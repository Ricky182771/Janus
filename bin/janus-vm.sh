#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Janus Project - VM Orchestration Helper (janus-vm) v0.1
# ------------------------------------------------------------------------------
# Description:
# Creates and manages libvirt QEMU/KVM VM definitions for Janus workflows.
# Creation runs in DRY-RUN mode by default; use --apply to persist changes.
#
# Usage:
#   janus-vm <create|start|stop|status> [options]
# ------------------------------------------------------------------------------

set -uo pipefail

VERSION="0.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/templates/libvirt"

CONFIG_DIR="$HOME/.config/janus/vm"
DEF_DIR="$CONFIG_DIR/definitions"
NVRAM_DIR="$CONFIG_DIR/nvram"
DEFAULT_DISK_DIR="$HOME/.local/share/janus/vms"

LOG_DIR="$HOME/.cache/janus/logs"
log_probe="$LOG_DIR/.janus_probe_$$"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || ! touch "$log_probe" >/dev/null 2>&1; then
    LOG_DIR="/tmp/janus/logs"
    mkdir -p "$LOG_DIR" || {
        echo "[ERROR] Unable to create log directory." >&2
        exit 1
    }
fi
rm -f "$log_probe"

LOG_FILE="$LOG_DIR/janus-vm_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Defaults
ACTION=""
VM_NAME="janus-win11"
MODE="base"
MEMORY_MIB="16384"
VCPUS="8"
DISK_SIZE="120G"
DISK_PATH=""
ISO_PATH=""
NETWORK_NAME="default"
CONNECT_URI="qemu:///system"
OVMF_CODE=""
OVMF_VARS=""
GPU_PCI=""
GPU_AUDIO_PCI=""
APPLY=0
ASSUME_YES=0
FORCE=0

log_info()  { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

die() {
    log_error "$1"
    exit 1
}

show_help() {
cat <<EOF
janus-vm v$VERSION
Manage Janus libvirt VM definitions for Windows + passthrough workflows.

Usage:
  janus-vm create [options]
  janus-vm start [options]
  janus-vm stop [options]
  janus-vm status [options]

Core options:
  --name NAME             VM name (default: janus-win11)
  --connect URI           libvirt URI (default: qemu:///system)
  --help, -h              Show this help

Create options:
  --mode MODE             base|passthrough (default: base)
  --memory-mib N          RAM in MiB (default: 16384)
  --vcpus N               vCPU count (default: 8)
  --disk-path PATH        QCOW2 disk path
  --disk-size SIZE        QCOW2 size if disk is created (default: 120G)
  --iso PATH              Windows installation ISO path
  --network NAME          libvirt network name (default: default)
  --ovmf-code PATH        OVMF_CODE.fd path
  --ovmf-vars PATH        OVMF_VARS.fd template path
  --gpu PCI               GPU PCI address for passthrough mode
  --gpu-audio PCI         GPU audio PCI address for passthrough mode
  --apply                 Apply changes (define VM, create disk/NVRAM)
  --yes                   Assume yes for confirmations

Stop options:
  --force                 Force stop via virsh destroy

Examples:
  janus-vm create --name win11 --mode base
  janus-vm create --name win11 --mode passthrough --gpu 0000:03:00.0 --gpu-audio 0000:03:00.1
  janus-vm create --name win11 --mode base --iso /var/lib/libvirt/boot/win11.iso --apply
  janus-vm status --name win11
  janus-vm start --name win11
  janus-vm stop --name win11

Safety:
  - 'create' is DRY-RUN by default.
  - Use --apply to persist VM definitions and artifacts.
EOF
}

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    read -r -p "$1 [y/N]: " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

normalize_pci() {
    local raw="${1,,}"
    if [[ "$raw" =~ ^[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
        echo "0000:$raw"
        return 0
    fi
    if [[ "$raw" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
        echo "$raw"
        return 0
    fi
    return 1
}

parse_pci_parts() {
    local pci="$1"
    local prefix="$2"
    local domain bus slot function

    pci="$(normalize_pci "$pci")" || die "Invalid PCI format: $1"
    IFS=':.' read -r domain bus slot function <<< "$pci"

    printf -v "${prefix}_DOMAIN" "0x%s" "$domain"
    printf -v "${prefix}_BUS" "0x%s" "$bus"
    printf -v "${prefix}_SLOT" "0x%s" "$slot"
    printf -v "${prefix}_FUNCTION" "0x%s" "$function"
}

sed_escape() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

detect_ovmf_code() {
    local candidates=(
        /usr/share/edk2/ovmf/OVMF_CODE.fd
        /usr/share/OVMF/OVMF_CODE.fd
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
    )
    local path
    for path in "${candidates[@]}"; do
        [ -f "$path" ] && { echo "$path"; return 0; }
    done
    return 1
}

detect_ovmf_vars() {
    local candidates=(
        /usr/share/edk2/ovmf/OVMF_VARS.fd
        /usr/share/OVMF/OVMF_VARS.fd
        /usr/share/edk2-ovmf/x64/OVMF_VARS.fd
    )
    local path
    for path in "${candidates[@]}"; do
        [ -f "$path" ] && { echo "$path"; return 0; }
    done
    return 1
}

ensure_virsh_connection() {
    require_cmd "virsh"
    virsh -c "$CONNECT_URI" uri >/dev/null 2>&1 || die "Unable to connect to libvirt URI: $CONNECT_URI"
}

domain_exists() {
    virsh -c "$CONNECT_URI" dominfo "$VM_NAME" >/dev/null 2>&1
}

domain_state() {
    virsh -c "$CONNECT_URI" domstate "$VM_NAME" 2>/dev/null | awk 'NR==1 {print $0}'
}

parse_args() {
    ACTION="${1:-}"
    [ -n "$ACTION" ] || { show_help; exit 1; }
    shift || true

    case "$ACTION" in
        create|start|stop|status) ;;
        --help|-h|help) show_help; exit 0 ;;
        *) die "Unknown action: $ACTION" ;;
    esac

    while [ $# -gt 0 ]; do
        case "$1" in
            --name) [ $# -ge 2 ] || die "--name requires a value"; VM_NAME="$2"; shift ;;
            --connect) [ $# -ge 2 ] || die "--connect requires a value"; CONNECT_URI="$2"; shift ;;
            --mode) [ $# -ge 2 ] || die "--mode requires a value"; MODE="$2"; shift ;;
            --memory-mib) [ $# -ge 2 ] || die "--memory-mib requires a value"; MEMORY_MIB="$2"; shift ;;
            --vcpus) [ $# -ge 2 ] || die "--vcpus requires a value"; VCPUS="$2"; shift ;;
            --disk-path) [ $# -ge 2 ] || die "--disk-path requires a value"; DISK_PATH="$2"; shift ;;
            --disk-size) [ $# -ge 2 ] || die "--disk-size requires a value"; DISK_SIZE="$2"; shift ;;
            --iso) [ $# -ge 2 ] || die "--iso requires a value"; ISO_PATH="$2"; shift ;;
            --network) [ $# -ge 2 ] || die "--network requires a value"; NETWORK_NAME="$2"; shift ;;
            --ovmf-code) [ $# -ge 2 ] || die "--ovmf-code requires a value"; OVMF_CODE="$2"; shift ;;
            --ovmf-vars) [ $# -ge 2 ] || die "--ovmf-vars requires a value"; OVMF_VARS="$2"; shift ;;
            --gpu) [ $# -ge 2 ] || die "--gpu requires a value"; GPU_PCI="$2"; shift ;;
            --gpu-audio) [ $# -ge 2 ] || die "--gpu-audio requires a value"; GPU_AUDIO_PCI="$2"; shift ;;
            --apply) APPLY=1 ;;
            --yes) ASSUME_YES=1 ;;
            --force) FORCE=1 ;;
            --help|-h) show_help; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done
}

validate_common() {
    [ -n "$VM_NAME" ] || die "VM name cannot be empty."
    [[ "$VM_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "VM name contains invalid characters: $VM_NAME"
}

validate_create() {
    case "$MODE" in
        base|passthrough) ;;
        *) die "Invalid mode: $MODE (expected base|passthrough)" ;;
    esac

    is_integer "$MEMORY_MIB" || die "--memory-mib must be an integer."
    is_integer "$VCPUS" || die "--vcpus must be an integer."
    [ "$MEMORY_MIB" -gt 0 ] || die "--memory-mib must be > 0"
    [ "$VCPUS" -gt 0 ] || die "--vcpus must be > 0"

    [ -n "$DISK_PATH" ] || DISK_PATH="$DEFAULT_DISK_DIR/${VM_NAME}.qcow2"

    [ -n "$OVMF_CODE" ] || OVMF_CODE="$(detect_ovmf_code || true)"
    [ -n "$OVMF_VARS" ] || OVMF_VARS="$(detect_ovmf_vars || true)"

    if [ -z "$OVMF_CODE" ]; then
        if [ "$APPLY" -eq 1 ]; then
            die "Unable to detect OVMF_CODE.fd. Provide --ovmf-code."
        fi
        OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
        log_warn "OVMF code path not detected; dry-run will use placeholder: $OVMF_CODE"
    elif [ ! -f "$OVMF_CODE" ]; then
        if [ "$APPLY" -eq 1 ]; then
            die "OVMF code file not found: $OVMF_CODE"
        fi
        log_warn "OVMF code file does not exist on this host (dry-run only): $OVMF_CODE"
    fi

    if [ -z "$OVMF_VARS" ]; then
        if [ "$APPLY" -eq 1 ]; then
            die "Unable to detect OVMF_VARS.fd. Provide --ovmf-vars."
        fi
        OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
        log_warn "OVMF vars path not detected; dry-run will use placeholder: $OVMF_VARS"
    elif [ ! -f "$OVMF_VARS" ]; then
        if [ "$APPLY" -eq 1 ]; then
            die "OVMF vars template not found: $OVMF_VARS"
        fi
        log_warn "OVMF vars template does not exist on this host (dry-run only): $OVMF_VARS"
    fi

    if [ -n "$ISO_PATH" ] && [ ! -f "$ISO_PATH" ]; then
        if [ "$APPLY" -eq 1 ]; then
            die "ISO file not found: $ISO_PATH"
        fi
        log_warn "ISO file does not exist on this host (dry-run only): $ISO_PATH"
    fi

    if [ "$MODE" = "passthrough" ]; then
        [ -n "$GPU_PCI" ] || die "--gpu is required for passthrough mode."
        [ -n "$GPU_AUDIO_PCI" ] || die "--gpu-audio is required for passthrough mode."
    fi

    if [ "$FORCE" -eq 1 ]; then
        die "--force is only valid for the stop action."
    fi
}

validate_non_create() {
    if [ "$APPLY" -eq 1 ]; then
        die "--apply is only valid for the create action."
    fi

    if [ "$ACTION" = "start" ] || [ "$ACTION" = "status" ]; then
        [ "$FORCE" -eq 0 ] || die "--force is only valid for stop."
    fi
}

prepare_layout() {
    mkdir -p "$DEF_DIR" "$NVRAM_DIR" "$(dirname "$DISK_PATH")" || die "Unable to create VM directories."
}

build_iso_block() {
    if [ -z "$ISO_PATH" ]; then
        printf '%s\n' "    <!-- No installation ISO configured -->"
        return 0
    fi

    cat <<EOF
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='__ISO_PATH__'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
EOF
}

build_display_block() {
    if [ "$MODE" = "passthrough" ]; then
        cat <<EOF
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>
EOF
        return 0
    fi

    cat <<EOF
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>
    <sound model='ich9'/>
    <audio id='1' type='spice'/>
EOF
}

build_gpu_hostdev_block() {
    if [ "$MODE" != "passthrough" ]; then
        printf '%s\n' "    <!-- No PCIe GPU passthrough configured -->"
        return 0
    fi

    cat <<EOF
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='${GPU_DOMAIN}' bus='${GPU_BUS}' slot='${GPU_SLOT}' function='${GPU_FUNCTION}'/>
      </source>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='${GPU_AUDIO_DOMAIN}' bus='${GPU_AUDIO_BUS}' slot='${GPU_AUDIO_SLOT}' function='${GPU_AUDIO_FUNCTION}'/>
      </source>
    </hostdev>
EOF
}

render_xml_definition() {
    local template_file="$1"
    local out_file="$2"
    local iso_block
    local display_block
    local gpu_hostdev_block
    local nvram_path="$NVRAM_DIR/${VM_NAME}_VARS.fd"

    [ -f "$template_file" ] || die "Template not found: $template_file"

    iso_block="$(build_iso_block)"
    iso_block="$(printf '%s' "$iso_block" | sed "s|__ISO_PATH__|$(sed_escape "$ISO_PATH")|g")"
    display_block="$(build_display_block)"
    gpu_hostdev_block="$(build_gpu_hostdev_block)"

    awk \
        -v VM_NAME="$VM_NAME" \
        -v MEMORY_MIB="$MEMORY_MIB" \
        -v VCPUS="$VCPUS" \
        -v OVMF_CODE="$OVMF_CODE" \
        -v OVMF_VARS="$OVMF_VARS" \
        -v NVRAM_PATH="$nvram_path" \
        -v DISK_PATH="$DISK_PATH" \
        -v NETWORK_NAME="$NETWORK_NAME" \
        -v ISO_BLOCK="$iso_block" \
        -v DISPLAY_BLOCK="$display_block" \
        -v GPU_HOSTDEV_BLOCK="$gpu_hostdev_block" \
        '
        {
            gsub(/__VM_NAME__/, VM_NAME)
            gsub(/__MEMORY_MIB__/, MEMORY_MIB)
            gsub(/__VCPUS__/, VCPUS)
            gsub(/__OVMF_CODE__/, OVMF_CODE)
            gsub(/__OVMF_VARS__/, OVMF_VARS)
            gsub(/__NVRAM_PATH__/, NVRAM_PATH)
            gsub(/__DISK_PATH__/, DISK_PATH)
            gsub(/__NETWORK_NAME__/, NETWORK_NAME)
            gsub(/__ISO_DEVICE_BLOCK__/, ISO_BLOCK)
            gsub(/__DISPLAY_DEVICE_BLOCK__/, DISPLAY_BLOCK)
            gsub(/__GPU_HOSTDEV_BLOCK__/, GPU_HOSTDEV_BLOCK)
            print
        }
        ' "$template_file" > "$out_file" || die "Unable to render VM definition: $out_file"
}

create_vm() {
    local def_file="$DEF_DIR/${VM_NAME}.xml"
    local template_file="$TEMPLATE_DIR/windows-base.xml"
    local nvram_path="$NVRAM_DIR/${VM_NAME}_VARS.fd"

    validate_create
    prepare_layout

    if [ "$MODE" = "passthrough" ]; then
        parse_pci_parts "$GPU_PCI" "GPU"
        parse_pci_parts "$GPU_AUDIO_PCI" "GPU_AUDIO"
    fi

    render_xml_definition "$template_file" "$def_file"
    log_ok "VM definition rendered: $def_file"

    if [ "$APPLY" -eq 0 ]; then
        log_info "DRY-RUN mode: no libvirt changes applied."
        if [ ! -f "$DISK_PATH" ]; then
            log_info "Would create disk: $DISK_PATH (size $DISK_SIZE)"
        fi
        if [ ! -f "$nvram_path" ]; then
            log_info "Would create NVRAM file from template: $nvram_path"
        fi
        log_info "To apply: janus-vm create --name $VM_NAME --mode $MODE --apply"
        return 0
    fi

    require_cmd "qemu-img"
    ensure_virsh_connection

    if ! confirm "Apply VM definition and local artifacts now?"; then
        log_warn "Aborted by user."
        return 0
    fi

    if [ ! -f "$DISK_PATH" ]; then
        log_info "Creating disk: $DISK_PATH ($DISK_SIZE)"
        qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE" >/dev/null || die "Failed to create disk image."
    else
        log_info "Disk already exists: $DISK_PATH"
    fi

    if [ ! -f "$nvram_path" ]; then
        cp "$OVMF_VARS" "$nvram_path" || die "Failed to create NVRAM file."
        log_ok "NVRAM file created: $nvram_path"
    else
        log_info "NVRAM file already exists: $nvram_path"
    fi

    virsh -c "$CONNECT_URI" define "$def_file" >/dev/null || die "virsh define failed."
    log_ok "VM defined in libvirt: $VM_NAME"
}

start_vm() {
    ensure_virsh_connection
    domain_exists || die "VM not defined: $VM_NAME"

    if [ "$(domain_state)" = "running" ]; then
        log_info "VM is already running: $VM_NAME"
        return 0
    fi

    virsh -c "$CONNECT_URI" start "$VM_NAME" >/dev/null || die "Failed to start VM."
    log_ok "VM started: $VM_NAME"
}

stop_vm() {
    local state
    ensure_virsh_connection
    domain_exists || die "VM not defined: $VM_NAME"

    state="$(domain_state)"
    if [ "$state" = "shut off" ]; then
        log_info "VM is already stopped: $VM_NAME"
        return 0
    fi

    if [ "$FORCE" -eq 1 ]; then
        confirm "Force-stop VM using virsh destroy?" || {
            log_warn "Aborted by user."
            return 0
        }
        virsh -c "$CONNECT_URI" destroy "$VM_NAME" >/dev/null || die "Failed to force-stop VM."
        log_ok "VM force-stopped: $VM_NAME"
        return 0
    fi

    virsh -c "$CONNECT_URI" shutdown "$VM_NAME" >/dev/null || die "Failed to request VM shutdown."
    log_ok "Shutdown signal sent: $VM_NAME"
}

status_vm() {
    ensure_virsh_connection
    if ! domain_exists; then
        log_warn "VM is not defined: $VM_NAME"
        return 1
    fi

    log_info "VM status for: $VM_NAME"
    printf "  State: %s\n" "$(domain_state)"
    virsh -c "$CONNECT_URI" dominfo "$VM_NAME" | sed 's/^/  /'
}

main() {
    parse_args "$@"
    validate_common

    case "$ACTION" in
        create) validate_create ;;
        start|stop|status) validate_non_create ;;
    esac

    case "$ACTION" in
        create) create_vm ;;
        start) start_vm ;;
        stop) stop_vm ;;
        status) status_vm ;;
        *) die "Unhandled action: $ACTION" ;;
    esac
}

main "$@"
