#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Unattended Storage
# ----------------------------------------------------------------------------
# This file creates unattended XML data and ISO media.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_STORAGE_UNATTEND_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_STORAGE_UNATTEND_LOADED=1

# Write Autounattend.xml using current account settings.
janus_vm_write_unattend_xml_file() {
    local out_file="$1"
    local user_escaped=""
    local pass_escaped=""
    local password_block=""
    local autologon_block=""

    user_escaped="$(janus_vm_xml_escape "$JANUS_VM_WIN_USERNAME")"

    if [ -n "$JANUS_VM_WIN_PASSWORD" ]; then
        pass_escaped="$(janus_vm_xml_escape "$JANUS_VM_WIN_PASSWORD")"

        password_block=$(cat <<EOF_PASSWORD
            <Password>
              <Value>$pass_escaped</Value>
              <PlainText>true</PlainText>
            </Password>
EOF_PASSWORD
)

        autologon_block=$(cat <<EOF_AUTOLOGON
      <AutoLogon>
        <Password>
          <Value>$pass_escaped</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Username>$user_escaped</Username>
      </AutoLogon>
EOF_AUTOLOGON
)
    fi

    cat > "$out_file" <<EOF_XML
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
$password_block
            <Description>Janus local account</Description>
            <DisplayName>$user_escaped</DisplayName>
            <Group>Administrators</Group>
            <Name>$user_escaped</Name>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
$autologon_block
      <TimeZone>UTC</TimeZone>
    </component>
  </settings>
</unattend>
EOF_XML
}

# Build unattended ISO with the first available ISO tooling backend.
janus_vm_build_unattend_iso() {
    local source_dir="$1"
    local iso_path="$2"

    if command -v genisoimage >/dev/null 2>&1; then
        genisoimage -quiet -o "$iso_path" -J -r "$source_dir" >/dev/null 2>&1 || janus_vm_die "Failed to build unattended ISO with genisoimage."
        return 0
    fi

    if command -v mkisofs >/dev/null 2>&1; then
        mkisofs -quiet -o "$iso_path" -J -r "$source_dir" >/dev/null 2>&1 || janus_vm_die "Failed to build unattended ISO with mkisofs."
        return 0
    fi

    if command -v xorriso >/dev/null 2>&1; then
        xorriso -as mkisofs -quiet -o "$iso_path" -J -r "$source_dir" >/dev/null 2>&1 || janus_vm_die "Failed to build unattended ISO with xorriso."
        return 0
    fi

    janus_vm_die "Unattended mode requires genisoimage, mkisofs, or xorriso."
}
