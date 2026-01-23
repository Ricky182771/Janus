#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Janus Project - Diagnostic Tool (janus-check) v0.1
# ──────────────────────────────────────────────────────────────────────────────
# Copyright (C) 2026 Ricardo (Ricky182771) <your-email@example.com>
# Licensed under GNU GPL v3.0 - See LICENSE file in the repository.
#
# Description:
# This script performs a comprehensive hardware and software diagnostic for
# Janus Project compatibility. It checks key requirements for VFIO GPU
# passthrough, KVM virtualization, and hybrid Linux-Windows setups.
#
# Key Features:
# - Colored terminal output for readability
# - Full logging to ~/.cache/janus/ for issue reporting
# - Modular checks: Easy to add new functions or modules
# - Interactive: Asks for detailed IOMMU groups if desired
# - Flags: --help, --version
#
# Usage:
#   ./janus-check [--help | --version]
#
# To contribute: See CONTRIBUTING.md. Add new checks as functions and PR!
#
# Dependencies: lspci, grep, egrep (standard on most Linux distros)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail  # Enable strict mode: exit on error, undefined vars, pipe failures

# ──────────────────────────────────────────────────────────────────────────────
# CONSTANTS & GLOBALS
# ──────────────────────────────────────────────────────────────────────────────
VERSION="0.1"
LOG_DIR="$HOME/.cache/janus"
LOG_FILE="$LOG_DIR/last_check_$(date +%Y%m%d_%H%M%S).log"

# Create log dir if not exists
mkdir -p "$LOG_DIR"

# Redirect all output (stdout + stderr) to log file + terminal
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Janus Diagnostic v$VERSION - $(date '+%Y-%m-%d %H:%M:%S') ==="

# ──────────────────────────────────────────────────────────────────────────────
# COLORS FOR TERMINAL OUTPUT
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ──────────────────────────────────────────────────────────────────────────────
# LOGGING FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
# These print to terminal with color and append to log file implicitly (via exec)
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }  # Exit on error for critical fails

# ──────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────
# Display help message
show_help() {
    echo -e "${BLUE}Usage:${NC} ./janus-check [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --version, -v  Show version"
    echo ""
    echo "Description: Runs hardware diagnostics for Janus Project compatibility."
    echo "Log saved to: $LOG_FILE"
    exit 0
}

# ──────────────────────────────────────────────────────────────────────────────
# DIAGNOSTIC CHECKS (MODULAR - ADD NEW ONES HERE)
# ──────────────────────────────────────────────────────────────────────────────
# Check 1: CPU Virtualization Support (VT-x / AMD-V)
check_cpu_virt() {
    log_info "Checking CPU virtualization support (VT-x / AMD-V)..."
    if grep -E -c '(vmx|svm)' /proc/cpuinfo | grep -q '[1-9]'; then
        log_success "Virtualization support detected in CPU."
    else
        log_error "No virtualization support detected. Enable VT-x / AMD-V in BIOS."
    fi
}

# Check 2: Kernel IOMMU Status
check_iommu() {
    log_info "Verifying Kernel IOMMU status..."
    if [ -d "/sys/kernel/iommu_groups" ] && ls /sys/kernel/iommu_groups/* >/dev/null 2>&1; then
        log_success "IOMMU active with populated groups."
    else
        log_warn "IOMMU not active or no groups found."
        log_info "Recommendation: Add to GRUB cmdline (in /etc/default/grub):"
        log_info "  For Intel: intel_iommu=on iommu=pt"
        log_info "  For AMD: amd_iommu=on"
        log_info "Then: sudo grub2-mkconfig -o /boot/grub2/grub.cfg && reboot"
    fi
}

# Check 3: Virtualization Tools (libvirt, QEMU)
check_virt_tools() {
    log_info "Checking libvirt & QEMU tools..."
    if command -v virsh >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
        log_success "libvirt and QEMU installed."
    else
        log_error "Missing virtualization tools."
        log_info "Install on Fedora: sudo dnf install libvirt qemu-kvm virt-manager"
        log_info "On other distros: Use apt/yum equivalent."
    fi
}

# Check 4: GPU Detection
check_gpus() {
    log_info "Detecting GPUs..."
    GPUS=$(lspci -nnk | grep -iE 'vga|3d|display' | wc -l)
    if [ "$GPUS" -ge 2 ]; then
        log_success "$GPUS GPUs detected → Suitable for multi-GPU passthrough."
    else
        log_warn "Only $GPUS GPU detected → Consider Single-GPU passthrough or Looking Glass IDD mode."
    fi
    # Display details
    lspci -nnk | grep -iE 'vga|3d|display|Subsystem' | sed 's/^/  - /'
}

# Check 5: Kernel Modules (VFIO-related)
check_kernel_modules() {
    log_info "Checking VFIO kernel modules..."
    REQUIRED_MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "kvm")
    for mod in "${REQUIRED_MODULES[@]}"; do
        if lsmod | grep -q "$mod"; then
            log_success "Module $mod loaded."
        else
            log_warn "Module $mod not loaded."
            log_info "Load with: sudo modprobe $mod"
            log_info "For persistence: Add to /etc/modules-load.d/janus.conf"
        fi
    done
}

# Check 6: Hugepages Support (for performance optimization)
check_hugepages() {
    log_info "Checking hugepages support..."
    if grep -q 'HugePages_Total: * [1-9]' /proc/meminfo; then
        log_success "Hugepages enabled."
    else
        log_warn "Hugepages not enabled (recommended for VM performance)."
        log_info "To enable: echo 'vm.nr_hugepages = 1024' | sudo tee /etc/sysctl.d/99-hugepages.conf"
        log_info "Then: sudo sysctl -p && reboot"
    fi
}

# Check 7: Distro & Kernel Info (for compatibility reports)
check_system_info() {
    log_info "Gathering system info..."
    DISTRO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    KERNEL=$(uname -r)
    log_success "Distro: $DISTRO | Kernel: $KERNEL"
    if [[ ! "$DISTRO" =~ "Fedora" ]]; then
        log_warn "Janus is optimized for Fedora KDE; other distros may need adjustments."
    fi
}

# Check 8: Detailed IOMMU Groups Analysis
check_iommu_groups() {
    log_info "Detailed IOMMU Group analysis..."
    if [ ! -d "/sys/kernel/iommu_groups" ]; then
        log_error "IOMMU groups directory not found. See IOMMU check."
        return
    fi
    for group in /sys/kernel/iommu_groups/*; do
        group_id=$(basename "$group")
        echo -e "${BLUE}Group $group_id:${NC}"
        for device in "$group"/devices/*; do
            pci_id=$(basename "$device")
            echo "  $(lspci -nns "$pci_id")"
        done
        echo ""
    done
    log_warn "For optimal passthrough: Ensure GPU + Audio/USB are in isolated groups."
    log_warn "If groups are not isolated, consider ACS override or hardware changes."
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN EXECUTION
# ──────────────────────────────────────────────────────────────────────────────
main() {
    # Handle flags
    case "${1:-}" in
        --help|-h) show_help ;;
        --version|-v) echo "janus-check v$VERSION"; exit 0 ;;
    esac

    # Run all checks in sequence
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

    # Interactive detailed check
    read -p "Show detailed IOMMU groups? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "────────────────────────────────────────"
        check_iommu_groups
    fi

    echo "────────────────────────────────────────"
    log_success "Diagnostic complete!"
    log_info "Full log saved to: $LOG_FILE"
    log_info "Share this log or output in GitHub issues for feedback or contributions."
}

main "$@"
