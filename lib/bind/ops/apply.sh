#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Apply/Rollback
# ----------------------------------------------------------------------------
# This file contains dry-run, apply, and rollback workflows.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_OP_APPLY_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_OP_APPLY_LOADED=1

# Print non-destructive preview for target devices.
janus_bind_dry_run() {
    local pci=""
    local driver=""
    local id=""
    local group=""

    janus_bind_log_info "DRY RUN - no changes will be applied"

    for pci in "${JANUS_BIND_DEVICES[@]}"; do
        janus_bind_require_existing_pci "$pci"

        driver="$(janus_bind_pci_driver "$pci")"
        id="$(janus_bind_pci_vendor_device "$pci")" || janus_bind_die "Unable to read vendor/device for $pci"
        group="$(janus_bind_pci_iommu_group "$pci")"

        printf -- '- Device: %s\n' "$pci"
        printf '    Current driver: %s\n' "$driver"
        printf '    Vendor:Device: %s\n' "$id"
        printf '    IOMMU group: %s\n' "$group"
        printf '    Action: unbind from %s -> bind to vfio-pci\n' "$driver"
        printf '\n'
    done
}

# Bind selected devices to vfio-pci and save rollback state.
janus_bind_apply() {
    local state_file=""
    local pci=""
    local driver=""
    local group=""
    local id=""

    janus_bind_require_root

    [ -e /sys/bus/pci/drivers/vfio-pci/bind ] || janus_bind_die "vfio-pci is not available. Load vfio-pci before applying."

    state_file="$JANUS_BIND_STATE_DIR/bind_$(date +%Y%m%d_%H%M%S).state"
    janus_bind_log_info "Saving bind state to $state_file"

    for pci in "${JANUS_BIND_DEVICES[@]}"; do
        janus_bind_require_existing_pci "$pci"

        driver="$(janus_bind_pci_driver "$pci")"
        group="$(janus_bind_pci_iommu_group "$pci")"
        id="$(janus_bind_pci_vendor_device "$pci")" || janus_bind_die "Unable to read vendor/device for $pci"

        janus_bind_log_debug "Binding $pci (driver=$driver, group=$group, id=$id)"

        {
            printf 'DEVICE=%s\n' "$pci"
            printf 'OLD_DRIVER=%s\n' "$driver"
            printf 'GROUP=%s\n' "$group"
            printf 'ID=%s\n' "$id"
            printf '%s\n' '---'
        } >> "$state_file"

        if [ "$driver" != "none" ]; then
            [ -e "/sys/bus/pci/drivers/$driver/unbind" ] || janus_bind_die "Missing unbind path for driver $driver"
            printf '%s' "$pci" > "/sys/bus/pci/drivers/$driver/unbind" || janus_bind_die "Failed to unbind $pci from $driver"
        fi

        printf '%s' "$id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || janus_bind_log_debug "Device ID $id is already registered in vfio-pci."
        printf '%s' "$pci" > /sys/bus/pci/drivers/vfio-pci/bind || janus_bind_die "Failed to bind $pci to vfio-pci"

        janus_bind_log_ok "Bound $pci to vfio-pci"
    done
}

# Restore latest saved bindings from state file.
janus_bind_rollback_last() {
    local last_state=""
    local line=""
    local pci=""
    local old_driver=""

    janus_bind_require_root

    last_state="$(ls -t "$JANUS_BIND_STATE_DIR"/bind_*.state 2>/dev/null | head -n1)"
    [ -n "$last_state" ] || janus_bind_die "No previous bind state found."

    janus_bind_log_info "Rolling back using $last_state"

    while IFS= read -r line; do
        case "$line" in
            DEVICE=*)
                pci="${line#DEVICE=}"
                ;;
            OLD_DRIVER=*)
                old_driver="${line#OLD_DRIVER=}"
                ;;
            ID=*)
                ;;
            ---)
                [ -n "$pci" ] || janus_bind_die "Corrupt state file: missing DEVICE entry."

                if [ "$(janus_bind_pci_driver "$pci")" = "vfio-pci" ]; then
                    [ -e /sys/bus/pci/drivers/vfio-pci/unbind ] || janus_bind_die "Missing vfio-pci unbind path."
                    printf '%s' "$pci" > /sys/bus/pci/drivers/vfio-pci/unbind || janus_bind_die "Failed to unbind $pci from vfio-pci"
                fi

                if [ "${old_driver:-none}" != "none" ]; then
                    [ -e "/sys/bus/pci/drivers/$old_driver/bind" ] || janus_bind_die "Missing bind path for driver $old_driver"
                    printf '%s' "$pci" > "/sys/bus/pci/drivers/$old_driver/bind" || janus_bind_die "Failed to rebind $pci to $old_driver"
                fi

                janus_bind_log_ok "Restored $pci to driver $old_driver"
                ;;
        esac
    done < "$last_state"
}
