#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d /tmp/janus-smoke.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

assert_nonzero() {
    local cmd=("$@")
    if "${cmd[@]}" >/dev/null 2>&1; then
        fail "Expected non-zero exit: ${cmd[*]}"
    fi
}

assert_zero() {
    local cmd=("$@")
    if ! "${cmd[@]}" >/dev/null 2>&1; then
        fail "Expected zero exit: ${cmd[*]}"
    fi
}

echo "[INFO] Syntax check"
while IFS= read -r file; do
    bash -n "$file"
done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/lib" "$ROOT_DIR/modules" -type f -name "*.sh" | sort)
bash -n "$ROOT_DIR/Janus.sh"

echo "[INFO] Version/help checks"
assert_zero bash "$ROOT_DIR/bin/janus-init.sh" --version
assert_zero bash "$ROOT_DIR/bin/janus-check.sh" --version
assert_zero bash "$ROOT_DIR/bin/janus-bind.sh" --help
assert_zero bash "$ROOT_DIR/bin/janus-vm.sh" --help
assert_zero bash "$ROOT_DIR/Janus.sh" --help
assert_zero bash "$ROOT_DIR/Janus.sh" --list-languages
assert_zero python3 "$ROOT_DIR/orchestrator/janus_tui.py" --list-languages
assert_zero python3 -m py_compile "$ROOT_DIR/orchestrator/janus_tui.py"
[ -f "$ROOT_DIR/docs/module-api.md" ] || fail "Missing docs/module-api.md"

echo "[INFO] Module API v1 checks"
assert_zero bash "$ROOT_DIR/modules/gpu/template.sh" check
assert_zero bash "$ROOT_DIR/modules/gpu/template.sh" apply
assert_zero bash "$ROOT_DIR/modules/gpu/template.sh" rollback
assert_zero bash "$ROOT_DIR/modules/gpu/template.sh" meta
MODULE_META="$(bash "$ROOT_DIR/modules/gpu/template.sh" meta)"
printf '%s\n' "$MODULE_META" | grep -q "^id=gpu-template$" || fail "Expected module metadata id=gpu-template"
printf '%s\n' "$MODULE_META" | grep -q "^compat_api=1$" || fail "Expected module metadata compat_api=1"

echo "[INFO] Module loader checks"
assert_zero bash -c '
set -euo pipefail
JANUS_ROOT_DIR="$1"
source "$JANUS_ROOT_DIR/lib/modules/main.sh"
janus_module_load "$JANUS_ROOT_DIR/modules/gpu/template.sh"
[ "$JANUS_MODULE_ID" = "gpu-template" ]
[ "$JANUS_MODULE_COMPAT_API" = "1" ]
janus_module_unload
janus_module_run_action "$JANUS_ROOT_DIR/modules/gpu/template.sh" check
JANUS_MODULE_EXEC_MODE=subshell
janus_module_run_action "$JANUS_ROOT_DIR/modules/gpu/template.sh" check
' _ "$ROOT_DIR"

MODULE_DISCOVERY="$(
    bash -c '
set -euo pipefail
JANUS_ROOT_DIR="$1"
source "$JANUS_ROOT_DIR/lib/modules/main.sh"
janus_modules_discover
' _ "$ROOT_DIR"
)"
printf '%s\n' "$MODULE_DISCOVERY" | grep -q "^id=gpu-template$" || fail "Expected module discovery to include gpu-template"

echo "[INFO] Error-path checks"
assert_nonzero bash "$ROOT_DIR/bin/janus-init.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-check.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --group
assert_nonzero bash "$ROOT_DIR/bin/janus-vm.sh" invalid-action
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device 0000:ff:ff.f --dry-run --yes
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --rollback --apply
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --rollback --device 0000:03:00.0

echo "[INFO] VM XML defaults (stealth + passthrough) checks"
assert_zero bash "$ROOT_DIR/bin/janus-vm.sh" create --name smoke-win11 --mode passthrough --gpu 0000:03:00.0 --gpu-audio 0000:03:00.1 --yes
VM_XML="$TMP_HOME/.config/janus/vm/definitions/smoke-win11.xml"
[ -f "$VM_XML" ] || fail "Expected VM XML definition not found: $VM_XML"
grep -q "<hidden state='on'/>" "$VM_XML" || fail "Expected KVM hidden state enabled by default."
grep -q "<feature policy='disable' name='hypervisor'/>" "$VM_XML" || fail "Expected CPU hypervisor CPUID bit disabled by default."
grep -q "<hostdev mode='subsystem' type='pci' managed='yes'>" "$VM_XML" || fail "Expected passthrough hostdev block in VM XML."

echo "[INFO] Single-GPU + block storage + unattended checks"
assert_zero bash "$ROOT_DIR/bin/janus-vm.sh" create --name smoke-single --mode base --single-gpu-mode cpu-only --storage block --disk-path /dev/null --unattended --win-user smokeuser --yes --no-guided
VM_XML_SINGLE="$TMP_HOME/.config/janus/vm/definitions/smoke-single.xml"
[ -f "$VM_XML_SINGLE" ] || fail "Expected VM XML definition not found: $VM_XML_SINGLE"
grep -q "<disk type='block' device='disk'>" "$VM_XML_SINGLE" || fail "Expected block-disk storage mode in VM XML."
grep -q "<source dev='/dev/null'/>" "$VM_XML_SINGLE" || fail "Expected block source path in VM XML."
grep -q "<model type='vga' heads='1' primary='yes'/>" "$VM_XML_SINGLE" || fail "Expected CPU-only video model in VM XML."
grep -q "<source file='$TMP_HOME/.config/janus/vm/unattend/smoke-single.iso'/>" "$VM_XML_SINGLE" || fail "Expected unattended ISO device block in VM XML."

assert_zero bash "$ROOT_DIR/bin/janus-vm.sh" create --name smoke-shared --mode base --single-gpu-mode shared-vram --yes --no-guided
VM_XML_SHARED="$TMP_HOME/.config/janus/vm/definitions/smoke-shared.xml"
[ -f "$VM_XML_SHARED" ] || fail "Expected VM XML definition not found: $VM_XML_SHARED"
grep -q "<acceleration accel3d='yes'/>" "$VM_XML_SHARED" || fail "Expected shared-vram 3D acceleration in VM XML."

echo "[INFO] No-TTY regression checks"
bash "$ROOT_DIR/bin/janus-check.sh" </dev/null >"$TMP_HOME/janus-check-notty.log" 2>&1 || true
if grep -q "Launching janus-init" "$TMP_HOME/janus-check-notty.log"; then
    fail "janus-check should not auto-launch janus-init when no interactive TTY is available."
fi

if ! bash "$ROOT_DIR/bin/janus-vm.sh" create --name smoke-auto-notty --mode base --single-gpu-mode cpu-only </dev/null >"$TMP_HOME/janus-vm-auto-notty.log" 2>&1; then
    fail "janus-vm create (auto guided) should not fail when no interactive TTY is available."
fi

if bash "$ROOT_DIR/bin/janus-vm.sh" create --name smoke-guided-notty --guided </dev/null >"$TMP_HOME/janus-vm-guided-notty.log" 2>&1; then
    fail "janus-vm --guided should fail when no interactive TTY is available."
fi

if ! grep -q -- "--guided requires an interactive TTY" "$TMP_HOME/janus-vm-guided-notty.log"; then
    fail "Expected explicit guided no-TTY error message."
fi

echo "[OK] Smoke checks passed"
