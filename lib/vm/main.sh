#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Main
# ----------------------------------------------------------------------------
# This file composes janus-vm modules and exposes janus_vm_main.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_VM_MAIN_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_VM_MAIN_LOADED=1

JANUS_ROOT_DIR="${JANUS_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../core/runtime/logging.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/logging.sh"
# shellcheck source=../core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"

# shellcheck source=core/context.sh
source "$JANUS_ROOT_DIR/lib/vm/core/context.sh"
# shellcheck source=core/helpers.sh
source "$JANUS_ROOT_DIR/lib/vm/core/helpers.sh"
# shellcheck source=core/validate.sh
source "$JANUS_ROOT_DIR/lib/vm/core/validate.sh"

# shellcheck source=cli/args.sh
source "$JANUS_ROOT_DIR/lib/vm/cli/args.sh"
# shellcheck source=cli/wizard.sh
source "$JANUS_ROOT_DIR/lib/vm/cli/wizard.sh"

# shellcheck source=xml/blocks.sh
source "$JANUS_ROOT_DIR/lib/vm/xml/blocks.sh"
# shellcheck source=xml/render.sh
source "$JANUS_ROOT_DIR/lib/vm/xml/render.sh"

# shellcheck source=storage/unattend.sh
source "$JANUS_ROOT_DIR/lib/vm/storage/unattend.sh"

# shellcheck source=actions/create.sh
source "$JANUS_ROOT_DIR/lib/vm/actions/create.sh"
# shellcheck source=actions/lifecycle.sh
source "$JANUS_ROOT_DIR/lib/vm/actions/lifecycle.sh"

# Execute janus-vm action flow.
janus_vm_main() {
    janus_runtime_start_logging "janus-vm" || exit 1

    janus_vm_parse_args "$@"
    janus_vm_validate_common
    janus_vm_maybe_run_guided_create_wizard

    case "$JANUS_VM_ACTION" in
        create)
            janus_vm_validate_create
            ;;
        start|stop|status)
            janus_vm_validate_non_create
            ;;
        *)
            janus_vm_die "Unhandled action: $JANUS_VM_ACTION"
            ;;
    esac

    case "$JANUS_VM_ACTION" in
        create)
            janus_vm_create
            ;;
        start)
            janus_vm_start
            ;;
        stop)
            janus_vm_stop
            ;;
        status)
            janus_vm_status
            ;;
        *)
            janus_vm_die "Unhandled action: $JANUS_VM_ACTION"
            ;;
    esac
}
