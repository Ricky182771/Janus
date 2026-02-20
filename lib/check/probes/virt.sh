#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check Virtualization Probes
# ----------------------------------------------------------------------------
# This file includes virtualization and kernel capability checks.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_PROBE_VIRT_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_PROBE_VIRT_LOADED=1

# Validate CPU virtualization support and /dev/kvm presence.
janus_check_probe_cpu_virt() {
    local cpu_flags=""

    janus_check_log_info "Checking CPU virtualization support (VT-x / AMD-V) and /dev/kvm..."

    cpu_flags="$(grep -m1 -oE 'vmx|svm' /proc/cpuinfo | head -n1 || true)"
    if [ -n "$cpu_flags" ]; then
        janus_check_log_ok "VT-x / AMD-V support detected: $cpu_flags"
    else
        janus_check_log_critical "No VT-x / AMD-V flags found in /proc/cpuinfo. Enable them in BIOS/UEFI."
    fi

    if [ -e /dev/kvm ]; then
        janus_check_log_ok "/dev/kvm present - KVM accessible"
    else
        janus_check_log_warn "/dev/kvm is missing. Verify KVM is enabled and your user has permissions (kvm_* module loaded)."
    fi
}

# Validate IOMMU state from kernel cmdline or sysfs groups.
janus_check_probe_iommu() {
    local cmdline=""

    janus_check_log_info "Checking IOMMU presence in kernel (cmdline + sysfs)..."

    cmdline="$(cat /proc/cmdline || true)"
    if echo "$cmdline" | grep -q -E 'intel_iommu=on|amd_iommu=on|iommu=pt'; then
        janus_check_log_ok "IOMMU enabled in kernel cmdline."
        return 0
    fi

    if [ -d /sys/kernel/iommu_groups ] && ls /sys/kernel/iommu_groups/* >/dev/null 2>&1; then
        janus_check_log_ok "IOMMU active and groups populated (detected via /sys/kernel/iommu_groups)."
        return 0
    fi

    janus_check_log_warn "IOMMU does not appear active in cmdline and /sys/kernel/iommu_groups looks empty."
    janus_check_log_info "Recommendation: add intel_iommu=on iommu=pt (Intel) or amd_iommu=on (AMD) to kernel cmdline."
}

# Verify required virtualization userspace tools.
janus_check_probe_virt_tools() {
    local missing=()
    local tool=""

    janus_check_log_info "Checking virtualization tools (libvirt/qemu/virsh/virt-manager)..."

    for tool in virsh qemu-img qemu-system-x86_64; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        janus_check_log_ok "libvirt/QEMU tools installed."
        return 0
    fi

    janus_check_log_warn "Missing tools: ${missing[*]}"
    janus_check_log_info "On Fedora: sudo dnf install libvirt qemu-kvm virt-manager"
    janus_check_log_info "On Debian/Ubuntu: sudo apt install qemu-kvm libvirt-clients libvirt-daemon-system virt-manager"
}

# Validate presence of VFIO/KVM kernel modules.
janus_check_probe_kernel_modules() {
    local cpu_vendor=""
    local required=(kvm vfio vfio_pci vfio_iommu_type1)
    local module=""

    janus_check_log_info "Checking kernel modules related to VFIO / KVM..."

    janus_check_require_cmd_or_warn "lsmod" "Kernel module check" || return

    if ! lsmod >/dev/null 2>&1; then
        janus_check_log_warn "Kernel module check skipped: 'lsmod' command is present but failed to execute."
        return
    fi

    cpu_vendor="$(awk -F: '/vendor_id/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"

    case "$cpu_vendor" in
        GenuineIntel)
            required+=(kvm_intel)
            ;;
        AuthenticAMD)
            required+=(kvm_amd)
            ;;
        *)
            required+=(kvm_intel kvm_amd)
            ;;
    esac

    for module in "${required[@]}"; do
        if lsmod | grep -q "^$module"; then
            janus_check_log_ok "Module loaded: $module"
        else
            janus_check_log_warn "Module not loaded: $module"
            janus_check_log_info "Load with: sudo modprobe $module (or persist via /etc/modules-load.d/janus.conf)"
        fi
    done
}
