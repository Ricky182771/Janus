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
mkdir -p "$STATE_DIR" "$LOG_DIR"

LOG_FILE="$LOG_DIR/janus-bind_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags / state
MODE="dry-run"
TARGET_DEVICE=""
TARGET_GROUP=""
ROLLBACK=0
ASSUME_YES=0
VERBOSE=0

# ─────────────────────────────────────────────
# Logging helpers
# ─────────────────────────────────────────────

log_info()  { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

die() {
    log_error "$1"
    exit 1
}

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "This action requires root privileges. Re-run with sudo."
    fi
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
    v=$(cat "/sys/bus/pci/devices/$pci/vendor")
    d=$(cat "/sys/bus/pci/devices/$pci/device")
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

resolve_targets() {
    if [ -n "$TARGET_DEVICE" ] && [ -n "$TARGET_GROUP" ]; then
        die "Use either --device or --group, not both."
    fi

    if [ -n "$TARGET_DEVICE" ]; then
        DEVICES=("$TARGET_DEVICE")
        return
    fi

    if [ -n "$TARGET_GROUP" ]; then
        mapfile -t DEVICES < <(ls "/sys/kernel/iommu_groups/$TARGET_GROUP/devices" 2>/dev/null | xargs -n1 basename)
        [ "${#DEVICES[@]}" -eq 0 ] && die "No devices found in IOMMU group $TARGET_GROUP"
        return
    fi

    die "No target specified. Use --device or --group."
}

analyze_group_safety() {
    local grp="$1"
    mapfile -t devs < <(ls "/sys/kernel/iommu_groups/$grp/devices" | xargs -n1 basename)

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
        drv=$(pci_driver "$pci")
        id=$(pci_vendor_device "$pci")
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

    STATE_FILE="$STATE_DIR/bind_$(date +%Y%m%d_%H%M%S).state"
    log_info "Saving bind state to $STATE_FILE"

    for pci in "${DEVICES[@]}"; do
        drv=$(pci_driver "$pci")
        grp=$(pci_iommu_group "$pci")
        id=$(pci_vendor_device "$pci")

        echo "DEVICE=$pci" >> "$STATE_FILE"
        echo "OLD_DRIVER=$drv" >> "$STATE_FILE"
        echo "GROUP=$grp" >> "$STATE_FILE"
        echo "ID=$id" >> "$STATE_FILE"
        echo "---" >> "$STATE_FILE"

        if [ "$drv" != "none" ]; then
            echo "$pci" > "/sys/bus/pci/drivers/$drv/unbind"
        fi

        echo "$id" > /sys/bus/pci/drivers/vfio-pci/new_id
        log_ok "Bound $pci to vfio-pci"
    done
}

rollback_last() {
    require_root

    last=$(ls -t "$STATE_DIR"/bind_*.state 2>/dev/null | head -n1)
    [ -z "$last" ] && die "No previous bind state found."

    log_info "Rolling back using $last"

    while read -r line; do
        case "$line" in
            DEVICE=*) pci="${line#DEVICE=}" ;;
            OLD_DRIVER=*) drv="${line#OLD_DRIVER=}" ;;
            ID=*) id="${line#ID=}" ;;
            ---)
                echo "$pci" > /sys/bus/pci/drivers/vfio-pci/unbind
                [ "$drv" != "none" ] && echo "$pci" > "/sys/bus/pci/drivers/$drv/bind"
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
            --device) TARGET_DEVICE="$2"; shift ;;
            --group) TARGET_GROUP="$2"; shift ;;
            --dry-run) MODE="dry-run" ;;
            --apply) MODE="apply" ;;
            --rollback) ROLLBACK=1 ;;
            --yes) ASSUME_YES=1 ;;
            --verbose) VERBOSE=1 ;;
            --help|-h)
                echo "janus-bind v$VERSION"
                echo "Use --list, --device PCI or --group ID"
                exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    echo "=== Janus VFIO Bind v$VERSION ==="

    if [ "$ROLLBACK" -eq 1 ]; then
        rollback_last
        exit 0
    fi

    resolve_targets

    grp=$(pci_iommu_group "${DEVICES[0]}")
    analyze_group_safety "$grp" || {
        confirm "Continue despite unsafe IOMMU group?" || exit 1
    }

    if [ "$MODE" = "dry-run" ]; then
        dry_run
        exit 0
    fi

    confirm "Apply VFIO binding now?" || exit 0
    apply_bind
    log_ok "VFIO binding completed."
}

main "$@"
