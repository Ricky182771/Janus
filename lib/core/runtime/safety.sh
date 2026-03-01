#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Runtime Safety
# ----------------------------------------------------------------------------
# This file provides interaction and privilege helpers.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_RUNTIME_SAFETY_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_RUNTIME_SAFETY_LOADED=1

# shellcheck source=logging.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logging.sh"

# Return success when input is interactive and at least one output stream is
# (or was) interactive.  After janus_runtime_start_logging redirects stdout/
# stderr through tee, [ -t 1 ] and [ -t 2 ] become false even in real
# terminals.  JANUS_STDOUT_WAS_TTY captures the original state so prompts,
# wizards, and confirmations keep working after logging starts.
janus_is_interactive_tty() {
    [ -t 0 ] && { [ -t 1 ] || [ -t 2 ] || [ "${JANUS_STDOUT_WAS_TTY:-0}" = "1" ]; }
}

# Prompt for confirmation with a safe default of "No".
janus_confirm() {
    local prompt="$1"
    local answer=""

    read -r -p "$prompt [y/N]: " answer || true
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Exit when root privileges are required but missing.
janus_require_root() {
    local context="$1"

    if [ "$(id -u)" -ne 0 ]; then
        if [ -n "$context" ]; then
            janus_log_error "$context requires root privileges. Re-run with sudo."
        else
            janus_log_error "This action requires root privileges. Re-run with sudo."
        fi
        return 1
    fi

    return 0
}

# Detect whether an argument list contains a specific flag.
janus_has_flag() {
    local target="$1"
    shift || true

    local arg=""
    for arg in "$@"; do
        if [ "$arg" = "$target" ]; then
            return 0
        fi
    done

    return 1
}
