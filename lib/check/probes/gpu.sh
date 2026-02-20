#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check GPU Probes
# ----------------------------------------------------------------------------
# This file inspects GPUs, active drivers, and IOMMU group topology.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_PROBE_GPU_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_PROBE_GPU_LOADED=1

# Resolve the IOMMU group id for a PCI device.
janus_check_pci_iommu_group() {
    local pci="$1"

    if [ -e "/sys/bus/pci/devices/$pci/iommu_group" ]; then
        basename "$(readlink -f "/sys/bus/pci/devices/$pci/iommu_group")"
    else
        printf '%s' "none"
    fi
}

# Detect GPU devices and summarize isolation state.
janus_check_probe_gpus() {
    local gpu_lines=()
    local line=""
    local address=""
    local pci=""
    local driver=""
    local group=""
    local gpu_count=0
    local g=""

    janus_check_require_cmd_or_warn "lspci" "GPU detection" || return

    if ! lspci -nn >/dev/null 2>&1; then
        janus_check_log_warn "GPU detection skipped: 'lspci' command is present but failed to execute."
        return
    fi

    janus_check_log_info "Detecting GPUs and drivers (PCI addresses + driver + IOMMU group)..."

    mapfile -t gpu_lines < <(lspci -nn | grep -iE 'VGA|3D controller|Display' || true)
    if [ "${#gpu_lines[@]}" -eq 0 ]; then
        janus_check_log_warn "No video controllers found (lspci returned no VGA/Display entries)."
        return
    fi

    declare -A janus_check_group_map=()

    for line in "${gpu_lines[@]}"; do
        address="$(awk '{print $1}' <<< "$line")"
        if [[ "$address" != 0000:* ]]; then
            pci="0000:$address"
        else
            pci="$address"
        fi

        gpu_count=$((gpu_count + 1))
        driver=""

        if [ -e "/sys/bus/pci/devices/$pci/driver" ]; then
            driver="$(basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")" || true)"
        fi

        group="$(janus_check_pci_iommu_group "$pci")"
        janus_check_group_map["$group"]+="$pci "

        printf '  - PCI: %s\n' "$pci"
        printf '      Desc: %s\n' "$(lspci -s "$address" -nn)"

        if [ -n "$driver" ]; then
            printf '      Driver: %s\n' "$driver"
        else
            printf '      Driver: (none)\n'
        fi

        printf '      IOMMU group: %s\n' "$group"
        printf '\n'
    done

    if [ "$gpu_count" -ge 2 ]; then
        janus_check_log_ok "$gpu_count GPUs detected (multi-GPU)."
    else
        janus_check_log_warn "$gpu_count GPU(s) detected. Multi-GPU is recommended for dedicated passthrough."
    fi

    janus_check_log_info "Analyzing IOMMU groups (summary)..."
    for g in "${!janus_check_group_map[@]}"; do
        local devices=()
        devices=(${janus_check_group_map[$g]})

        printf '  Group %s: %d device(s): %s\n' "$g" "${#devices[@]}" "${devices[*]}"

        if [ "${#devices[@]}" -gt 1 ]; then
            janus_check_log_warn "Group $g contains multiple devices: this may block clean passthrough."
        else
            janus_check_log_ok "Group $g appears isolated (good for passthrough)."
        fi
    done
}

# Print detailed mapping of all IOMMU groups.
janus_check_probe_iommu_groups_detailed() {
    local group_path=""
    local group_id=""
    local dev=""
    local dev_name=""

    janus_check_require_cmd_or_warn "lspci" "Detailed IOMMU group listing" || return

    if ! lspci -nn >/dev/null 2>&1; then
        janus_check_log_warn "Detailed IOMMU group listing skipped: 'lspci' command is present but failed to execute."
        return
    fi

    janus_check_log_info "Detailed list of IOMMU groups and their devices..."

    if [ ! -d /sys/kernel/iommu_groups ]; then
        janus_check_log_critical "Could not find /sys/kernel/iommu_groups. Confirm IOMMU is enabled."
        return
    fi

    for group_path in /sys/kernel/iommu_groups/*; do
        group_id="$(basename "$group_path")"
        printf 'Group %s:\n' "$group_id"

        for dev in "$group_path"/devices/*; do
            dev_name="$(basename "$dev")"
            printf '  %s\n' "$(lspci -s "${dev_name#0000:}" -nn || echo "$dev_name")"
        done

        printf '\n'
    done

    janus_check_log_info "Tip: Ideally the GPU and its HDMI/DP audio are in isolated groups or only with closely related devices."
}
