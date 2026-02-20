#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init Main
# ----------------------------------------------------------------------------
# This file wires janus-init modules and exposes janus_init_main.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_MAIN_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_MAIN_LOADED=1

JANUS_ROOT_DIR="${JANUS_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../core/runtime/logging.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/logging.sh"
# shellcheck source=core/context.sh
source "$JANUS_ROOT_DIR/lib/init/core/context.sh"
# shellcheck source=cli/args.sh
source "$JANUS_ROOT_DIR/lib/init/cli/args.sh"
# shellcheck source=steps/filesystem.sh
source "$JANUS_ROOT_DIR/lib/init/steps/filesystem.sh"
# shellcheck source=steps/config.sh
source "$JANUS_ROOT_DIR/lib/init/steps/config.sh"
# shellcheck source=steps/state.sh
source "$JANUS_ROOT_DIR/lib/init/steps/state.sh"
# shellcheck source=steps/permissions.sh
source "$JANUS_ROOT_DIR/lib/init/steps/permissions.sh"

# Print the final init summary and next steps.
janus_init_print_summary() {
    printf '%s\n' '----------------------------------------'
    printf 'Initialization finished: %d WARN, %d INFO\n' \
        "$JANUS_INIT_WARN_COUNT" \
        "$JANUS_INIT_INFO_COUNT"

    printf '\n'
    printf 'Next steps:\n'
    printf '  -> Review: %s\n' "$JANUS_INIT_CONF_FILE"
    printf '  -> Run: janus-check (if not already done)\n'
    printf '  -> Continue with: janus-bind (when ready for VFIO)\n'
    printf '\n'
    printf 'This command did not apply system-level changes.\n'
    printf 'Logs:\n'
    printf '  - %s\n' "$JANUS_LOG_FILE"
    printf '  - %s\n' "$JANUS_MAIN_LOG_FILE"
}

# Execute the janus-init workflow.
janus_init_main() {
    janus_runtime_start_logging "janus-init" || exit 1

    janus_init_parse_args "$@"

    printf '=== Janus Initialization v%s ===\n' "$JANUS_INIT_VERSION"

    janus_init_create_directories
    janus_init_create_config
    janus_init_create_state
    janus_init_check_permissions
    janus_init_finalize_config

    janus_init_print_summary
}
