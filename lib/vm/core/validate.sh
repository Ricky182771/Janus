#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Validation
# ----------------------------------------------------------------------------
# This file validates arguments and prepares filesystem layout.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_VALIDATE_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_VALIDATE_LOADED=1

# Validate common options shared by all actions.
janus_vm_validate_common() {
    [ -n "$JANUS_VM_NAME" ] || janus_vm_die "VM name cannot be empty."
    [[ "$JANUS_VM_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || janus_vm_die "VM name contains invalid characters: $JANUS_VM_NAME"
}

# Validate create-specific options and derive defaults.
janus_vm_validate_create() {
    case "$JANUS_VM_MODE" in
        base|passthrough)
            ;;
        *)
            janus_vm_die "Invalid mode: $JANUS_VM_MODE (expected base|passthrough)"
            ;;
    esac

    case "$JANUS_VM_STORAGE_MODE" in
        file|block)
            ;;
        *)
            janus_vm_die "Invalid --storage mode: $JANUS_VM_STORAGE_MODE (expected file|block)"
            ;;
    esac

    case "$JANUS_VM_SINGLE_GPU_MODE" in
        shared-vram|cpu-only)
            ;;
        *)
            janus_vm_die "Invalid --single-gpu-mode: $JANUS_VM_SINGLE_GPU_MODE (expected shared-vram|cpu-only)"
            ;;
    esac

    janus_vm_is_integer "$JANUS_VM_MEMORY_MIB" || janus_vm_die "--memory-mib must be an integer."
    janus_vm_is_integer "$JANUS_VM_VCPUS" || janus_vm_die "--vcpus must be an integer."

    [ "$JANUS_VM_MEMORY_MIB" -gt 0 ] || janus_vm_die "--memory-mib must be > 0"
    [ "$JANUS_VM_VCPUS" -gt 0 ] || janus_vm_die "--vcpus must be > 0"

    if [ "$JANUS_VM_STORAGE_MODE" = "file" ]; then
        [ -n "$JANUS_VM_DISK_PATH" ] || JANUS_VM_DISK_PATH="$JANUS_VM_DEFAULT_DISK_DIR/${JANUS_VM_NAME}.qcow2"
        [ -n "$JANUS_VM_DISK_SIZE" ] || janus_vm_die "--disk-size cannot be empty for file storage."
    else
        [ -n "$JANUS_VM_DISK_PATH" ] || janus_vm_die "--disk-path is required for --storage block."

        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            [ -e "$JANUS_VM_DISK_PATH" ] || janus_vm_die "Block device path does not exist: $JANUS_VM_DISK_PATH"
            [ -b "$JANUS_VM_DISK_PATH" ] || janus_vm_die "--storage block requires a block device (expected /dev/...): $JANUS_VM_DISK_PATH"
        elif [ ! -e "$JANUS_VM_DISK_PATH" ]; then
            janus_vm_log_warn "Block device path does not exist on this host (dry-run only): $JANUS_VM_DISK_PATH"
        elif [ ! -b "$JANUS_VM_DISK_PATH" ]; then
            janus_vm_log_warn "Configured block storage is not a block device (dry-run only): $JANUS_VM_DISK_PATH"
        fi
    fi

    [ -n "$JANUS_VM_OVMF_CODE" ] || JANUS_VM_OVMF_CODE="$(janus_vm_detect_ovmf_code || true)"
    [ -n "$JANUS_VM_OVMF_VARS" ] || JANUS_VM_OVMF_VARS="$(janus_vm_detect_ovmf_vars || true)"

    if [ -z "$JANUS_VM_OVMF_CODE" ]; then
        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            janus_vm_die "Unable to detect OVMF_CODE.fd. Provide --ovmf-code."
        fi
        JANUS_VM_OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
        janus_vm_log_warn "OVMF code path not detected; dry-run will use placeholder: $JANUS_VM_OVMF_CODE"
    elif [ ! -f "$JANUS_VM_OVMF_CODE" ]; then
        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            janus_vm_die "OVMF code file not found: $JANUS_VM_OVMF_CODE"
        fi
        janus_vm_log_warn "OVMF code file does not exist on this host (dry-run only): $JANUS_VM_OVMF_CODE"
    fi

    if [ -z "$JANUS_VM_OVMF_VARS" ]; then
        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            janus_vm_die "Unable to detect OVMF_VARS.fd. Provide --ovmf-vars."
        fi
        JANUS_VM_OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
        janus_vm_log_warn "OVMF vars path not detected; dry-run will use placeholder: $JANUS_VM_OVMF_VARS"
    elif [ ! -f "$JANUS_VM_OVMF_VARS" ]; then
        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            janus_vm_die "OVMF vars template not found: $JANUS_VM_OVMF_VARS"
        fi
        janus_vm_log_warn "OVMF vars template does not exist on this host (dry-run only): $JANUS_VM_OVMF_VARS"
    fi

    if [ -n "$JANUS_VM_ISO_PATH" ] && [ ! -f "$JANUS_VM_ISO_PATH" ]; then
        if [ "$JANUS_VM_APPLY" -eq 1 ]; then
            janus_vm_die "ISO file not found: $JANUS_VM_ISO_PATH"
        fi
        janus_vm_log_warn "ISO file does not exist on this host (dry-run only): $JANUS_VM_ISO_PATH"
    fi

    if [ "$JANUS_VM_MODE" = "passthrough" ]; then
        [ -n "$JANUS_VM_GPU_PCI" ] || janus_vm_die "--gpu is required for passthrough mode."
        [ -n "$JANUS_VM_GPU_AUDIO_PCI" ] || janus_vm_die "--gpu-audio is required for passthrough mode."
    elif [ -n "$JANUS_VM_GPU_PCI$JANUS_VM_GPU_AUDIO_PCI" ]; then
        janus_vm_log_warn "Ignoring --gpu/--gpu-audio because mode is base."
    fi

    if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 1 ]; then
        [ -n "$JANUS_VM_WIN_USERNAME" ] || janus_vm_die "--win-user is required when --unattended is enabled."
    fi

    if [ "$JANUS_VM_FORCE" -eq 1 ]; then
        janus_vm_die "--force is only valid for the stop action."
    fi
}

# Validate options for non-create actions.
janus_vm_validate_non_create() {
    if [ "$JANUS_VM_APPLY" -eq 1 ]; then
        janus_vm_die "--apply is only valid for the create action."
    fi

    [ "$JANUS_VM_GUIDED_MODE" = "auto" ] || janus_vm_die "--guided/--no-guided are only valid for create."
    [ "$JANUS_VM_STORAGE_MODE" = "file" ] || janus_vm_die "--storage is only valid for create."
    [ "$JANUS_VM_SINGLE_GPU_MODE" = "shared-vram" ] || janus_vm_die "--single-gpu-mode is only valid for create."
    [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 0 ] || janus_vm_die "--unattended is only valid for create."
    [ -z "$JANUS_VM_WIN_USERNAME$JANUS_VM_WIN_PASSWORD" ] || janus_vm_die "--win-user/--win-password are only valid for create."

    if [ "$JANUS_VM_ACTION" = "start" ] || [ "$JANUS_VM_ACTION" = "status" ]; then
        [ "$JANUS_VM_FORCE" -eq 0 ] || janus_vm_die "--force is only valid for stop."
    fi
}

# Ensure required directories exist for the selected operation.
janus_vm_prepare_layout() {
    local dirs=("$JANUS_VM_DEF_DIR" "$JANUS_VM_NVRAM_DIR")

    if [ "$JANUS_VM_STORAGE_MODE" = "file" ]; then
        dirs+=("$(dirname "$JANUS_VM_DISK_PATH")")
    fi

    if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 1 ]; then
        dirs+=("$JANUS_VM_UNATTEND_DIR/$JANUS_VM_NAME")
    fi

    mkdir -p "${dirs[@]}" || janus_vm_die "Unable to create VM directories."
}
