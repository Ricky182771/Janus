#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/vm/.
# It performs early root gating for explicitly mutating operations.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"
# shellcheck source=../lib/tty.sh
source "$JANUS_ROOT_DIR/lib/tty.sh"

# Explicit guided mode needs interactive input. If stdin is not a TTY:
# - first attempt pseudo-TTY re-exec through ensure_tty;
# - if pseudo-TTY is unavailable, transparently downgrade to --no-guided.
if janus_has_flag "--guided" "$@" && ! janus_tty_has_stdin && [ -z "${JANUS_VM_TTY_REEXEC:-}" ]; then
    export JANUS_VM_TTY_REEXEC=1
    ensure_tty bash "$0" "$@"
    tty_rc=$?
    unset JANUS_VM_TTY_REEXEC

    if [ "$tty_rc" -eq 0 ]; then
        exit 0
    fi

    if [ "$tty_rc" -eq "$JANUS_TTY_UNAVAILABLE_RC" ]; then
        janus_log_warn "Pseudo-TTY is unavailable; switching --guided to --no-guided."
        janus_vm_rewritten_args=()
        janus_vm_arg=""
        for janus_vm_arg in "$@"; do
            if [ "$janus_vm_arg" = "--guided" ]; then
                janus_vm_rewritten_args+=("--no-guided")
            else
                janus_vm_rewritten_args+=("$janus_vm_arg")
            fi
        done
        set -- "${janus_vm_rewritten_args[@]}"
    else
        exit "$tty_rc"
    fi
fi

# Request root early for mutating apply/force operations.
if janus_has_flag "--apply" "$@" || janus_has_flag "--force" "$@"; then
    janus_require_root "janus-vm" || exit 1
fi

# shellcheck source=../lib/vm/main.sh
source "$JANUS_ROOT_DIR/lib/vm/main.sh"

janus_vm_main "$@"
