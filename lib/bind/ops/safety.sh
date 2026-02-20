#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Safety Checks
# ----------------------------------------------------------------------------
# This file evaluates basic IOMMU isolation safety before binding.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_OP_SAFETY_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_OP_SAFETY_LOADED=1

# Assess whether a target IOMMU group appears reasonably isolated.
janus_bind_analyze_group_safety() {
    local group="$1"
    local devices=()

    if [ "$group" = "none" ]; then
        janus_bind_log_warn "IOMMU group is unknown for target device."
        return 1
    fi

    if [ ! -d "/sys/kernel/iommu_groups/$group/devices" ]; then
        janus_bind_log_warn "IOMMU group path does not exist: $group"
        return 1
    fi

    mapfile -t devices < <(
        for dev in "/sys/kernel/iommu_groups/$group/devices"/*; do
            [ -e "$dev" ] && basename "$dev"
        done
    )

    if [ "${#devices[@]}" -eq 0 ]; then
        janus_bind_log_warn "IOMMU group $group has no visible devices."
        return 1
    fi

    if [ "${#devices[@]}" -gt 2 ]; then
        janus_bind_log_warn "Group $group contains ${#devices[@]} devices. Passthrough may be unsafe."
        return 1
    fi

    janus_bind_log_ok "Group $group appears reasonably isolated."
    return 0
}
