#!/bin/bash

# --- INTERFACE COLORS ---
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
    log_info "Searching for GPUs in the system..."
    GPUS=$(lspci | grep -i 'vga\|display' | wc -l)
    if [ "$GPUS" -ge 2 ]; then
        log_success "$GPUS GPUs detected. System is suitable for Passthrough."
        lspci | grep -i 'vga\|display'
    else
        log_warn "Only one GPU detected ($GPUS). Janus will require Single-GPU Passthrough configuration."
    fi
}

# --- 4. DETAILED IOMMU GROUP ANALYSIS ---
check_iommu_groups() {
    log_info "Analyzing IOMMU Group isolation..."
    
    if [ ! -d "/sys/kernel/iommu_groups" ]; then
        log_error "IOMMU group directory not detected. Please verify step 2."
        return
    fi

    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
        echo -e "${BLUE}Group $(basename $g):${NC}"
        for d in $g/devices/*; do
            device_id=$(basename $d)
            echo -e "    $(lspci -nns $device_id)"
        done
    done

    echo ""
    log_warn "Note: For a successful passthrough, your secondary GPU and its Audio"
    log_warn "controller should be in an isolated group from other essential devices."
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
    log_info "Diagnostic finished. Copy this report if you need assistance on GitHub!"
}

main
