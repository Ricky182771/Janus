#!/bin/bash
set -euo pipefail

#---- LOG INFO ----
LOG_DIR="$HOME/.cache/janus"
mkdir -p "$LOG_DIR"
LOG_FILE="$$   LOG_DIR/last_check_   $$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Janus Diagnostic v0.1 - $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

# ---- INTERFACE COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- HEADER BANNER ---
clear
echo -e "${BLUE}"
echo "  🏛️  JANUS PROJECT | Diagnostic Tool v0.1"
echo "  ---------------------------------------"
echo -e "${NC}"

# --- LOGGING FUNCTIONS ---
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 1. CPU VIRTUALIZATION CHECK ---
check_cpu_virt() {
    log_info "Checking CPU virtualization support..."
    VIRT_SUPPORT=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
    if [ "$VIRT_SUPPORT" -gt 0 ]; then
        log_success "Hardware support detected (VT-x/AMD-V)."
    else
        log_error "Virtualization is not enabled in BIOS or your CPU does not support it."
    fi
}

# --- 2. KERNEL IOMMU CHECK ---
check_iommu() {
    log_info "Verifying Kernel IOMMU status..."
    if [ -d "/sys/kernel/iommu_groups" ] && [ "$(ls -A /sys/kernel/iommu_groups)" ]; then
        log_success "IOMMU is active and groups are populated."
    else
        log_warn "IOMMU does not appear to be active. Check GRUB parameters (intel_iommu=on or amd_iommu=on)."
    fi
}

# --- 3. GPU DETECTION ---
check_gpus() {
    log_info "Detecting GPUs..."
    GPUS=$(lspci -nnk | grep -iE 'vga|3d|display' | wc -l)
    if [ "$GPUS" -ge 2 ]; then
        log_success "$GPUS GPUs detected → Good for standard VFIO passthrough"
    else
        log_warn "Only $GPUS GPU detected → Consider Single-GPU Passthrough or IDD mode (Looking Glass experimental)"
    fi
    lspci -nnk | grep -iE 'vga|3d|display' | while read line; do
        echo "  - $line"
    done
}

#---- 4. CHECK VIRTUALIZATION CAPABILITIES ----
check_virt_tools() {
    log_info "Checking virtualization tools..."
    if command -v virsh >/dev/null 2>&1 && command -v qemu-img >/dev/null 2>&1; then
        log_success "libvirt & QEMU installed"
    else
        log_error "Missing libvirt or QEMU. Install with: sudo dnf install libvirt qemu-kvm virt-manager"
    fi
}

# --- 5. DETAILED IOMMU GROUP ANALYSIS ---
check_iommu() {
    log_info "Verifying Kernel IOMMU status..."
    if [ -d "/sys/kernel/iommu_groups" ] && ls /sys/kernel/iommu_groups/* >/dev/null 2>&1; then
        log_success "IOMMU is active and groups are populated."
    else
        log_warn "IOMMU not active or no groups found."
        log_info "Try adding to GRUB: intel_iommu=on iommu=pt (Intel) or amd_iommu=on (AMD)"
        log_info "Then run: sudo grub2-mkconfig -o /boot/grub2/grub.cfg && reboot"
    fi
}

# --- MAIN EXECUTION ---
main() {
    check_cpu_virt
    echo "---------------------------------------"
    check_iommu
    echo "---------------------------------------"
    check_gpus
    echo "---------------------------------------"
    
    read -p "Would you like to see the detailed IOMMU group breakdown? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        check_iommu_groups
    fi
    
    echo "---------------------------------------"
    log_info "Full log saved to: $LOG_FILE"
    log_info "Diagnostic finished. Copy this report if you need assistance on GitHub!"
}

main
