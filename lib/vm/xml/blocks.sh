#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM XML Blocks
# ----------------------------------------------------------------------------
# This file builds XML fragments used by the VM template renderer.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_XML_BLOCKS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_XML_BLOCKS_LOADED=1

# Build primary disk block for file or block-backed storage.
janus_vm_build_primary_disk_block() {
    if [ "$JANUS_VM_STORAGE_MODE" = "block" ]; then
        cat <<EOF_BLOCK
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source dev='__DISK_PATH__'/>
      <target dev='vda' bus='virtio'/>
      <boot order='1'/>
    </disk>
EOF_BLOCK
        return 0
    fi

    cat <<EOF_BLOCK
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='__DISK_PATH__'/>
      <target dev='vda' bus='virtio'/>
      <boot order='1'/>
    </disk>
EOF_BLOCK
}

# Build installation ISO cdrom block.
janus_vm_build_iso_block() {
    if [ -z "$JANUS_VM_ISO_PATH" ]; then
        printf '%s\n' "    <!-- No installation ISO configured -->"
        return 0
    fi

    cat <<EOF_BLOCK
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='__ISO_PATH__'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
EOF_BLOCK
}

# Build unattended ISO cdrom block.
janus_vm_build_unattend_device_block() {
    if [ "$JANUS_VM_UNATTENDED_ENABLED" -eq 0 ]; then
        printf '%s\n' "    <!-- No unattended ISO configured -->"
        return 0
    fi

    cat <<EOF_BLOCK
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='__UNATTEND_ISO_PATH__'/>
      <target dev='sdb' bus='sata'/>
      <readonly/>
    </disk>
EOF_BLOCK
}

# Build display/audio blocks according to selected profile.
janus_vm_build_display_block() {
    if [ "$JANUS_VM_MODE" = "passthrough" ]; then
        cat <<EOF_BLOCK
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>
EOF_BLOCK
        return 0
    fi

    if [ "$JANUS_VM_SINGLE_GPU_MODE" = "cpu-only" ]; then
        cat <<EOF_BLOCK
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='vga' heads='1' primary='yes'/>
    </video>
    <sound model='ich9'/>
    <audio id='1' type='spice'/>
EOF_BLOCK
        return 0
    fi

    cat <<EOF_BLOCK
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio' heads='1' primary='yes'>
        <acceleration accel3d='yes'/>
      </model>
    </video>
    <sound model='ich9'/>
    <audio id='1' type='spice'/>
EOF_BLOCK
}

# Build passthrough hostdev block for GPU + HDMI audio function.
janus_vm_build_gpu_hostdev_block() {
    if [ "$JANUS_VM_MODE" != "passthrough" ]; then
        printf '%s\n' "    <!-- No PCIe GPU passthrough configured -->"
        return 0
    fi

    cat <<EOF_BLOCK
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='${JANUS_VM_GPU_DOMAIN}' bus='${JANUS_VM_GPU_BUS}' slot='${JANUS_VM_GPU_SLOT}' function='${JANUS_VM_GPU_FUNCTION}'/>
      </source>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='${JANUS_VM_GPU_AUDIO_DOMAIN}' bus='${JANUS_VM_GPU_AUDIO_BUS}' slot='${JANUS_VM_GPU_AUDIO_SLOT}' function='${JANUS_VM_GPU_AUDIO_FUNCTION}'/>
      </source>
    </hostdev>
EOF_BLOCK
}
