#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Context
# ----------------------------------------------------------------------------
# This file defines shared state and defaults for janus-vm modules.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_CONTEXT_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_CONTEXT_LOADED=1

JANUS_VM_VERSION="0.2"

JANUS_VM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JANUS_VM_TEMPLATE_DIR="$JANUS_ROOT_DIR/templates/libvirt"

JANUS_VM_CONFIG_DIR="$HOME/.config/janus/vm"
JANUS_VM_DEF_DIR="$JANUS_VM_CONFIG_DIR/definitions"
JANUS_VM_NVRAM_DIR="$JANUS_VM_CONFIG_DIR/nvram"
JANUS_VM_UNATTEND_DIR="$JANUS_VM_CONFIG_DIR/unattend"
JANUS_VM_DEFAULT_DISK_DIR="$HOME/.local/share/janus/vms"

JANUS_VM_ACTION=""
JANUS_VM_NAME="janus-win11"
JANUS_VM_MODE="base"
JANUS_VM_MEMORY_MIB="16384"
JANUS_VM_VCPUS="8"
JANUS_VM_STORAGE_MODE="file"
JANUS_VM_DISK_SIZE="120G"
JANUS_VM_DISK_PATH=""
JANUS_VM_ISO_PATH=""
JANUS_VM_NETWORK_NAME="default"
JANUS_VM_CONNECT_URI="qemu:///system"
JANUS_VM_OVMF_CODE=""
JANUS_VM_OVMF_VARS=""
JANUS_VM_GPU_PCI=""
JANUS_VM_GPU_AUDIO_PCI=""
JANUS_VM_SINGLE_GPU_MODE="shared-vram"
JANUS_VM_GUIDED_MODE="auto"
JANUS_VM_UNATTENDED_ENABLED=0
JANUS_VM_WIN_USERNAME=""
JANUS_VM_WIN_PASSWORD=""
JANUS_VM_APPLY=0
JANUS_VM_ASSUME_YES=0
JANUS_VM_FORCE=0

# Parsed PCI components for passthrough rendering.
JANUS_VM_GPU_DOMAIN=""
JANUS_VM_GPU_BUS=""
JANUS_VM_GPU_SLOT=""
JANUS_VM_GPU_FUNCTION=""
JANUS_VM_GPU_AUDIO_DOMAIN=""
JANUS_VM_GPU_AUDIO_BUS=""
JANUS_VM_GPU_AUDIO_SLOT=""
JANUS_VM_GPU_AUDIO_FUNCTION=""

# Emit a standard INFO message.
janus_vm_log_info() {
    janus_log_info "$*"
}

# Emit a standard OK message.
janus_vm_log_ok() {
    janus_log_ok "$*"
}

# Emit a standard WARN message.
janus_vm_log_warn() {
    janus_log_warn "$*"
}

# Emit a standard ERROR message.
janus_vm_log_error() {
    janus_log_error "$*"
}

# Exit with a VM-specific error message.
janus_vm_die() {
    janus_vm_log_error "$1"
    exit 1
}
