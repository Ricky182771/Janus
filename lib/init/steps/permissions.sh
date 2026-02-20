#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init Permission Steps
# ----------------------------------------------------------------------------
# This file performs non-destructive host permission checks.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_STEP_PERMISSIONS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_STEP_PERMISSIONS_LOADED=1

# Verify whether the current user is part of a required group.
janus_init_check_group() {
    local group="$1"

    if groups | grep -qw "$group"; then
        janus_init_log_ok "User belongs to '$group' group"
    else
        janus_init_log_warn "User is NOT in '$group' group"
        janus_init_log_info "Suggestion: sudo usermod -aG $group \$USER && re-login"
    fi
}

# Run non-destructive permission checks for virtualization.
janus_init_check_permissions() {
    janus_init_log_info "Checking user permissions (non-destructive)"

    janus_init_check_group "kvm"
    janus_init_check_group "libvirt"

    if ! command -v systemctl >/dev/null 2>&1; then
        janus_init_log_warn "systemctl not available; skipping libvirtd service check."
        return 0
    fi

    if systemctl is-active libvirtd >/dev/null 2>&1; then
        janus_init_log_ok "libvirtd service is active"
    else
        janus_init_log_warn "libvirtd service is not active"
        janus_init_log_info "Suggestion: sudo systemctl enable --now libvirtd"
    fi
}
