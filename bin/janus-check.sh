#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Janus Project - Diagnostic Tool (janus-check) v0.2
# ──────────────────────────────────────────────────────────────────────────────
# Copyright (C) 2026 Ricardo (Ricky182771)
# Licensed under GNU GPL v3.0 - See LICENSE file in the repository.
#
# Description:
# Diagnostic script: checks basic requirements for VFIO passthrough,
# KVM virtualization and the Janus Linux<->Windows hybrid architecture.
#
# Usage:
#   ./janus-check [--help | --version | --no-interactive]
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail
# Note: avoid -e so we can collect non-critical errors and present a summary.

VERSION="0.2"
LOG_DIR="${HOME:-/root}/.cache/janus"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/last_check_$(date +%Y%m%d_%H%M%S).log"

# Dual output: terminal + log
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Janus Diagnostic v$VERSION - $(date '+%Y-%m-%d %H:%M:%S') ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters / state
CRITICAL_COUNT=0
WARN_COUNT=0
INFO_COUNT=0
NO_INTERACTIVE=0

# Logging helpers
log_info()     { printf "${BLUE}[INFO]${NC} %s\n" "$1"; ((INFO_COUNT++)); }
log_ok()       { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()     { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; ((WARN_COUNT++)); }
log_critical() { printf "${RED}[CRITICAL]${NC} %s\n" "$1"; ((CRITICAL_COUNT++)); }

# Find janus-init script
find_janus_init() {
    # Prefer local bin directory
    if [ -x "$(dirname "$0")/janus-init.sh" ]; then
        echo "$(dirname "$0")/janus-init.sh"
        return 0
    fi

    # Fallback to PATH
    if command -v janus-init >/dev/null 2>&1; then
        command -v janus-init
        return 0
    fi

    return 1
}


# Exit with summary and non-zero if any criticals found
finish() {
    echo "────────────────────────────────────────"
    printf "Summary: %s%d%s CRITICAL, %s%d%s WARN, %s%d%s INFO\n" \
      "${RED}" "$CRITICAL_COUNT" "${NC}" \
      "${YELLOW}" "$WARN_COUNT" "${NC}" \
      "${BLUE}" "$INFO_COUNT" "${NC}"

    echo "Log saved to: $LOG_FILE"

    # Hard stop if critical errors
    if [ "$CRITICAL_COUNT" -gt 0 ]; then
        echo ""
        echo "Critical issues were detected."
        echo "Resolve them before continuing with Janus initialization."
        exit 2
    fi

    # Offer janus-init
    init_path="$(find_janus_init || true)"

    if [ -n "$init_path" ]; then
        echo ""
        if [ "$NO_INTERACTIVE" -eq 0 ]; then
            read -r -p "Run janus-init now? (recommended) [Y/n]: " confirm || true
            if [[ ! "$confirm" =~ ^[Nn] ]]; then
                echo ""
                echo "Launching janus-init..."
                exec "$init_path"
            fi
        else
            log_info "Non-interactive mode: skipping janus-init prompt."
        fi
    else
        log_warn "janus-init not found. Run it manually to continue setup."
    fi

    exit 0
}

show_help() {
    cat <<EOF
Usage: ./janus-check [OPTIONS]

Options:
  --help, -h         Show this help
  --version, -v      Show version
  --no-interactive   Do not prompt (useful for CI / examples)
EOF
    exit 0
}

# Utility: run a command and return a warning if missing
run() {
    # $1 = description, rest = command
    desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        log_ok "$desc"
        return 0
    else
        log_warn "$desc (not found / failed)"
        return 1
    fi
}

# ---------------------------
# Checks
# ---------------------------

# Check 1: CPU virtualization support + /dev/kvm
check_cpu_virt() {
    log_info "Checking CPU virtualization support (VT-x / AMD-V) and /dev/kvm..."
    cpuflags=$(grep -m1 -oE 'vmx|svm' /proc/cpuinfo || true)
    if [ -n "$cpuflags" ]; then
        log_ok "VT-x / AMD-V support detected: $cpuflags"
    else
        log_critical "No VT-x / AMD-V flags found in /proc/cpuinfo. Enable them in BIOS/UEFI."
    fi

    if [ -e /dev/kvm ]; then
        log_ok "/dev/kvm present - KVM accessible"
    else
        log_warn "/dev/kvm is missing. Verify KVM is enabled and your user has permissions (kvm_* module loaded)."
    fi
}

# Check 2: IOMMU kernel activation (cmdline + sysfs)
check_iommu() {
    log_info "Checking IOMMU presence in kernel (cmdline + sysfs)..."
    cmdline=$(cat /proc/cmdline || true)
    if echo "$cmdline" | grep -q -E 'intel_iommu=on|amd_iommu=on|iommu=pt'; then
        log_ok "IOMMU enabled in kernel cmdline."
    else
        # Fallback check: sysfs groups
        if [ -d /sys/kernel/iommu_groups ] && ls /sys/kernel/iommu_groups/* >/dev/null 2>&1; then
            log_ok "IOMMU active and groups populated (detected via /sys/kernel/iommu_groups)."
        else
            log_warn "IOMMU does not appear active in cmdline and /sys/kernel/iommu_groups looks empty."
            log_info "Recommendation: add intel_iommu=on iommu=pt (Intel) or amd_iommu=on (AMD) to kernel cmdline."
            # We avoid auto-applying changes here; only recommend.
        fi
    fi
}

# Check 3: Virtualization tools
check_virt_tools() {
    log_info "Checking virtualization tools (libvirt/qemu/virsh/virt-manager)..."
    miss=()
    for p in virsh qemu-img qemu-system-x86_64; do
        if ! command -v "$p" >/dev/null 2>&1; then
            miss+=("$p")
        fi
    done
    if [ "${#miss[@]}" -eq 0 ]; then
        log_ok "libvirt/QEMU tools installed."
    else
        log_warn "Missing tools: ${miss[*]}"
        log_info "On Fedora: sudo dnf install libvirt qemu-kvm virt-manager"
        log_info "On Debian/Ubuntu: sudo apt install qemu-kvm libvirt-clients libvirt-daemon-system virt-manager"
    fi
}

# Check 4: Kernel modules for VFIO / KVM
check_kernel_modules() {
    log_info "Checking kernel modules related to VFIO / KVM..."
    required=(kvm kvm_intel kvm_amd vfio vfio_pci vfio_iommu_type1)
    for m in "${required[@]}"; do
        if lsmod | grep -q "^$m"; then
            log_ok "Module loaded: $m"
        else
            # Only warn for module absence
            log_warn "Module not loaded: $m"
            log_info "Load with: sudo modprobe $m (or persist via /etc/modules-load.d/janus.conf)"
        fi
    done
}

# Check 5: Hugepages suggestion
check_hugepages() {
    log_info "Checking hugepages (recommended for high-performance VMs)..."
    total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo || echo 0)
    total_gb=$(( (total_kb / 1024 / 1024) ))
    # heuristic: ~64 2MiB hugepages per GB
    recommend=$(( total_gb * 64 ))
    actual=$(grep -E '^HugePages_Total' /proc/meminfo | awk '{print $2}' || echo 0)
    if [ -n "$actual" ] && [ "$actual" -ge 1 ]; then
        log_ok "HugePages present: $actual (recommended ~ $recommend)"
    else
        log_warn "HugePages not enabled. Recommended for this machine: vm.nr_hugepages = $recommend"
        log_info "Example: echo 'vm.nr_hugepages = $recommend' | sudo tee /etc/sysctl.d/99-hugepages.conf && sudo sysctl -p"
    fi
}

# Helper: read IOMMU group for a PCI device (0000:xx:xx.x)
pci_iommu_group() {
    pci="$1"
    if [ -e "/sys/bus/pci/devices/$pci/iommu_group" ]; then
        basename "$(readlink -f /sys/bus/pci/devices/$pci/iommu_group)"
    else
        echo "none"
    fi
}

# Check 6: GPUs detection with driver and iommu groups
check_gpus() {
    log_info "Detecting GPUs and drivers (PCI addresses + driver + IOMMU group)..."
    mapfile -t gpu_lines < <(lspci -nn | grep -iE 'VGA|3D controller|Display' || true)

    if [ ${#gpu_lines[@]} -eq 0 ]; then
        log_warn "No video controllers found (lspci returned no VGA/Display entries)."
        return
    fi

    declare -A group_map
    gpu_count=0
    for line in "${gpu_lines[@]}"; do
        addr=$(echo "$line" | awk '{print $1}')
        if [[ "$addr" != 0000:* ]]; then
            pci="0000:$addr"
        else
            pci="$addr"
        fi
        ((gpu_count++))
        driver=""
        if [ -e "/sys/bus/pci/devices/$pci/driver" ]; then
            driver=$(basename "$(readlink -f /sys/bus/pci/devices/$pci/driver)" || true)
        fi
        group=$(pci_iommu_group "$pci")
        group_map["$group"]+="$pci "

        # Print details
        echo "  - PCI: $pci"
        echo "      Desc: $(lspci -s "$addr" -nn)"
        if [ -n "$driver" ]; then
            echo "      Driver: $driver"
        else
            echo "      Driver: (none)"
        fi
        echo "      IOMMU group: $group"
        echo ""
    done

    if [ "$gpu_count" -ge 2 ]; then
        log_ok "$gpu_count GPUs detected (multi-GPU)."
    else
        log_warn "$gpu_count GPU(s) detected. Multi-GPU is recommended for dedicated passthrough."
    fi

    # Analyze groups: prefer groups that contain only the GPU (and maybe its audio function)
    log_info "Analyzing IOMMU groups (summary)..."
    for g in "${!group_map[@]}"; do
        devices=(${group_map[$g]})
        echo "  Group $g: ${#devices[@]} device(s): ${devices[*]}"
        if [ "${#devices[@]}" -gt 1 ]; then
            log_warn "Group $g contains multiple devices: this may block clean passthrough."
        else
            log_ok "Group $g appears isolated (good for passthrough)."
        fi
    done
}

# Check 7: Distro and kernel info
check_system_info() {
    log_info "Gathering system information..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${PRETTY_NAME:-$NAME}"
    else
        DISTRO="Unknown"
    fi
    KERNEL="$(uname -r)"
    echo "  Distro: $DISTRO"
    echo "  Kernel: $KERNEL"
    INFO_COUNT=$((INFO_COUNT)) # no-op to avoid unset warnings
    if [[ "$DISTRO" != *"Fedora"* ]]; then
        log_warn "Janus is focused around Fedora KDE; other distributions may require package/path adjustments."
    else
        log_ok "Compatible distribution detected (Fedora)."
    fi
}

# Detailed iommu groups display (interactive or forced)
check_iommu_groups() {
    log_info "Detailed list of IOMMU groups and their devices..."
    if [ ! -d /sys/kernel/iommu_groups ]; then
        log_critical "Could not find /sys/kernel/iommu_groups. Confirm IOMMU is enabled."
        return
    fi
    for group in /sys/kernel/iommu_groups/*; do
        group_id=$(basename "$group")
        echo -e "${BLUE}Group $group_id:${NC}"
        for dev in "$group"/devices/*; do
            devname=$(basename "$dev")
            echo "  $(lspci -s "${devname#0000:}" -nn || echo "  - $devname")"
        done
        echo ""
    done
    log_info "Tip: Ideally the GPU and its HDMI/DP audio are in isolated groups or only with closely related devices."
}

# ---------------------------
# MAIN
# ---------------------------

main() {
    # parse flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) show_help ;;
            --version|-v) echo "janus-check v$VERSION"; exit 0 ;;
            --no-interactive) NO_INTERACTIVE=1 ;;
            *) echo "Unknown option: $1"; show_help ;;
        esac
        shift
    done

    check_system_info
    echo "────────────────────────────────────────"
    check_cpu_virt
    echo "────────────────────────────────────────"
    check_iommu
    echo "────────────────────────────────────────"
    check_virt_tools
    echo "────────────────────────────────────────"
    check_kernel_modules
    echo "────────────────────────────────────────"
    check_hugepages
    echo "────────────────────────────────────────"
    check_gpus
    echo "────────────────────────────────────────"

    if [ "$NO_INTERACTIVE" -eq 0 ]; then
        read -r -p "Show detailed IOMMU groups? (y/N): " confirm || true
        if [[ "$confirm" =~ ^[Yy] ]]; then
            echo "────────────────────────────────────────"
            check_iommu_groups
        fi
    else
        log_info "Non-interactive mode: skipping IOMMU group prompt."
    fi

    log_ok "Diagnostic complete."
    log_info "Share $LOG_FILE in issues to help debugging."
    finish
}

main "$@"
