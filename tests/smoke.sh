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

echo "[INFO] Syntax check"
for file in "$ROOT_DIR"/bin/*.sh "$ROOT_DIR"/lib/*.sh "$ROOT_DIR"/modules/gpu/template.sh; do
    bash -n "$file"
done

echo "[INFO] Version/help checks"
bash "$ROOT_DIR/bin/janus-init.sh" --version >/dev/null
bash "$ROOT_DIR/bin/janus-check.sh" --version >/dev/null
bash "$ROOT_DIR/bin/janus-bind.sh" --help >/dev/null

echo "[INFO] Error-path checks"
assert_nonzero bash "$ROOT_DIR/bin/janus-init.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-check.sh" --invalid
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --group
assert_nonzero bash "$ROOT_DIR/bin/janus-bind.sh" --device 0000:ff:ff.f --dry-run --yes

echo "[OK] Smoke checks passed"
