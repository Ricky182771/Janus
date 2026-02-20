#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init CLI
# ----------------------------------------------------------------------------
# This file handles command-line help and argument parsing.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_CLI_ARGS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_CLI_ARGS_LOADED=1

# Print command help text.
janus_init_show_help() {
    local exit_code="${1:-0}"

    cat <<EOF_HELP
Usage: ./janus-init [OPTIONS]

Options:
  --help, -h       Show this help
  --version, -v    Show version

Examples:
  ./janus-init
  ./janus-init --version

Notes:
  - This command is non-destructive and does not edit kernel/boot settings.
  - It only creates Janus state/config files in your home directory.
EOF_HELP

    exit "$exit_code"
}

# Parse and validate command-line arguments.
janus_init_parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                janus_init_show_help
                ;;
            --version|-v)
                printf 'janus-init v%s\n' "$JANUS_INIT_VERSION"
                exit 0
                ;;
            *)
                janus_init_log_error "Unknown option: $1"
                janus_init_show_help 1
                ;;
        esac
        shift
    done
}
