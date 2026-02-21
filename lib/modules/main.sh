#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Module Loader
# ----------------------------------------------------------------------------
# This file provides module discovery, API validation, and action invocation.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_MODULES_MAIN_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_MODULES_MAIN_LOADED=1

JANUS_ROOT_DIR="${JANUS_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../core/runtime/logging.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/logging.sh"

JANUS_MODULE_EXEC_MODE="${JANUS_MODULE_EXEC_MODE:-source}"
JANUS_MODULE_API_VERSION_SUPPORTED="${JANUS_MODULE_API_VERSION_SUPPORTED:-1}"
JANUS_MODULE_LOADED_FUNCTIONS="${JANUS_MODULE_LOADED_FUNCTIONS:-}"
JANUS_MODULE_LOADED_PATH="${JANUS_MODULE_LOADED_PATH:-}"

# Print candidate module scripts in deterministic order.
janus_modules_find() {
    local modules_dir="${JANUS_ROOT_DIR}/modules"

    [ -d "$modules_dir" ] || return 0
    find "$modules_dir" -mindepth 2 -maxdepth 2 -type f -name "*.sh" | sort
}

# Remove symbols from the currently loaded module.
janus_module_unload() {
    local function_name=""

    while IFS= read -r function_name; do
        [ -n "$function_name" ] || continue
        unset -f "$function_name" 2>/dev/null || true
    done <<< "$JANUS_MODULE_LOADED_FUNCTIONS"

    JANUS_MODULE_LOADED_FUNCTIONS=""
    JANUS_MODULE_LOADED_PATH=""

    unset JANUS_MODULE_TYPE
    unset JANUS_MODULE_ID
    unset JANUS_MODULE_VERSION
    unset JANUS_MODULE_COMPAT_API
}

# Validate required metadata and lifecycle functions after module load.
janus_module_validate_loaded() {
    local module_path="$1"
    local valid=0
    local field=""
    local fn=""

    for field in JANUS_MODULE_TYPE JANUS_MODULE_ID JANUS_MODULE_VERSION JANUS_MODULE_COMPAT_API; do
        if [ -z "${!field:-}" ]; then
            janus_log_error "Invalid module '$module_path': missing required metadata '$field'."
            valid=1
        fi
    done

    for fn in janus_module_check janus_module_apply janus_module_rollback; do
        if ! declare -F "$fn" >/dev/null 2>&1; then
            janus_log_error "Invalid module '$module_path': missing function '$fn'."
            valid=1
        fi
    done

    if ! [[ "${JANUS_MODULE_COMPAT_API:-}" =~ ^[0-9]+$ ]]; then
        janus_log_error "Invalid module '$module_path': JANUS_MODULE_COMPAT_API must be numeric."
        valid=1
    elif [ "${JANUS_MODULE_COMPAT_API:-0}" != "$JANUS_MODULE_API_VERSION_SUPPORTED" ]; then
        janus_log_error "Invalid module '$module_path': API '${JANUS_MODULE_COMPAT_API}' is not supported (expected '${JANUS_MODULE_API_VERSION_SUPPORTED}')."
        valid=1
    fi

    [ "$valid" -eq 0 ]
}

# Source and validate one module under the current shell context.
janus_module_load() {
    local module_path="$1"
    local functions_before=""
    local functions_after=""
    local function_name=""

    if [ ! -f "$module_path" ]; then
        janus_log_error "Module not found: $module_path"
        return 1
    fi

    janus_module_unload
    functions_before="$(declare -F | awk '{print $3}')"

    # shellcheck source=/dev/null
    source "$module_path"
    functions_after="$(declare -F | awk '{print $3}')"

    JANUS_MODULE_LOADED_FUNCTIONS=""
    while IFS= read -r function_name; do
        [ -n "$function_name" ] || continue
        if ! grep -Fxq "$function_name" <<< "$functions_before"; then
            JANUS_MODULE_LOADED_FUNCTIONS+="$function_name"$'\n'
        fi
    done <<< "$functions_after"

    if ! janus_module_validate_loaded "$module_path"; then
        janus_module_unload
        return 1
    fi

    JANUS_MODULE_LOADED_PATH="$module_path"
    return 0
}

# Print machine-readable metadata for the currently loaded module.
janus_module_print_metadata() {
    printf 'id=%s\n' "${JANUS_MODULE_ID:-}"
    printf 'type=%s\n' "${JANUS_MODULE_TYPE:-}"
    printf 'version=%s\n' "${JANUS_MODULE_VERSION:-}"
    printf 'compat_api=%s\n' "${JANUS_MODULE_COMPAT_API:-}"
    printf 'path=%s\n' "${JANUS_MODULE_LOADED_PATH:-}"
}

# Find a module path by JANUS_MODULE_ID.
janus_module_find_by_id() {
    local module_id="$1"
    local module_path=""

    while IFS= read -r module_path; do
        [ -n "$module_path" ] || continue
        if ! janus_module_load "$module_path"; then
            continue
        fi
        if [ "${JANUS_MODULE_ID:-}" = "$module_id" ]; then
            printf '%s' "$module_path"
            janus_module_unload
            return 0
        fi
    done < <(janus_modules_find)

    janus_module_unload
    return 1
}

# Discover modules and print their metadata blocks.
janus_modules_discover() {
    local module_path=""
    local discovered=0

    while IFS= read -r module_path; do
        [ -n "$module_path" ] || continue
        if ! janus_module_load "$module_path"; then
            janus_log_warn "Skipping invalid module: $module_path"
            continue
        fi

        janus_module_print_metadata
        printf '\n'
        discovered=$((discovered + 1))
        janus_module_unload
    done < <(janus_modules_find)

    [ "$discovered" -gt 0 ] || janus_log_warn "No modules discovered under '$JANUS_ROOT_DIR/modules'."
    return 0
}

# Execute one lifecycle action on a loaded module.
janus_module_run_loaded_action() {
    local action="$1"
    local rc=0

    case "$action" in
        check)
            if janus_module_check; then
                rc=0
            else
                rc=$?
            fi
            ;;
        apply)
            if janus_module_apply; then
                rc=0
            else
                rc=$?
            fi
            ;;
        rollback)
            if janus_module_rollback; then
                rc=0
            else
                rc=$?
            fi
            ;;
        *)
            janus_log_error "Unsupported module action '$action'. Use: check|apply|rollback."
            return 1
            ;;
    esac

    return "$rc"
}

# Execute one module action using source-mode (in-process).
janus_module_run_action_source() {
    local module_path="$1"
    local action="$2"
    local rc=0

    if ! janus_module_load "$module_path"; then
        return 1
    fi

    if janus_module_run_loaded_action "$action"; then
        rc=0
    else
        rc=$?
    fi

    janus_module_unload
    return "$rc"
}

# Execute one module action using subshell mode for stronger isolation.
janus_module_run_action_subshell() {
    local module_path="$1"
    local action="$2"

    bash "$module_path" "$action"
}

# Execute one module action based on JANUS_MODULE_EXEC_MODE.
janus_module_run_action() {
    local module_path="$1"
    local action="$2"

    case "$JANUS_MODULE_EXEC_MODE" in
        source) janus_module_run_action_source "$module_path" "$action" ;;
        subshell) janus_module_run_action_subshell "$module_path" "$action" ;;
        *)
            janus_log_error "Invalid JANUS_MODULE_EXEC_MODE '$JANUS_MODULE_EXEC_MODE'. Use: source|subshell."
            return 1
            ;;
    esac
}
