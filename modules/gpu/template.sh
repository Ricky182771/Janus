#!/usr/bin/env bash

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/janus-log.sh
source "$SCRIPT_DIR/../../lib/janus-log.sh"

JANUS_MODULE_TYPE="gpu"
JANUS_MODULE_ID="gpu-template"
JANUS_MODULE_VERSION="0.1.0"
JANUS_MODULE_COMPAT_API="1"

janus_module_check() {
    janus_log INFO "[$JANUS_MODULE_ID] Running capability checks"
    # Replace this probe with real hardware checks.
    return 0
}

janus_module_apply() {
    janus_log INFO "[$JANUS_MODULE_ID] Applying configuration"
    # Add deterministic configuration steps here.
    return 0
}

janus_module_rollback() {
    janus_log WARN "[$JANUS_MODULE_ID] Rolling back changes"
    # Revert every side effect produced by janus_module_apply.
    return 0
}

# Backward-compatible aliases for legacy module contract.
check_capability() { janus_module_check "$@"; }
apply_config() { janus_module_apply "$@"; }
rollback() { janus_module_rollback "$@"; }

janus_module_meta() {
    printf 'id=%s\n' "$JANUS_MODULE_ID"
    printf 'type=%s\n' "$JANUS_MODULE_TYPE"
    printf 'version=%s\n' "$JANUS_MODULE_VERSION"
    printf 'compat_api=%s\n' "$JANUS_MODULE_COMPAT_API"
}

janus_module_main() {
    case "${1:-}" in
        check) janus_module_check ;;
        apply) janus_module_apply ;;
        rollback) janus_module_rollback ;;
        meta) janus_module_meta ;;
        *)
            janus_log ERROR "Usage: ${0##*/} {check|apply|rollback|meta}"
            return 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    janus_module_main "$@"
fi
