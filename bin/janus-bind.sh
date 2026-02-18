#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Janus Project - VFIO Bind Tool (janus-bind) v0.1
# ──────────────────────────────────────────────────────────────────────────────
# Copyright (C) 2026 Ricardo (Ricky182771)
# Licensed under GNU GPL v3.0
#
# Description:
# Safely prepares PCI devices (GPU / audio) for VFIO passthrough.
# Default mode is DRY-RUN. No destructive action is performed unless --apply
# is explicitly provided.
#
# Usage:
#   janus-bind [--list]
#              [--device PCI | --group ID]
#              [--dry-run | --apply]
#              [--rollback]
#              [--yes]
#              [--verbose]
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

VERSION="0.1"

# Paths
CONFIG_DIR="$HOME/.config/janus"
STATE_DIR="$CONFIG_DIR/state"
LOG_DIR="$HOME/.cache/janus/logs"
state_probe="$STATE_DIR/.janus_probe_$$"
if ! mkdir -p "$STATE_DIR" 2>/dev/null || ! touch "$state_probe" >/dev/null 2>&1; then
    STATE_DIR="/tmp/janus/state"
    mkdir -p "$STATE_DIR" || {
        echo "[ERROR] Unable to create state directory." >&2
        exit 1
    }
    state_probe="$STATE_DIR/.janus_probe_$$"
    touch "$state_probe" >/dev/null 2>&1 || {
        echo "[ERROR] State directory is not writable." >&2
        exit 1
    }
fi
rm -f "$state_probe"

log_probe="$LOG_DIR/.janus_probe_$$"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || ! touch "$log_probe" >/dev/null 2>&1; then
    LOG_DIR="/tmp/janus/logs"
    mkdir -p "$LOG_DIR" || {
        echo "[ERROR] Unable to create log directory." >&2
        exit 1
    }
    log_probe="$LOG_DIR/.janus_probe_$$"
    touch "$log_probe" >/dev/null 2>&1 || {
        echo "[ERROR] Log directory is not writable." >&2
        exit 1
    }
fi
rm -f "$log_probe"

LOG_FILE="$LOG_DIR/janus-bind_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Flags / state
MODE="dry-run"
TARGET_DEVICE=""
TARGET_GROUP=""
ROLLBACK=0
ASSUME_YES=0
VERBOSE=0
DEVICES=()

# ─────────────────────────────────────────────
# Logging helpers
# ─────────────────────────────────────────────

log_info()  { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_debug() { [ "$VERBOSE" -eq 1 ] && printf "${BLUE}[DEBUG]${NC} %s\n" "$1"; }

die() {
    log_error "$1"
    exit 1
}

show_help() {
cat <<EOF
janus-bind v$VERSION
Safely prepare PCI devices for VFIO passthrough.

Usage:
  janus-bind --list
  janus-bind --device 0000:03:00.0 --dry-run
  janus-bind --group 11 --dry-run --yes
  sudo janus-bind --device 0000:03:00.0 --apply
  sudo janus-bind --rollback

Options:
  --list              List detected display controllers.
  --device PCI        Target a single PCI device.
  --group ID          Target all devices in an IOMMU group.
  --dry-run           Simulate actions (default mode).
  --apply             Apply bind operations to vfio-pci (requires root).
  --rollback          Restore last saved bind state (requires root).
  --yes               Assume yes for confirmation prompts.
  --verbose           Enable debug logging.
  --help, -h          Show this help.

Warning:
  --apply writes to /sys and can impact active graphics/session devices.
  Prefer --dry-run first and validate your IOMMU isolation.
EOF
}

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "This action requires root privileges. Re-run with sudo."
    fi
}

require_cmd() {
    local cmd="$1"
    local context="$2"
    command -v "$cmd" >/dev/null 2>&1 || die "$context requires '$cmd' (install missing package)."
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

require_existing_pci() {
    local pci="$1"
    [ -d "/sys/bus/pci/devices/$pci" ] || die "PCI device does not exist: $pci"
}

require_numeric_group() {
    [[ "$1" =~ ^[0-9]+$ ]] || die "Invalid IOMMU group: $1"
}

pci_driver() {
    local pci="$1"
    if [ -e "/sys/bus/pci/devices/$pci/driver" ]; then
        basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")"
    else
        echo "none"
    fi
}

pci_vendor_device() {
    local pci="$1"
    local v d
    [ -d "/sys/bus/pci/devices/$pci" ] || return 1
    v=$(cat "/sys/bus/pci/devices/$pci/vendor") || return 1
    d=$(cat "/sys/bus/pci/devices/$pci/device") || return 1
    echo "${v#0x}:${d#0x}"
}

pci_iommu_group() {
    local pci="$1"
    if [ -e "/sys/bus/pci/devices/$pci/iommu_group" ]; then
        basename "$(readlink -f "/sys/bus/pci/devices/$pci/iommu_group")"
    else
        echo "none"
    fi
}

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    read -r -p "$1 [y/N]: " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ─────────────────────────────────────────────
# Core logic
# ─────────────────────────────────────────────

list_devices() {
    require_cmd "lspci" "Device listing"
    log_info "Detecting VGA / 3D / Display devices"
    mapfile -t lines < <(lspci -nn | grep -Ei 'VGA|3D controller|Display')

    if [ "${#lines[@]}" -eq 0 ]; then
        log_warn "No GPU devices detected."
        return
    fi

    i=0
    for line in "${lines[@]}"; do
        addr=$(awk '{print $1}' <<< "$line")
        pci="0000:$addr"
        drv=$(pci_driver "$pci")
        grp=$(pci_iommu_group "$pci")

        echo "[$i] $pci  Driver: $drv  Group: $grp"
        echo "    $line"
        ((i++))
    done
}

validate_option_combinations() {
    if [ "$ROLLBACK" -eq 1 ] && [ -n "$TARGET_DEVICE$TARGET_GROUP" ]; then
        die "--rollback cannot be combined with --device or --group."
    fi

    if [ "$ROLLBACK" -eq 1 ] && [ "$MODE" = "apply" ]; then
        die "--rollback cannot be combined with --apply."
    fi
}

validate_environment() {
    [ -d /sys/bus/pci/devices ] || die "PCI sysfs path is not available: /sys/bus/pci/devices"
}

resolve_targets() {
    if [ -n "$TARGET_DEVICE" ] && [ -n "$TARGET_GROUP" ]; then
        die "Use either --device or --group, not both."
    fi

    if [ -n "$TARGET_DEVICE" ]; then
        TARGET_DEVICE="$(normalize_pci "$TARGET_DEVICE")" || die "Invalid PCI format: $TARGET_DEVICE"
        require_existing_pci "$TARGET_DEVICE"
        DEVICES=("$TARGET_DEVICE")
        return
    fi

    if [ -n "$TARGET_GROUP" ]; then
        require_numeric_group "$TARGET_GROUP"
        [ -d "/sys/kernel/iommu_groups/$TARGET_GROUP/devices" ] || die "IOMMU group not found: $TARGET_GROUP"
        mapfile -t DEVICES < <(
            for dev in "/sys/kernel/iommu_groups/$TARGET_GROUP/devices"/*; do
                [ -e "$dev" ] && basename "$dev"
            done
        )
        [ "${#DEVICES[@]}" -eq 0 ] && die "No devices found in IOMMU group $TARGET_GROUP"
        return
    fi

    die "No target specified. Use --device or --group."
}

analyze_group_safety() {
    local grp="$1"
    [ "$grp" != "none" ] || {
        log_warn "IOMMU group is unknown for target device."
        return 1
    }
    [ -d "/sys/kernel/iommu_groups/$grp/devices" ] || {
        log_warn "IOMMU group path does not exist: $grp"
        return 1
    }
    mapfile -t devs < <(
        for dev in "/sys/kernel/iommu_groups/$grp/devices"/*; do
            [ -e "$dev" ] && basename "$dev"
        done
    )
    [ "${#devs[@]}" -gt 0 ] || {
        log_warn "IOMMU group $grp has no visible devices."
        return 1
    }

    if [ "${#devs[@]}" -gt 2 ]; then
        log_warn "Group $grp contains ${#devs[@]} devices. Passthrough may be unsafe."
        return 1
    fi

    log_ok "Group $grp appears reasonably isolated."
    return 0
}

dry_run() {
    log_info "DRY RUN — no changes will be applied"

    for pci in "${DEVICES[@]}"; do
        require_existing_pci "$pci"
        drv=$(pci_driver "$pci")
        id=$(pci_vendor_device "$pci") || die "Unable to read vendor/device for $pci"
        grp=$(pci_iommu_group "$pci")

        echo "• Device: $pci"
        echo "    Current driver: $drv"
        echo "    Vendor:Device: $id"
        echo "    IOMMU group: $grp"
        echo "    Action: unbind from $drv → bind to vfio-pci"
        echo ""
    done
}

apply_bind() {
    require_root
    [ -e /sys/bus/pci/drivers/vfio-pci/bind ] || die "vfio-pci is not available. Load vfio-pci before applying."

    STATE_FILE="$STATE_DIR/bind_$(date +%Y%m%d_%H%M%S).state"
    log_info "Saving bind state to $STATE_FILE"

    for pci in "${DEVICES[@]}"; do
        require_existing_pci "$pci"
        drv=$(pci_driver "$pci")
        grp=$(pci_iommu_group "$pci")
        id=$(pci_vendor_device "$pci") || die "Unable to read vendor/device for $pci"
        log_debug "Binding $pci (driver=$drv, group=$grp, id=$id)"

        echo "DEVICE=$pci" >> "$STATE_FILE"
        echo "OLD_DRIVER=$drv" >> "$STATE_FILE"
        echo "GROUP=$grp" >> "$STATE_FILE"
        echo "ID=$id" >> "$STATE_FILE"
        echo "---" >> "$STATE_FILE"

        if [ "$drv" != "none" ]; then
            [ -e "/sys/bus/pci/drivers/$drv/unbind" ] || die "Missing unbind path for driver $drv"
            printf '%s' "$pci" > "/sys/bus/pci/drivers/$drv/unbind" || die "Failed to unbind $pci from $drv"
        fi

        printf '%s' "$id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || log_debug "Device ID $id is already registered in vfio-pci."
        printf '%s' "$pci" > /sys/bus/pci/drivers/vfio-pci/bind || die "Failed to bind $pci to vfio-pci"
        log_ok "Bound $pci to vfio-pci"
    done
}

rollback_last() {
    require_root

    last=$(ls -t "$STATE_DIR"/bind_*.state 2>/dev/null | head -n1)
    [ -z "$last" ] && die "No previous bind state found."

    log_info "Rolling back using $last"

    while IFS= read -r line; do
        case "$line" in
            DEVICE=*) pci="${line#DEVICE=}" ;;
            OLD_DRIVER=*) drv="${line#OLD_DRIVER=}" ;;
            ID=*) id="${line#ID=}" ;;
            ---)
                [ -n "${pci:-}" ] || die "Corrupt state file: missing DEVICE entry."
                if [ "$(pci_driver "$pci")" = "vfio-pci" ]; then
                    [ -e /sys/bus/pci/drivers/vfio-pci/unbind ] || die "Missing vfio-pci unbind path."
                    printf '%s' "$pci" > /sys/bus/pci/drivers/vfio-pci/unbind || die "Failed to unbind $pci from vfio-pci"
                fi
                if [ "${drv:-none}" != "none" ]; then
                    [ -e "/sys/bus/pci/drivers/$drv/bind" ] || die "Missing bind path for driver $drv"
                    printf '%s' "$pci" > "/sys/bus/pci/drivers/$drv/bind" || die "Failed to rebind $pci to $drv"
                fi
                log_ok "Restored $pci to driver $drv"
                ;;
        esac
    done < "$last"
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --list) list_devices; exit 0 ;;
            --device)
                [ $# -ge 2 ] || die "--device requires a PCI address argument."
                TARGET_DEVICE="$2"
                shift
                ;;
            --group)
                [ $# -ge 2 ] || die "--group requires an IOMMU group ID."
                TARGET_GROUP="$2"
                shift
                ;;
            --dry-run) MODE="dry-run" ;;
            --apply) MODE="apply" ;;
            --rollback) ROLLBACK=1 ;;
            --yes) ASSUME_YES=1 ;;
            --verbose) VERBOSE=1 ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    echo "=== Janus VFIO Bind v$VERSION ==="
    validate_option_combinations

    if [ "$ROLLBACK" -eq 1 ]; then
        rollback_last
        exit 0
    fi

    validate_environment
    resolve_targets

    grp=$(pci_iommu_group "${DEVICES[0]}")
    analyze_group_safety "$grp" || {
        confirm "Continue despite unsafe IOMMU group?" || exit 1
    }

    if [ "$MODE" = "dry-run" ]; then
        dry_run
        exit 0
    fi

    log_warn "APPLY mode selected. This will modify active driver bindings."
    confirm "Apply VFIO binding now?" || exit 0
    apply_bind
    log_ok "VFIO binding completed."
}

main "$@"
