#!/usr/bin/env bash
set -euo pipefail

# Janus Project - Diagnostic Tool v0.1
# Copyright (C) 2026 Ricardo (Ricky182771)

# ──────────────────────────────────────────────────────────────────────────────
# LOGGING SETUP
# ──────────────────────────────────────────────────────────────────────────────
LOG_DIR="$HOME/.cache/janus"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/last_check_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Janus Diagnostic v0.1 - $(date '+%Y-%m-%d %H:%M:%S') ==="

# ──────────────────────────────────────────────────────────────────────────────
# COLORS
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# BANNER
# ──────────────────────────────────────────────────────────────────────────────
clear
echo -e "${BLUE}"
echo " 🏛️  JANUS PROJECT | Diagnostic Tool v0.1"
echo " ────────────────────────────────────────"
echo -e "${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# CHECKS
# ──────────────────────────────────────────────────────────────────────────────
check_cpu_virt() {
    log_info "Checking CPU virtualization support (VT-x / AMD-V)..."
    if grep -E -c '(vmx|svm)' /proc/cpuinfo | grep -q '[1-9]'; then
        log_success "Virtualization support detected."
    else
        log_error "No virtualization support. Enable in BIOS."
    fi
}

check_iommu() {
    log_info "Verifying Kernel IOMMU status..."
    if [ -d "/sys/kernel/iommu_groups" ] && ls /sys/kernel/iommu_groups/* >/dev/null 2>&1; then
        log_success "IOMMU active with populated groups."
    else
        log_warn "IOMMU not active or empty."
        log_info "Add to GRUB: intel_iommu=on iommu=pt (Intel) or amd_iommu=on (AMD)"
        log_info "Then: sudo grub2-mkconfig -o /boot/grub2/grub.cfg && reboot"
    fi
}

check_virt_tools() {
    log_info "Checking libvirt & QEMU..."
    if command -v virsh >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
        log_success "libvirt and QEMU tools found."
    else
        log_error "Missing tools. Install: sudo dnf install libvirt qemu-kvm virt-manager"
    fi
}

check_gpus() {
    log_info "Detecting GPUs..."
    GPUS=$(lspci -nnk | grep -iE 'vga|3d|display' | wc -l)
    if [ "$GPUS" -ge 2 ]; then
        log_success "$GPUS GPUs → Good for multi-GPU passthrough"
    else
        log_warn "Only $GPUS GPU → Single-GPU or IDD mode needed"
    fi
    lspci -nnk | grep -iE 'vga|3d|display' | sed 's/^/  - /'
}

check_iommu_groups() {
    log_info "Detailed IOMMU Group analysis..."
    if [ ! -d "/sys/kernel/iommu_groups" ]; then
        log_error "IOMMU groups not found."
        return
    fi
    for g in /sys/kernel/iommu_groups/*; do
        echo -e "${BLUE}Group $(basename "$g"):${NC}"
        for d in "$g"/devices/*; do
            echo "  $(lspci -nns "${d##*/}")"
        done
    done
    log_warn "Ideal: GPU + Audio isolated from SATA/NVMe/USB/Ethernet."
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────
main() {
    check_cpu_virt
    echo "────────────────────────────────────────"
    check_iommu
    echo "────────────────────────────────────────"
    check_virt_tools
    echo "────────────────────────────────────────"
    check_gpus
    echo "────────────────────────────────────────"

    read -p "Show detailed IOMMU groups? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "────────────────────────────────────────"
        check_iommu_groups
    fi

    echo "────────────────────────────────────────"
    log_success "Diagnostic complete!"
    log_info "Full log: $LOG_FILE"
    log_info "Share this in GitHub issues if needed."
}

main "$@"
