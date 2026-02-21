#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/bind/.
# It also performs early root gating for mutating modes.
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"
# shellcheck source=../lib/tty.sh
source "$JANUS_ROOT_DIR/lib/tty.sh"

# janus-bind can prompt for confirmations when --yes is not set.
# For non-TTY runs:
# - first try pseudo-TTY re-exec through ensure_tty;
# - if pseudo-TTY is unavailable, switch to non-interactive confirmation mode.
if ! janus_has_flag "--yes" "$@" \
    && ! janus_has_flag "--help" "$@" \
    && ! janus_has_flag "-h" "$@" \
    && ! janus_has_flag "--list" "$@" \
    && ! janus_tty_has_stdin \
    && [ -z "${JANUS_BIND_TTY_REEXEC:-}" ]; then
    export JANUS_BIND_TTY_REEXEC=1
    if ensure_tty bash "$0" "$@"; then
        exit 0
    else
        tty_rc=$?
    fi
    unset JANUS_BIND_TTY_REEXEC

    if [ "$tty_rc" -eq "$JANUS_TTY_UNAVAILABLE_RC" ]; then
        janus_log_warn "Pseudo-TTY is unavailable; continuing with --yes."
        set -- "$@" "--yes"
    else
        exit "$tty_rc"
    fi
fi

# Request root early when a mutating bind action is requested.
if janus_has_flag "--apply" "$@" || janus_has_flag "--rollback" "$@"; then
    janus_require_root "janus-bind" || exit 1
fi

# shellcheck source=../lib/bind/main.sh
source "$JANUS_ROOT_DIR/lib/bind/main.sh"

janus_bind_main "$@"
