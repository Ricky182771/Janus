#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Guided Wizard
# ----------------------------------------------------------------------------
# This file contains interactive guided creation workflow helpers.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_CLI_WIZARD_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_CLI_WIZARD_LOADED=1

# Return the recommended default video profile choice.
janus_vm_video_profile_default_choice() {
    if [ "$JANUS_VM_MODE" = "passthrough" ]; then
        printf '%s' "1"
        return
    fi

    if [ "$JANUS_VM_SINGLE_GPU_MODE" = "cpu-only" ]; then
        printf '%s' "3"
        return
    fi

    printf '%s' "2"
}

# Run the interactive three-step VM creation wizard.
janus_vm_run_guided_create_wizard() {
    local input=""
    local default_choice=""

    janus_vm_log_info "Guided creation enabled."
    printf '=== Janus VM Create Wizard ===\n'

    printf '\n'
    printf '[1/3] Installation ISO\n'
    janus_vm_prompt_with_default "Windows ISO path (empty to skip)" "$JANUS_VM_ISO_PATH" JANUS_VM_ISO_PATH

    printf '\n'
    printf '[2/3] VM resources\n'
    janus_vm_prompt_with_default "RAM (MiB)" "$JANUS_VM_MEMORY_MIB" JANUS_VM_MEMORY_MIB
    janus_vm_prompt_with_default "vCPU cores" "$JANUS_VM_VCPUS" JANUS_VM_VCPUS

    default_choice="$(janus_vm_video_profile_default_choice)"
    printf 'Video profile:\n'
    printf '  1) Passthrough (isolated secondary GPU)\n'
    printf '  2) Single GPU - Shared VRAM (virtio)\n'
    printf '  3) Single GPU - No acceleration (CPU only)\n'

    read -r -p "Select profile [1/2/3] [$default_choice]: " input || true
    [ -n "$input" ] || input="$default_choice"

    case "$input" in
        1)
            JANUS_VM_MODE="passthrough"
            janus_vm_prompt_with_default "GPU PCI (example: 0000:03:00.0)" "$JANUS_VM_GPU_PCI" JANUS_VM_GPU_PCI
            janus_vm_prompt_with_default "GPU audio PCI (example: 0000:03:00.1)" "$JANUS_VM_GPU_AUDIO_PCI" JANUS_VM_GPU_AUDIO_PCI
            ;;
        2)
            JANUS_VM_MODE="base"
            JANUS_VM_SINGLE_GPU_MODE="shared-vram"
            JANUS_VM_GPU_PCI=""
            JANUS_VM_GPU_AUDIO_PCI=""
            ;;
        3)
            JANUS_VM_MODE="base"
            JANUS_VM_SINGLE_GPU_MODE="cpu-only"
            JANUS_VM_GPU_PCI=""
            JANUS_VM_GPU_AUDIO_PCI=""
            ;;
        *)
            janus_vm_die "Invalid video profile selection: $input"
            ;;
    esac

    default_choice="1"
    [ "$JANUS_VM_STORAGE_MODE" = "block" ] && default_choice="2"

    printf 'Storage backend:\n'
    printf '  1) Create/use QCOW2 file\n'
    printf '  2) Use RAW partition/disk (/dev/...)\n'

    read -r -p "Select storage [1/2] [$default_choice]: " input || true
    [ -n "$input" ] || input="$default_choice"

    case "$input" in
        1)
            JANUS_VM_STORAGE_MODE="file"
            [ -n "$JANUS_VM_DISK_PATH" ] || JANUS_VM_DISK_PATH="$JANUS_VM_DEFAULT_DISK_DIR/${JANUS_VM_NAME}.qcow2"
            janus_vm_prompt_with_default "QCOW2 disk path" "$JANUS_VM_DISK_PATH" JANUS_VM_DISK_PATH
            janus_vm_prompt_with_default "Disk size (example: 120G)" "$JANUS_VM_DISK_SIZE" JANUS_VM_DISK_SIZE
            ;;
        2)
            JANUS_VM_STORAGE_MODE="block"
            janus_vm_prompt_with_default "RAW device path (example: /dev/nvme0n1p3)" "$JANUS_VM_DISK_PATH" JANUS_VM_DISK_PATH
            ;;
        *)
            janus_vm_die "Invalid storage selection: $input"
            ;;
    esac

    printf '\n'
    printf '[3/3] Windows unattended setup\n'

    if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 1 ]; then
        default_choice="Y"
    else
        default_choice="N"
    fi

    read -r -p "Create unattended local account configuration? [y/N] [$default_choice]: " input || true
    [ -n "$input" ] || input="$default_choice"

    if [[ "$input" =~ ^[Yy]$ ]]; then
        JANUS_VM_UNATTENDED_ENABLED=1
        janus_vm_prompt_with_default "Windows local username" "${JANUS_VM_WIN_USERNAME:-janus}" JANUS_VM_WIN_USERNAME
        janus_vm_prompt_secret_optional "Windows local password (optional, press Enter for empty)" JANUS_VM_WIN_PASSWORD
    else
        JANUS_VM_UNATTENDED_ENABLED=0
        JANUS_VM_WIN_USERNAME=""
        JANUS_VM_WIN_PASSWORD=""
    fi
}

# Execute wizard depending on guided mode and interaction state.
janus_vm_maybe_run_guided_create_wizard() {
    [ "$JANUS_VM_ACTION" = "create" ] || return 0

    case "$JANUS_VM_GUIDED_MODE" in
        on)
            janus_vm_is_interactive_tty || janus_vm_die "--guided requires an interactive TTY (run in a terminal, or use --no-guided)."
            janus_vm_run_guided_create_wizard
            ;;
        off)
            ;;
        auto)
            if [ "$JANUS_VM_ASSUME_YES" -eq 0 ] && janus_vm_is_interactive_tty; then
                janus_vm_run_guided_create_wizard
            fi
            ;;
        *)
            janus_vm_die "Invalid guided mode: $JANUS_VM_GUIDED_MODE"
            ;;
    esac
}
