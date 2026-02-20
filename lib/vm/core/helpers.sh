#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Helpers
# ----------------------------------------------------------------------------
# This file contains reusable utility helpers used across VM modules.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_HELPERS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_HELPERS_LOADED=1

# Confirm an operation unless --yes is enabled.
janus_vm_confirm() {
    [ "$JANUS_VM_ASSUME_YES" -eq 1 ] && return 0
    janus_confirm "$1"
}

# Require a command to exist.
janus_vm_require_cmd() {
    local cmd="$1"

    command -v "$cmd" >/dev/null 2>&1 || janus_vm_die "Required command not found: $cmd"
}

# Check if a value is an integer.
janus_vm_is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Detect whether current terminal is interactive.
janus_vm_is_interactive_tty() {
    janus_is_interactive_tty
}

# Prompt with a default value.
janus_vm_prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local out_var="$3"
    local input=""

    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " input || true
        [ -n "$input" ] || input="$default"
    else
        read -r -p "$prompt: " input || true
    fi

    printf -v "$out_var" '%s' "$input"
}

# Prompt for an optional secret value.
janus_vm_prompt_secret_optional() {
    local prompt="$1"
    local out_var="$2"
    local input=""

    read -r -s -p "$prompt: " input || true
    printf '\n'

    printf -v "$out_var" '%s' "$input"
}

# Escape XML special characters.
janus_vm_xml_escape() {
    local value="$1"

    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&apos;}"

    printf '%s' "$value"
}

# Normalize PCI string into full domain notation.
janus_vm_normalize_pci() {
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

# Parse a PCI id into libvirt hex fields.
janus_vm_parse_pci_parts() {
    local pci="$1"
    local prefix="$2"
    local domain=""
    local bus=""
    local slot=""
    local function=""

    pci="$(janus_vm_normalize_pci "$pci")" || janus_vm_die "Invalid PCI format: $1"
    IFS=':.' read -r domain bus slot function <<< "$pci"

    printf -v "${prefix}_DOMAIN" '0x%s' "$domain"
    printf -v "${prefix}_BUS" '0x%s' "$bus"
    printf -v "${prefix}_SLOT" '0x%s' "$slot"
    printf -v "${prefix}_FUNCTION" '0x%s' "$function"
}

# Escape text for sed replacement.
janus_vm_sed_escape() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

# Auto-detect OVMF code file path.
janus_vm_detect_ovmf_code() {
    local candidates=(
        /usr/share/edk2/ovmf/OVMF_CODE.fd
        /usr/share/OVMF/OVMF_CODE.fd
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
    )
    local path=""

    for path in "${candidates[@]}"; do
        [ -f "$path" ] && {
            printf '%s' "$path"
            return 0
        }
    done

    return 1
}

# Auto-detect OVMF vars template path.
janus_vm_detect_ovmf_vars() {
    local candidates=(
        /usr/share/edk2/ovmf/OVMF_VARS.fd
        /usr/share/OVMF/OVMF_VARS.fd
        /usr/share/edk2-ovmf/x64/OVMF_VARS.fd
    )
    local path=""

    for path in "${candidates[@]}"; do
        [ -f "$path" ] && {
            printf '%s' "$path"
            return 0
        }
    done

    return 1
}

# Verify libvirt connection availability.
janus_vm_ensure_virsh_connection() {
    janus_vm_require_cmd "virsh"
    virsh -c "$JANUS_VM_CONNECT_URI" uri >/dev/null 2>&1 || janus_vm_die "Unable to connect to libvirt URI: $JANUS_VM_CONNECT_URI"
}

# Return success when a domain already exists.
janus_vm_domain_exists() {
    virsh -c "$JANUS_VM_CONNECT_URI" dominfo "$JANUS_VM_NAME" >/dev/null 2>&1
}

# Query current domain state.
janus_vm_domain_state() {
    virsh -c "$JANUS_VM_CONNECT_URI" domstate "$JANUS_VM_NAME" 2>/dev/null | awk 'NR==1 {print $0}'
}
