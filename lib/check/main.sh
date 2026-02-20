#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check Main
# ----------------------------------------------------------------------------
# This file composes all janus-check modules and exposes janus_check_main.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_MAIN_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_MAIN_LOADED=1

JANUS_ROOT_DIR="${JANUS_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=../core/runtime/logging.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/logging.sh"
# shellcheck source=../core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"
# shellcheck source=core/context.sh
source "$JANUS_ROOT_DIR/lib/check/core/context.sh"
# shellcheck source=cli/args.sh
source "$JANUS_ROOT_DIR/lib/check/cli/args.sh"
# shellcheck source=probes/system.sh
source "$JANUS_ROOT_DIR/lib/check/probes/system.sh"
# shellcheck source=probes/virt.sh
source "$JANUS_ROOT_DIR/lib/check/probes/virt.sh"
# shellcheck source=probes/gpu.sh
source "$JANUS_ROOT_DIR/lib/check/probes/gpu.sh"

# Print summary and optionally hand off to janus-init.
janus_check_finish() {
    local init_path=""
    local answer=""

    printf '%s\n' '----------------------------------------'
    printf 'Summary: %d CRITICAL, %d WARN, %d INFO\n' \
        "$JANUS_CHECK_CRITICAL_COUNT" \
        "$JANUS_CHECK_WARN_COUNT" \
        "$JANUS_CHECK_INFO_COUNT"

    printf 'Logs:\n'
    printf '  - %s\n' "$JANUS_LOG_FILE"
    printf '  - %s\n' "$JANUS_MAIN_LOG_FILE"

    if [ "$JANUS_CHECK_CRITICAL_COUNT" -gt 0 ]; then
        printf '\n'
        printf 'Critical issues were detected.\n'
        printf 'Resolve them before continuing with Janus initialization.\n'
        exit 2
    fi

    init_path="$(janus_check_find_janus_init || true)"
    if [ -z "$init_path" ]; then
        janus_check_log_warn "janus-init not found. Run it manually to continue setup."
        exit 0
    fi

    printf '\n'

    if [ "$JANUS_CHECK_NO_INTERACTIVE" -eq 1 ]; then
        janus_check_log_info "Non-interactive mode: skipping janus-init prompt."
        exit 0
    fi

    if [ "$JANUS_CHECK_INTERACTIVE_TTY" -eq 0 ]; then
        janus_check_log_info "No interactive TTY detected: skipping janus-init prompt."
        exit 0
    fi

    if read -r -p "Run janus-init now? (recommended) [Y/n]: " answer; then
        if [[ ! "$answer" =~ ^[Nn]$ ]]; then
            printf '\n'
            printf 'Launching janus-init...\n'
            exec "$init_path"
        fi
    else
        janus_check_log_info "Input unavailable: skipping janus-init prompt."
    fi

    exit 0
}

# Execute the full diagnostic flow.
janus_check_main() {
    local answer=""

    janus_runtime_start_logging "last_check" || exit 1

    janus_check_parse_args "$@"

    if janus_is_interactive_tty; then
        JANUS_CHECK_INTERACTIVE_TTY=1
    fi

    printf '=== Janus Diagnostic v%s - %s ===\n' \
        "$JANUS_CHECK_VERSION" \
        "$(date '+%Y-%m-%d %H:%M:%S')"

    janus_check_probe_system_info
    printf '%s\n' '----------------------------------------'
    janus_check_probe_cpu_virt
    printf '%s\n' '----------------------------------------'
    janus_check_probe_iommu
    printf '%s\n' '----------------------------------------'
    janus_check_probe_virt_tools
    printf '%s\n' '----------------------------------------'
    janus_check_probe_kernel_modules
    printf '%s\n' '----------------------------------------'
    janus_check_probe_hugepages
    printf '%s\n' '----------------------------------------'
    janus_check_probe_gpus
    printf '%s\n' '----------------------------------------'

    if [ "$JANUS_CHECK_NO_INTERACTIVE" -eq 1 ]; then
        janus_check_log_info "Non-interactive mode: skipping IOMMU group prompt."
    elif [ "$JANUS_CHECK_INTERACTIVE_TTY" -eq 0 ]; then
        janus_check_log_info "No interactive TTY detected: skipping IOMMU group prompt."
    else
        read -r -p "Show detailed IOMMU groups? (y/N): " answer || true
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            printf '%s\n' '----------------------------------------'
            janus_check_probe_iommu_groups_detailed
        fi
    fi

    janus_check_log_ok "Diagnostic complete."
    janus_check_log_info "Share $JANUS_LOG_FILE in issues to help debugging."

    janus_check_finish
}
