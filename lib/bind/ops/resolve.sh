#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Target Resolution
# ----------------------------------------------------------------------------
# This file validates environment prerequisites and resolves target devices.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_OP_RESOLVE_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_OP_RESOLVE_LOADED=1

# Validate required sysfs paths.
janus_bind_validate_environment() {
    [ -d /sys/bus/pci/devices ] || janus_bind_die "PCI sysfs path is not available: /sys/bus/pci/devices"
}

# Resolve final device list from --device or --group.
janus_bind_resolve_targets() {
    local normalized=""

    if [ -n "$JANUS_BIND_TARGET_DEVICE" ] && [ -n "$JANUS_BIND_TARGET_GROUP" ]; then
        janus_bind_die "Use either --device or --group, not both."
    fi

    if [ -n "$JANUS_BIND_TARGET_DEVICE" ]; then
        normalized="$(janus_bind_normalize_pci "$JANUS_BIND_TARGET_DEVICE")" \
            || janus_bind_die "Invalid PCI format: $JANUS_BIND_TARGET_DEVICE"

        janus_bind_require_existing_pci "$normalized"
        JANUS_BIND_DEVICES=("$normalized")
        return
    fi

    if [ -n "$JANUS_BIND_TARGET_GROUP" ]; then
        janus_bind_require_numeric_group "$JANUS_BIND_TARGET_GROUP"

        [ -d "/sys/kernel/iommu_groups/$JANUS_BIND_TARGET_GROUP/devices" ] \
            || janus_bind_die "IOMMU group not found: $JANUS_BIND_TARGET_GROUP"

        mapfile -t JANUS_BIND_DEVICES < <(
            for dev in "/sys/kernel/iommu_groups/$JANUS_BIND_TARGET_GROUP/devices"/*; do
                [ -e "$dev" ] && basename "$dev"
            done
        )

        [ "${#JANUS_BIND_DEVICES[@]}" -gt 0 ] || janus_bind_die "No devices found in IOMMU group $JANUS_BIND_TARGET_GROUP"
        return
    fi

    janus_bind_die "No target specified. Use --device or --group."
}
