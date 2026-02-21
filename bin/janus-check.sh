#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/check/.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"
# shellcheck source=../lib/tty.sh
source "$JANUS_ROOT_DIR/lib/tty.sh"

# If check is launched without a TTY, try pseudo-TTY first so prompts can work.
# When pseudo-TTY is unavailable, continue in explicit non-interactive mode.
if ! janus_has_flag "--no-interactive" "$@" \
    && ! janus_has_flag "--help" "$@" \
    && ! janus_has_flag "-h" "$@" \
    && ! janus_has_flag "--version" "$@" \
    && ! janus_has_flag "-v" "$@" \
    && ! janus_tty_has_stdin \
    && [ -z "${JANUS_CHECK_TTY_REEXEC:-}" ]; then
    export JANUS_CHECK_TTY_REEXEC=1
    ensure_tty bash "$0" "$@"
    tty_rc=$?
    unset JANUS_CHECK_TTY_REEXEC

    if [ "$tty_rc" -eq 0 ]; then
        exit 0
    fi

    if [ "$tty_rc" -eq "$JANUS_TTY_UNAVAILABLE_RC" ]; then
        janus_log_warn "Pseudo-TTY is unavailable; continuing with --no-interactive."
        set -- "$@" "--no-interactive"
    else
        exit "$tty_rc"
    fi
fi

# shellcheck source=../lib/check/main.sh
source "$JANUS_ROOT_DIR/lib/check/main.sh"

janus_check_main "$@"
