#!/bin/bash

# --- COLORES PARA LA INTERFAZ ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- BANNER DE INICIO ---
clear
echo -e "${BLUE}"
echo "  🏛️  JANUS PROJECT | Diagnostic Tool v0.1"
echo "  ---------------------------------------"
echo -e "${NC}"

# --- FUNCIONES DE LOGGING ---
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 1. VERIFICACIÓN DE VIRTUALIZACIÓN (CPU) ---
check_cpu_virt() {
    log_info "Comprobando soporte de virtualización en CPU..."
    VIRT_SUPPORT=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
    if [ "$VIRT_SUPPORT" -gt 0 ]; then
        log_success "Soporte de hardware detectado (VT-x/AMD-V)."
    else
        log_error "La virtualización no está habilitada en la BIOS o tu CPU no la soporta."
    fi
}

# --- 2. VERIFICACIÓN DE IOMMU (KERNEL) ---
check_iommu() {
    log_info "Verificando estado de IOMMU en el Kernel..."
    if [ -d "/sys/kernel/iommu_groups" ] && [ "$(ls -A /sys/kernel/iommu_groups)" ]; then
        log_success "IOMMU está activo y los grupos están poblados."
    else
        log_warn "IOMMU no parece estar activo. Verifica los parámetros del GRUB (intel_iommu=on / amd_iommu=on)."
    fi
}

# --- 3. DETECCIÓN DE GPUs ---
check_gpus() {
    log_info "Buscando GPUs en el sistema..."
    GPUS=$(lspci | grep -i 'vga\|display' | wc -l)
    if [ "$GPUS" -ge 2 ]; then
        log_success "Se detectaron $GPUS GPUs. Sistema apto para Passthrough."
        lspci | grep -i 'vga\|display'
    else
        log_warn "Solo se detectó una GPU ($GPUS). Janus requerirá configuración Single-GPU Passthrough."
    fi
}

# --- EJECUCIÓN PRINCIPAL ---
main() {
    check_cpu_virt
    echo "---------------------------------------"
    check_iommu
    echo "---------------------------------------"
    check_gpus
    echo "---------------------------------------"
    
    log_info "Diagnóstico finalizado. Revisa los mensajes de [WARN] o [ERROR] antes de proceder."
}

main
