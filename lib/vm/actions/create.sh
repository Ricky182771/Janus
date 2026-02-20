#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Create Action
# ----------------------------------------------------------------------------
# This file contains the create workflow, including dry-run and apply modes.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_ACTION_CREATE_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_ACTION_CREATE_LOADED=1

# Create or define a VM from the Janus template.
janus_vm_create() {
    local def_file="$JANUS_VM_DEF_DIR/${JANUS_VM_NAME}.xml"
    local template_file="$JANUS_VM_TEMPLATE_DIR/windows-base.xml"
    local nvram_path="$JANUS_VM_NVRAM_DIR/${JANUS_VM_NAME}_VARS.fd"
    local unattended_vm_dir="$JANUS_VM_UNATTEND_DIR/$JANUS_VM_NAME"
    local unattended_xml_path="$unattended_vm_dir/Autounattend.xml"
    local unattended_iso_path="$JANUS_VM_UNATTEND_DIR/${JANUS_VM_NAME}.iso"

    janus_vm_validate_create
    janus_vm_prepare_layout

    if [ "$JANUS_VM_MODE" = "passthrough" ]; then
        janus_vm_parse_pci_parts "$JANUS_VM_GPU_PCI" "JANUS_VM_GPU"
        janus_vm_parse_pci_parts "$JANUS_VM_GPU_AUDIO_PCI" "JANUS_VM_GPU_AUDIO"
    fi

    janus_vm_render_xml_definition "$template_file" "$def_file"
    janus_vm_log_ok "VM definition rendered: $def_file"

    if [ "$JANUS_VM_APPLY" -eq 0 ]; then
        janus_vm_log_info "DRY-RUN mode: no libvirt changes applied."

        if [ "$JANUS_VM_STORAGE_MODE" = "file" ]; then
            if [ ! -f "$JANUS_VM_DISK_PATH" ]; then
                janus_vm_log_info "Would create QCOW2 disk: $JANUS_VM_DISK_PATH (size $JANUS_VM_DISK_SIZE)"
            else
                janus_vm_log_info "QCOW2 disk already exists: $JANUS_VM_DISK_PATH"
            fi
        else
            janus_vm_log_info "Would use existing block device as VM disk: $JANUS_VM_DISK_PATH"
        fi

        if [ ! -f "$nvram_path" ]; then
            janus_vm_log_info "Would create NVRAM file from template: $nvram_path"
        fi

        if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 1 ]; then
            janus_vm_log_info "Would create unattended XML: $unattended_xml_path"
            janus_vm_log_info "Would create unattended ISO: $unattended_iso_path"
        fi

        janus_vm_log_info "To apply: janus-vm create --name $JANUS_VM_NAME --mode $JANUS_VM_MODE --apply"
        return 0
    fi

    if [ "$JANUS_VM_STORAGE_MODE" = "file" ]; then
        janus_vm_require_cmd "qemu-img"
    fi

    janus_vm_ensure_virsh_connection

    if ! janus_vm_confirm "Apply VM definition and local artifacts now?"; then
        janus_vm_log_warn "Aborted by user."
        return 0
    fi

    if [ "$JANUS_VM_STORAGE_MODE" = "file" ]; then
        if [ ! -f "$JANUS_VM_DISK_PATH" ]; then
            janus_vm_log_info "Creating QCOW2 disk: $JANUS_VM_DISK_PATH ($JANUS_VM_DISK_SIZE)"
            qemu-img create -f qcow2 "$JANUS_VM_DISK_PATH" "$JANUS_VM_DISK_SIZE" >/dev/null || janus_vm_die "Failed to create disk image."
        else
            janus_vm_log_info "Disk already exists: $JANUS_VM_DISK_PATH"
        fi
    else
        [ -b "$JANUS_VM_DISK_PATH" ] || janus_vm_die "Configured raw disk is not a block device: $JANUS_VM_DISK_PATH"
        janus_vm_log_info "Using block device disk: $JANUS_VM_DISK_PATH"
    fi

    if [ ! -f "$nvram_path" ]; then
        cp "$JANUS_VM_OVMF_VARS" "$nvram_path" || janus_vm_die "Failed to create NVRAM file."
        janus_vm_log_ok "NVRAM file created: $nvram_path"
    else
        janus_vm_log_info "NVRAM file already exists: $nvram_path"
    fi

    if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 1 ]; then
        janus_vm_write_unattend_xml_file "$unattended_xml_path"
        janus_vm_log_ok "Unattended XML created: $unattended_xml_path"

        janus_vm_build_unattend_iso "$unattended_vm_dir" "$unattended_iso_path"
        janus_vm_log_ok "Unattended ISO created: $unattended_iso_path"
    fi

    virsh -c "$JANUS_VM_CONNECT_URI" define "$def_file" >/dev/null || janus_vm_die "virsh define failed."
    janus_vm_log_ok "VM defined in libvirt: $JANUS_VM_NAME"
}
