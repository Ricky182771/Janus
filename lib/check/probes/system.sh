#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check System Probes
# ----------------------------------------------------------------------------
# This file provides generic host-level probe helpers.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_PROBE_SYSTEM_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_PROBE_SYSTEM_LOADED=1

# Test if a command exists in PATH.
janus_check_have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Require a command or emit a warning and skip related checks.
janus_check_require_cmd_or_warn() {
    local cmd="$1"
    local context="$2"

    if janus_check_have_cmd "$cmd"; then
        return 0
    fi

    janus_check_log_warn "$context skipped: required command '$cmd' is not installed."
    return 1
}

# Gather and display distro/kernel metadata.
janus_check_probe_system_info() {
    local distro="Unknown"
    local kernel=""

    janus_check_log_info "Gathering system information..."

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        distro="${PRETTY_NAME:-$NAME}"
    fi

    kernel="$(uname -r)"

    printf '  Distro: %s\n' "$distro"
    printf '  Kernel: %s\n' "$kernel"

    if [[ "$distro" == *"Fedora"* ]]; then
        janus_check_log_ok "Compatible distribution detected (Fedora)."
    else
        janus_check_log_warn "Janus is focused around Fedora KDE; other distributions may require package/path adjustments."
    fi
}

# Inspect hugepages and print a recommendation.
janus_check_probe_hugepages() {
    local total_kb=0
    local total_gb=0
    local recommend=0
    local actual=0

    janus_check_log_info "Checking hugepages (recommended for high-performance VMs)..."

    total_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo || echo 0)"
    total_gb=$((total_kb / 1024 / 1024))
    recommend=$((total_gb * 64))
    actual="$(grep -E '^HugePages_Total' /proc/meminfo | awk '{print $2}' || echo 0)"

    if [ -n "$actual" ] && [ "$actual" -ge 1 ]; then
        janus_check_log_ok "HugePages present: $actual (recommended ~ $recommend)"
        return 0
    fi

    janus_check_log_warn "HugePages not enabled. Recommended for this machine: vm.nr_hugepages = $recommend"
    janus_check_log_info "Example: echo 'vm.nr_hugepages = $recommend' | sudo tee /etc/sysctl.d/99-hugepages.conf && sudo sysctl -p"
}
