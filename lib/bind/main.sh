#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Main
# ----------------------------------------------------------------------------
# This file composes janus-bind modules and exposes janus_bind_main.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_MAIN_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_MAIN_LOADED=1

JANUS_ROOT_DIR="${JANUS_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../core/runtime/paths.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/paths.sh"
# shellcheck source=../core/runtime/logging.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/logging.sh"
# shellcheck source=../core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"
# shellcheck source=core/context.sh
source "$JANUS_ROOT_DIR/lib/bind/core/context.sh"
# shellcheck source=core/helpers.sh
source "$JANUS_ROOT_DIR/lib/bind/core/helpers.sh"
# shellcheck source=ops/list.sh
source "$JANUS_ROOT_DIR/lib/bind/ops/list.sh"
# shellcheck source=ops/resolve.sh
source "$JANUS_ROOT_DIR/lib/bind/ops/resolve.sh"
# shellcheck source=ops/safety.sh
source "$JANUS_ROOT_DIR/lib/bind/ops/safety.sh"
# shellcheck source=ops/apply.sh
source "$JANUS_ROOT_DIR/lib/bind/ops/apply.sh"
# shellcheck source=cli/args.sh
source "$JANUS_ROOT_DIR/lib/bind/cli/args.sh"

# Execute janus-bind workflow.
janus_bind_main() {
    local group=""

    janus_runtime_start_logging "janus-bind" || exit 1

    JANUS_BIND_STATE_DIR="$(janus_runtime_resolve_state_dir)" \
        || janus_bind_die "Unable to create state directory."

    janus_bind_parse_args "$@"

    printf '=== Janus VFIO Bind v%s ===\n' "$JANUS_BIND_VERSION"

    janus_bind_validate_option_combinations

    if [ "$JANUS_BIND_ROLLBACK" -eq 1 ]; then
        janus_bind_rollback_last
        return 0
    fi

    janus_bind_validate_environment
    janus_bind_resolve_targets

    group="$(janus_bind_pci_iommu_group "${JANUS_BIND_DEVICES[0]}")"
    janus_bind_analyze_group_safety "$group" || {
        janus_bind_confirm "Continue despite unsafe IOMMU group?" || exit 1
    }

    if [ "$JANUS_BIND_MODE" = "dry-run" ]; then
        janus_bind_dry_run
        return 0
    fi

    janus_bind_log_warn "APPLY mode selected. This will modify active driver bindings."
    janus_bind_confirm "Apply VFIO binding now?" || return 0

    janus_bind_apply
    janus_bind_log_ok "VFIO binding completed."
}
