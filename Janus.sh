#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_ENTRY="$ROOT_DIR/orchestrator/janus_tui.py"

janus_orchestrator_show_help() {
    cat <<EOF_HELP
Janus Orchestrator

Usage:
  ./Janus.sh [--lang en|es] [--list-languages]
  ./Janus.sh --help

Options:
  --lang CODE         UI language code (example: en, es)
  --list-languages    List available language packs
  --help, -h          Show this help

Notes:
  - Some actions require root and will request sudo credentials.
  - This script runs an interactive terminal UI.
EOF_HELP
}

if [ ! -f "$PY_ENTRY" ]; then
    printf '[ERROR] Missing orchestrator entrypoint: %s\n' "$PY_ENTRY" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf '[ERROR] python3 is required to run Janus.sh\n' >&2
    exit 1
fi

case "${1:-}" in
    --help|-h)
        janus_orchestrator_show_help
        exit 0
        ;;
esac

SKIP_PREFLIGHT=0
for arg in "$@"; do
    if [ "$arg" = "--list-languages" ]; then
        SKIP_PREFLIGHT=1
        break
    fi
done

# Optional sudo preflight for smoother root-required actions later.
if [ "$SKIP_PREFLIGHT" -eq 0 ] && [ "${JANUS_NO_SUDO_PREFLIGHT:-0}" != "1" ] && [ "$(id -u)" -ne 0 ] && [ -t 0 ] && [ -t 1 ]; then
    printf '[INFO] Janus can request root privileges for install/apply actions.\n'
    read -r -p 'Validate sudo credentials now? [Y/n]: ' answer || true
    if [[ ! "${answer:-}" =~ ^[Nn]$ ]]; then
        sudo -v || {
            printf '[ERROR] sudo authentication failed.\n' >&2
            exit 1
        }
    fi
fi

exec python3 "$PY_ENTRY" "$@"
