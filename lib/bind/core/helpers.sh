#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Helpers
# ----------------------------------------------------------------------------
# This file provides low-level VFIO helper functions.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_HELPERS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_HELPERS_LOADED=1

# Require root for mutating operations.
janus_bind_require_root() {
    janus_require_root "janus-bind" || exit 1
}

# Require an external command.
janus_bind_require_cmd() {
    local cmd="$1"
    local context="$2"

    command -v "$cmd" >/dev/null 2>&1 || janus_bind_die "$context requires '$cmd' (install missing package)."
}

# Normalize PCI format into domain-prefixed notation.
janus_bind_normalize_pci() {
    local raw="${1,,}"

    if [[ "$raw" =~ ^[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
        printf '%s' "0000:$raw"
        return 0
    fi

    if [[ "$raw" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]]; then
        printf '%s' "$raw"
        return 0
    fi

    return 1
}

# Ensure a PCI device exists in sysfs.
janus_bind_require_existing_pci() {
    local pci="$1"

    [ -d "/sys/bus/pci/devices/$pci" ] || janus_bind_die "PCI device does not exist: $pci"
}

# Ensure an IOMMU group id contains only digits.
janus_bind_require_numeric_group() {
    [[ "$1" =~ ^[0-9]+$ ]] || janus_bind_die "Invalid IOMMU group: $1"
}

# Read the currently bound kernel driver for a PCI device.
janus_bind_pci_driver() {
    local pci="$1"

    if [ -e "/sys/bus/pci/devices/$pci/driver" ]; then
        basename "$(readlink -f "/sys/bus/pci/devices/$pci/driver")"
    else
        printf '%s' "none"
    fi
}

# Read vendor:device id pair for a PCI device.
janus_bind_pci_vendor_device() {
    local pci="$1"
    local vendor=""
    local device=""

    [ -d "/sys/bus/pci/devices/$pci" ] || return 1

    vendor="$(cat "/sys/bus/pci/devices/$pci/vendor")" || return 1
    device="$(cat "/sys/bus/pci/devices/$pci/device")" || return 1

    printf '%s:%s' "${vendor#0x}" "${device#0x}"
}

# Resolve the IOMMU group id for a PCI device.
janus_bind_pci_iommu_group() {
    local pci="$1"

    if [ -e "/sys/bus/pci/devices/$pci/iommu_group" ]; then
        basename "$(readlink -f "/sys/bus/pci/devices/$pci/iommu_group")"
    else
        printf '%s' "none"
    fi
}

# Prompt for confirmation unless --yes was provided.
janus_bind_confirm() {
    [ "$JANUS_BIND_ASSUME_YES" -eq 1 ] && return 0
    janus_confirm "$1"
}
