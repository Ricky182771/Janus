#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Device Listing
# ----------------------------------------------------------------------------
# This file lists candidate display devices for VFIO workflows.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_OP_LIST_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_OP_LIST_LOADED=1

# List VGA/3D/Display PCI devices with driver and IOMMU group.
janus_bind_list_devices() {
    local lines=()
    local line=""
    local address=""
    local pci=""
    local driver=""
    local group=""
    local index=0

    janus_bind_require_cmd "lspci" "Device listing"

    janus_bind_log_info "Detecting VGA / 3D / Display devices"

    mapfile -t lines < <(lspci -nn | grep -Ei 'VGA|3D controller|Display')
    if [ "${#lines[@]}" -eq 0 ]; then
        janus_bind_log_warn "No GPU devices detected."
        return
    fi

    for line in "${lines[@]}"; do
        address="$(awk '{print $1}' <<< "$line")"
        pci="0000:$address"
        driver="$(janus_bind_pci_driver "$pci")"
        group="$(janus_bind_pci_iommu_group "$pci")"

        printf '[%d] %s  Driver: %s  Group: %s\n' "$index" "$pci" "$driver" "$group"
        printf '    %s\n' "$line"

        index=$((index + 1))
    done
}
