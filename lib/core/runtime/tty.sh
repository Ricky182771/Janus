#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Runtime TTY Helpers
# ----------------------------------------------------------------------------
# This module provides a reusable ensure_tty() helper that:
# - keeps direct execution when stdin is already interactive;
# - forces pseudo-TTY via `script -q -c "<command>" /dev/null` when needed;
# - preserves child exit codes across pseudo-TTY execution;
# - reports a dedicated return code when pseudo-TTY is unavailable.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_RUNTIME_TTY_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_RUNTIME_TTY_LOADED=1

# Return code used when no real TTY exists and pseudo-TTY cannot be created.
JANUS_TTY_UNAVAILABLE_RC=91

# Return success when stdin is an interactive TTY.
janus_tty_has_stdin() {
    [ -t 0 ]
}

# Return success when `script` command is available.
janus_tty_has_script() {
    command -v script >/dev/null 2>&1
}

# Join argv into a single shell-escaped command string.
janus_tty_join_escaped_args() {
    local out=""
    local arg=""

    for arg in "$@"; do
        if [ -n "$out" ]; then
            out+=" "
        fi
        out+="$(printf '%q' "$arg")"
    done

    printf '%s' "$out"
}

# Ensure command executes with interactive stdin.
# Usage:
#   ensure_tty command arg1 arg2 ...
ensure_tty() {
    local command_string=""
    local rc_file=""
    local rc_file_escaped=""
    local wrapped_command=""
    local script_rc=0
    local child_rc=""

    if [ $# -eq 0 ]; then
        printf '[ERROR] ensure_tty requires a command to run.\n' >&2
        return 2
    fi

    if janus_tty_has_stdin; then
        "$@"
        return $?
    fi

    if ! janus_tty_has_script; then
        printf '[WARN] No interactive TTY detected and `script` is unavailable.\n' >&2
        return "$JANUS_TTY_UNAVAILABLE_RC"
    fi

    printf '[WARN] No interactive TTY detected. Forcing pseudo-TTY with `script`.\n' >&2

    command_string="$(janus_tty_join_escaped_args "$@")"
    rc_file="$(mktemp "${TMPDIR:-/tmp}/janus-tty.XXXXXX")" || {
        printf '[ERROR] Unable to allocate temporary status file for pseudo-TTY flow.\n' >&2
        return 1
    }
    rc_file_escaped="$(printf '%q' "$rc_file")"
    wrapped_command="$command_string; __janus_tty_rc=\$?; printf '%s' \"\$__janus_tty_rc\" > $rc_file_escaped; exit \"\$__janus_tty_rc\""

    # shellcheck disable=SC2312
    script -q -c "$wrapped_command" /dev/null
    script_rc=$?

    if [ -r "$rc_file" ]; then
        child_rc="$(cat "$rc_file" 2>/dev/null || true)"
    fi
    rm -f "$rc_file"

    case "$child_rc" in
        ''|*[!0-9]*)
            if [ "$script_rc" -ne 0 ]; then
                printf '[WARN] Pseudo-TTY via `script` failed; continuing without pseudo-TTY.\n' >&2
                return "$JANUS_TTY_UNAVAILABLE_RC"
            fi
            return "$script_rc"
            ;;
        *)
            return "$child_rc"
            ;;
    esac
}
