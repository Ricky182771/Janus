#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM CLI
# ----------------------------------------------------------------------------
# This file parses actions and command-line options for janus-vm.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_CLI_ARGS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_CLI_ARGS_LOADED=1

# Print janus-vm help text.
janus_vm_show_help() {
    cat <<EOF_HELP
janus-vm v$JANUS_VM_VERSION
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
  --guided                Force guided create wizard (auto-fallback in no-TTY runs)
  --no-guided             Disable guided create wizard
  --memory-mib N          RAM in MiB (default: 16384)
  --vcpus N               vCPU count (default: 8)
  --storage MODE          file|block (default: file)
  --disk-path PATH        Disk path (qcow2 file or /dev block device)
  --disk-size SIZE        QCOW2 size if file disk is created (default: 120G)
  --iso PATH              Windows installation ISO path
  --network NAME          libvirt network name (default: default)
  --ovmf-code PATH        OVMF_CODE.fd path
  --ovmf-vars PATH        OVMF_VARS.fd template path
  --gpu PCI               GPU PCI address for passthrough mode
  --gpu-audio PCI         GPU audio PCI address for passthrough mode
  --single-gpu-mode MODE  shared-vram|cpu-only (base mode only)
  --unattended            Enable Windows unattended local account setup
  --win-user USER         Local Windows username for unattended
  --win-password PASS     Optional local Windows password for unattended
  --apply                 Apply changes (define VM, create disk/NVRAM)
  --yes                   Assume yes for confirmations

Stop options:
  --force                 Force stop via virsh destroy

Examples:
  janus-vm create --name win11 --guided
  janus-vm create --name win11 --mode passthrough --gpu 0000:03:00.0 --gpu-audio 0000:03:00.1
  janus-vm create --name win11 --mode base --single-gpu-mode cpu-only
  janus-vm create --name win11 --storage block --disk-path /dev/nvme0n1p3 --apply
  janus-vm create --name win11 --unattended --win-user gamer --win-password secret --apply
  janus-vm status --name win11
  janus-vm start --name win11
  janus-vm stop --name win11

Safety:
  - 'create' is DRY-RUN by default.
  - Use --apply to persist VM definitions and artifacts.
EOF_HELP
}

# Parse action and options.
janus_vm_parse_args() {
    JANUS_VM_ACTION="${1:-}"
    [ -n "$JANUS_VM_ACTION" ] || {
        janus_vm_show_help
        exit 1
    }
    shift || true

    case "$JANUS_VM_ACTION" in
        create|start|stop|status)
            ;;
        --help|-h|help)
            janus_vm_show_help
            exit 0
            ;;
        *)
            janus_vm_die "Unknown action: $JANUS_VM_ACTION"
            ;;
    esac

    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                [ $# -ge 2 ] || janus_vm_die "--name requires a value"
                JANUS_VM_NAME="$2"
                shift
                ;;
            --connect)
                [ $# -ge 2 ] || janus_vm_die "--connect requires a value"
                JANUS_VM_CONNECT_URI="$2"
                shift
                ;;
            --mode)
                [ $# -ge 2 ] || janus_vm_die "--mode requires a value"
                JANUS_VM_MODE="$2"
                shift
                ;;
            --guided)
                JANUS_VM_GUIDED_MODE="on"
                ;;
            --no-guided)
                JANUS_VM_GUIDED_MODE="off"
                ;;
            --memory-mib)
                [ $# -ge 2 ] || janus_vm_die "--memory-mib requires a value"
                JANUS_VM_MEMORY_MIB="$2"
                shift
                ;;
            --vcpus)
                [ $# -ge 2 ] || janus_vm_die "--vcpus requires a value"
                JANUS_VM_VCPUS="$2"
                shift
                ;;
            --storage)
                [ $# -ge 2 ] || janus_vm_die "--storage requires a value"
                JANUS_VM_STORAGE_MODE="$2"
                shift
                ;;
            --disk-path)
                [ $# -ge 2 ] || janus_vm_die "--disk-path requires a value"
                JANUS_VM_DISK_PATH="$2"
                shift
                ;;
            --disk-size)
                [ $# -ge 2 ] || janus_vm_die "--disk-size requires a value"
                JANUS_VM_DISK_SIZE="$2"
                shift
                ;;
            --iso)
                [ $# -ge 2 ] || janus_vm_die "--iso requires a value"
                JANUS_VM_ISO_PATH="$2"
                shift
                ;;
            --network)
                [ $# -ge 2 ] || janus_vm_die "--network requires a value"
                JANUS_VM_NETWORK_NAME="$2"
                shift
                ;;
            --ovmf-code)
                [ $# -ge 2 ] || janus_vm_die "--ovmf-code requires a value"
                JANUS_VM_OVMF_CODE="$2"
                shift
                ;;
            --ovmf-vars)
                [ $# -ge 2 ] || janus_vm_die "--ovmf-vars requires a value"
                JANUS_VM_OVMF_VARS="$2"
                shift
                ;;
            --gpu)
                [ $# -ge 2 ] || janus_vm_die "--gpu requires a value"
                JANUS_VM_GPU_PCI="$2"
                shift
                ;;
            --gpu-audio)
                [ $# -ge 2 ] || janus_vm_die "--gpu-audio requires a value"
                JANUS_VM_GPU_AUDIO_PCI="$2"
                shift
                ;;
            --single-gpu-mode)
                [ $# -ge 2 ] || janus_vm_die "--single-gpu-mode requires a value"
                JANUS_VM_SINGLE_GPU_MODE="$2"
                shift
                ;;
            --unattended)
                JANUS_VM_UNATTENDED_ENABLED=1
                ;;
            --win-user)
                [ $# -ge 2 ] || janus_vm_die "--win-user requires a value"
                JANUS_VM_WIN_USERNAME="$2"
                JANUS_VM_UNATTENDED_ENABLED=1
                shift
                ;;
            --win-password)
                [ $# -ge 2 ] || janus_vm_die "--win-password requires a value"
                JANUS_VM_WIN_PASSWORD="$2"
                JANUS_VM_UNATTENDED_ENABLED=1
                shift
                ;;
            --apply)
                JANUS_VM_APPLY=1
                ;;
            --yes)
                JANUS_VM_ASSUME_YES=1
                ;;
            --force)
                JANUS_VM_FORCE=1
                ;;
            --help|-h)
                janus_vm_show_help
                exit 0
                ;;
            *)
                janus_vm_die "Unknown option: $1"
                ;;
        esac
        shift
    done
}
