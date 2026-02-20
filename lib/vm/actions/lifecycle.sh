#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Lifecycle Actions
# ----------------------------------------------------------------------------
# This file contains start, stop, and status actions.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_ACTION_LIFECYCLE_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_ACTION_LIFECYCLE_LOADED=1

# Start VM when it is not already running.
janus_vm_start() {
    janus_vm_ensure_virsh_connection
    janus_vm_domain_exists || janus_vm_die "VM not defined: $JANUS_VM_NAME"

    if [ "$(janus_vm_domain_state)" = "running" ]; then
        janus_vm_log_info "VM is already running: $JANUS_VM_NAME"
        return 0
    fi

    virsh -c "$JANUS_VM_CONNECT_URI" start "$JANUS_VM_NAME" >/dev/null || janus_vm_die "Failed to start VM."
    janus_vm_log_ok "VM started: $JANUS_VM_NAME"
}

# Request graceful shutdown or force-stop VM.
janus_vm_stop() {
    local state=""

    janus_vm_ensure_virsh_connection
    janus_vm_domain_exists || janus_vm_die "VM not defined: $JANUS_VM_NAME"

    state="$(janus_vm_domain_state)"
    if [ "$state" = "shut off" ]; then
        janus_vm_log_info "VM is already stopped: $JANUS_VM_NAME"
        return 0
    fi

    if [ "$JANUS_VM_FORCE" -eq 1 ]; then
        janus_vm_confirm "Force-stop VM using virsh destroy?" || {
            janus_vm_log_warn "Aborted by user."
            return 0
        }

        virsh -c "$JANUS_VM_CONNECT_URI" destroy "$JANUS_VM_NAME" >/dev/null || janus_vm_die "Failed to force-stop VM."
        janus_vm_log_ok "VM force-stopped: $JANUS_VM_NAME"
        return 0
    fi

    virsh -c "$JANUS_VM_CONNECT_URI" shutdown "$JANUS_VM_NAME" >/dev/null || janus_vm_die "Failed to request VM shutdown."
    janus_vm_log_ok "Shutdown signal sent: $JANUS_VM_NAME"
}

# Print domain status and metadata.
janus_vm_status() {
    janus_vm_ensure_virsh_connection

    if ! janus_vm_domain_exists; then
        janus_vm_log_warn "VM is not defined: $JANUS_VM_NAME"
        return 1
    fi

    janus_vm_log_info "VM status for: $JANUS_VM_NAME"
    printf '  State: %s\n' "$(janus_vm_domain_state)"
    virsh -c "$JANUS_VM_CONNECT_URI" dominfo "$JANUS_VM_NAME" | sed 's/^/  /'
}
