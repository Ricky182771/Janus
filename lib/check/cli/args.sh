#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check CLI
# ----------------------------------------------------------------------------
# This file parses command options and resolves janus-init location.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_CLI_ARGS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_CLI_ARGS_LOADED=1

# Print help for janus-check.
janus_check_show_help() {
    local exit_code="${1:-0}"

    cat <<EOF_HELP
Usage: ./janus-check [OPTIONS]

Options:
  --help, -h         Show this help
  --version, -v      Show version
  --no-interactive   Do not prompt (useful for CI / examples)

Examples:
  ./janus-check
  ./janus-check --no-interactive

Notes:
  - This command is diagnostic-only. It does not apply system changes.
  - If no interactive TTY is available, prompts are skipped automatically.
EOF_HELP

    exit "$exit_code"
}

# Parse janus-check command-line flags.
janus_check_parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                janus_check_show_help
                ;;
            --version|-v)
                printf 'janus-check v%s\n' "$JANUS_CHECK_VERSION"
                exit 0
                ;;
            --no-interactive)
                JANUS_CHECK_NO_INTERACTIVE=1
                ;;
            *)
                printf 'Unknown option: %s\n' "$1"
                janus_check_show_help 1
                ;;
        esac
        shift
    done
}

# Locate janus-init script for post-check handoff.
janus_check_find_janus_init() {
    if [ -x "$(dirname "$0")/janus-init.sh" ]; then
        printf '%s' "$(dirname "$0")/janus-init.sh"
        return 0
    fi

    if command -v janus-init >/dev/null 2>&1; then
        command -v janus-init
        return 0
    fi

    return 1
}
