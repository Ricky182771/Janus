#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM XML Renderer
# ----------------------------------------------------------------------------
# This file renders template XML with dynamic block substitution.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_XML_RENDER_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_XML_RENDER_LOADED=1

# Render final libvirt XML from base template and runtime values.
janus_vm_render_xml_definition() {
    local template_file="$1"
    local out_file="$2"
    local primary_disk_block=""
    local iso_block=""
    local unattended_block=""
    local display_block=""
    local gpu_hostdev_block=""
    local nvram_path="$JANUS_VM_NVRAM_DIR/${JANUS_VM_NAME}_VARS.fd"
    local unattended_iso_path="$JANUS_VM_UNATTEND_DIR/${JANUS_VM_NAME}.iso"

    [ -f "$template_file" ] || janus_vm_die "Template not found: $template_file"

    primary_disk_block="$(janus_vm_build_primary_disk_block)"
    iso_block="$(janus_vm_build_iso_block)"
    iso_block="$(printf '%s' "$iso_block" | sed "s|__ISO_PATH__|$(janus_vm_sed_escape "$JANUS_VM_ISO_PATH")|g")"

    unattended_block="$(janus_vm_build_unattend_device_block)"
    unattended_block="$(printf '%s' "$unattended_block" | sed "s|__UNATTEND_ISO_PATH__|$(janus_vm_sed_escape "$unattended_iso_path")|g")"

    display_block="$(janus_vm_build_display_block)"
    gpu_hostdev_block="$(janus_vm_build_gpu_hostdev_block)"

    awk \
        -v VM_NAME="$JANUS_VM_NAME" \
        -v MEMORY_MIB="$JANUS_VM_MEMORY_MIB" \
        -v VCPUS="$JANUS_VM_VCPUS" \
        -v OVMF_CODE="$JANUS_VM_OVMF_CODE" \
        -v OVMF_VARS="$JANUS_VM_OVMF_VARS" \
        -v NVRAM_PATH="$nvram_path" \
        -v DISK_PATH="$JANUS_VM_DISK_PATH" \
        -v NETWORK_NAME="$JANUS_VM_NETWORK_NAME" \
        -v PRIMARY_DISK_BLOCK="$primary_disk_block" \
        -v ISO_BLOCK="$iso_block" \
        -v UNATTEND_BLOCK="$unattended_block" \
        -v DISPLAY_BLOCK="$display_block" \
        -v GPU_HOSTDEV_BLOCK="$gpu_hostdev_block" \
        '
        {
            gsub(/__VM_NAME__/, VM_NAME)
            gsub(/__MEMORY_MIB__/, MEMORY_MIB)
            gsub(/__VCPUS__/, VCPUS)
            gsub(/__OVMF_CODE__/, OVMF_CODE)
            gsub(/__OVMF_VARS__/, OVMF_VARS)
            gsub(/__NVRAM_PATH__/, NVRAM_PATH)
            gsub(/__PRIMARY_DISK_BLOCK__/, PRIMARY_DISK_BLOCK)
            gsub(/__DISK_PATH__/, DISK_PATH)
            gsub(/__NETWORK_NAME__/, NETWORK_NAME)
            gsub(/__ISO_DEVICE_BLOCK__/, ISO_BLOCK)
            gsub(/__UNATTEND_DEVICE_BLOCK__/, UNATTEND_BLOCK)
            gsub(/__DISPLAY_DEVICE_BLOCK__/, DISPLAY_BLOCK)
            gsub(/__GPU_HOSTDEV_BLOCK__/, GPU_HOSTDEV_BLOCK)
            print
        }
        ' "$template_file" > "$out_file" || janus_vm_die "Unable to render VM definition: $out_file"
}
