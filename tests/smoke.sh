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
for file in "$ROOT_DIR"/bin/*.sh "$ROOT_DIR"/lib/*.sh "$ROOT_DIR"/modules/gpu/template.sh; do
    bash -n "$file"
done

echo "[INFO] Version/help checks"
assert_zero bash "$ROOT_DIR/bin/janus-init.sh" --version
assert_zero bash "$ROOT_DIR/bin/janus-check.sh" --version
assert_zero bash "$ROOT_DIR/bin/janus-bind.sh" --help

echo "[INFO] Error-path checks"
assert_nonzero bash "$ROOT_DIR/bin/janus-init.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-check.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --group
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device 0000:ff:ff.f --dry-run --yes
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --rollback --apply
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --rollback --device 0000:03:00.0

echo "[INFO] No-TTY regression checks"
bash "$ROOT_DIR/bin/janus-check.sh" </dev/null >"$TMP_HOME/janus-check-notty.log" 2>&1 || true
if grep -q "Launching janus-init" "$TMP_HOME/janus-check-notty.log"; then
    fail "janus-check should not auto-launch janus-init when no interactive TTY is available."
fi

echo "[OK] Smoke checks passed"
