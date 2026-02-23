#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Janus Unit Tests
# ----------------------------------------------------------------------------
# Isolated tests for individual library functions from lib/core/runtime/.
# Each test runs in a subshell with a temporary HOME to avoid side effects.
# ----------------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d /tmp/janus-unit.XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"

PASS_COUNT=0
FAIL_COUNT=0

fail() {
    echo "[FAIL] $1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

# Assert that a command exits with code 0.
assert_zero() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label (expected exit 0, got $?)"
    fi
}

# Assert that a command exits with non-zero code.
assert_nonzero() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        fail "$label (expected non-zero exit, got 0)"
    else
        pass "$label"
    fi
}

# Assert that command stdout contains expected string.
assert_output_contains() {
    local label="$1"
    local expected="$2"
    shift 2
    local output=""
    output="$("$@" 2>&1)" || true
    if printf '%s' "$output" | grep -qF "$expected"; then
        pass "$label"
    else
        fail "$label (expected output to contain '$expected', got: '$output')"
    fi
}

# Assert exact stdout output (trimmed).
assert_output_equals() {
    local label="$1"
    local expected="$2"
    shift 2
    local output=""
    output="$("$@" 2>&1)" || true
    if [ "$output" = "$expected" ]; then
        pass "$label"
    else
        fail "$label (expected '$expected', got '$output')"
    fi
}

# ============================================================================
echo ""
echo "=== lib/core/runtime/paths.sh ==="
# ============================================================================

(
    source "$ROOT_DIR/lib/core/runtime/paths.sh"

    # -- janus_runtime_pick_writable_dir: picks writable primary --
    writable_dir="$TMP_HOME/test-writable"
    mkdir -p "$writable_dir"
    result="$(janus_runtime_pick_writable_dir "$writable_dir" "/nonexistent-fallback")"
    if [ "$result" = "$writable_dir" ]; then
        echo "[PASS] pick_writable_dir: returns writable primary"
    else
        echo "[FAIL] pick_writable_dir: expected '$writable_dir', got '$result'" >&2
    fi
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

(
    source "$ROOT_DIR/lib/core/runtime/paths.sh"

    # -- janus_runtime_pick_writable_dir: falls back when primary fails --
    fallback_dir="$TMP_HOME/test-fallback"
    mkdir -p "$fallback_dir"
    result="$(janus_runtime_pick_writable_dir "/proc/nonexistent" "$fallback_dir")"
    if [ "$result" = "$fallback_dir" ]; then
        echo "[PASS] pick_writable_dir: falls back to secondary"
    else
        echo "[FAIL] pick_writable_dir: expected '$fallback_dir', got '$result'" >&2
    fi
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

(
    source "$ROOT_DIR/lib/core/runtime/paths.sh"

    # -- janus_runtime_pick_writable_dir: fails when both bad --
    if janus_runtime_pick_writable_dir "/proc/nonexistent1" "/proc/nonexistent2" 2>/dev/null; then
        echo "[FAIL] pick_writable_dir: should fail when both paths are bad" >&2
        exit 1
    fi
    echo "[PASS] pick_writable_dir: returns error when both paths are bad"
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

(
    source "$ROOT_DIR/lib/core/runtime/paths.sh"

    # -- janus_runtime_resolve_log_dir: returns a valid path --
    result="$(janus_runtime_resolve_log_dir)"
    if [ -d "$result" ]; then
        echo "[PASS] resolve_log_dir: returns existing directory"
    else
        echo "[FAIL] resolve_log_dir: expected existing dir, got '$result'" >&2
        exit 1
    fi
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

(
    source "$ROOT_DIR/lib/core/runtime/paths.sh"

    # -- janus_runtime_resolve_state_dir: returns a valid path --
    result="$(janus_runtime_resolve_state_dir)"
    if [ -d "$result" ]; then
        echo "[PASS] resolve_state_dir: returns existing directory"
    else
        echo "[FAIL] resolve_state_dir: expected existing dir, got '$result'" >&2
        exit 1
    fi
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

# ============================================================================
echo ""
echo "=== lib/core/runtime/logging.sh ==="
# ============================================================================

assert_output_contains \
    "janus_log: INFO format" \
    "[INFO]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log INFO 'test message'
    "

assert_output_contains \
    "janus_log: includes message text" \
    "test message" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log INFO 'test message'
    "

assert_output_contains \
    "janus_log_warn: WARN format" \
    "[WARN]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log_warn 'warning test'
    "

assert_output_contains \
    "janus_log_error: ERROR format" \
    "[ERROR]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log_error 'error test'
    "

assert_output_contains \
    "janus_log_ok: OK format" \
    "[OK]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log_ok 'success test'
    "

assert_output_contains \
    "janus_log_debug: DEBUG format" \
    "[DEBUG]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log_debug 'debug test'
    "

assert_output_contains \
    "janus_log_critical: CRITICAL format" \
    "[CRITICAL]" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        JANUS_LOG_ENABLE_COLOR=0
        janus_log_critical 'critical test'
    "

# -- janus_log_color: returns ANSI codes --
assert_output_contains \
    "janus_log_color: INFO returns blue" \
    $'\033[0;34m' \
    bash -c "source '$ROOT_DIR/lib/core/runtime/logging.sh'; janus_log_color INFO"

assert_output_contains \
    "janus_log_color: ERROR returns red" \
    $'\033[0;31m' \
    bash -c "source '$ROOT_DIR/lib/core/runtime/logging.sh'; janus_log_color ERROR"

assert_output_contains \
    "janus_log_color: OK returns green" \
    $'\033[0;32m' \
    bash -c "source '$ROOT_DIR/lib/core/runtime/logging.sh'; janus_log_color OK"

assert_output_contains \
    "janus_log_color: WARN returns yellow" \
    $'\033[1;33m' \
    bash -c "source '$ROOT_DIR/lib/core/runtime/logging.sh'; janus_log_color WARN"

# ============================================================================
echo ""
echo "=== lib/core/runtime/safety.sh ==="
# ============================================================================

assert_zero \
    "janus_has_flag: detects present flag" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        janus_has_flag '--dry-run' --device 0000:03:00.0 --dry-run --yes
    "

assert_nonzero \
    "janus_has_flag: returns non-zero for missing flag" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        janus_has_flag '--apply' --device 0000:03:00.0 --dry-run --yes
    "

assert_zero \
    "janus_has_flag: detects flag at end of list" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        janus_has_flag '--yes' --device 0000:03:00.0 --yes
    "

assert_nonzero \
    "janus_has_flag: returns non-zero for empty args" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        janus_has_flag '--help'
    "

assert_nonzero \
    "janus_require_root: fails for non-root" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        janus_require_root 'test-context'
    "

# ============================================================================
echo ""
echo "=== lib/core/runtime/tty.sh ==="
# ============================================================================

assert_output_equals \
    "janus_tty_join_escaped_args: simple words" \
    "hello world" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
        janus_tty_join_escaped_args hello world
    "

(
    source "$ROOT_DIR/lib/core/runtime/tty.sh"

    # -- janus_tty_join_escaped_args: handles special characters --
    result="$(janus_tty_join_escaped_args "hello world" "it's")"
    # The result should be escaped such that eval would reproduce original args
    eval "set -- $result"
    if [ "$1" = "hello world" ] && [ "$2" = "it's" ]; then
        echo "[PASS] tty_join_escaped_args: handles spaces and quotes"
    else
        echo "[FAIL] tty_join_escaped_args: eval did not reproduce args: \$1='$1' \$2='$2'" >&2
        exit 1
    fi
) && PASS_COUNT=$((PASS_COUNT + 1)) || FAIL_COUNT=$((FAIL_COUNT + 1))

assert_zero \
    "JANUS_TTY_UNAVAILABLE_RC is defined" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
        [ -n \"\$JANUS_TTY_UNAVAILABLE_RC\" ]
    "

assert_output_equals \
    "JANUS_TTY_UNAVAILABLE_RC equals 91" \
    "91" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
        printf '%s' \"\$JANUS_TTY_UNAVAILABLE_RC\"
    "

# -- ensure_tty: returns error without arguments --
assert_nonzero \
    "ensure_tty: fails with no arguments" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
        ensure_tty
    "

# ============================================================================
echo ""
echo "=== lib/core/runtime/logging.sh (start_logging pre-flight) ==="
# ============================================================================

# The start_logging function uses exec > >(tee ...) which creates persistent
# pipes. We only test pre-flight validation here; the positive path is covered
# by smoke.sh end-to-end.

assert_nonzero \
    "start_logging: fails when resolve_log_dir fails" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        janus_runtime_resolve_log_dir() { return 1; }
        janus_runtime_start_logging 'test'
    "

# ============================================================================
echo ""
echo "=== Include guards ==="
# ============================================================================

assert_zero \
    "paths.sh: double source does not error" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/paths.sh'
        source '$ROOT_DIR/lib/core/runtime/paths.sh'
    "

assert_zero \
    "logging.sh: double source does not error" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
        source '$ROOT_DIR/lib/core/runtime/logging.sh'
    "

assert_zero \
    "safety.sh: double source does not error" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
        source '$ROOT_DIR/lib/core/runtime/safety.sh'
    "

assert_zero \
    "tty.sh: double source does not error" \
    bash -c "
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
        source '$ROOT_DIR/lib/core/runtime/tty.sh'
    "

assert_zero \
    "lib/tty.sh shim: double source does not error" \
    bash -c "
        source '$ROOT_DIR/lib/tty.sh'
        source '$ROOT_DIR/lib/tty.sh'
    "

# ============================================================================
echo ""
echo "=== Summary ==="
# ============================================================================

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Ran $TOTAL tests: $PASS_COUNT passed, $FAIL_COUNT failed."

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "[FAIL] Some unit tests failed." >&2
    exit 1
fi

echo "[OK] All unit tests passed."
