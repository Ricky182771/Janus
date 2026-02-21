#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_ENTRY="$ROOT_DIR/orchestrator/janus_tui.py"
TTY_LIB="$ROOT_DIR/lib/tty.sh"

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
  - In headless runs, Janus will try pseudo-TTY and then safe headless fallback.
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

if [ ! -f "$TTY_LIB" ]; then
    printf '[ERROR] Missing TTY helper module: %s\n' "$TTY_LIB" >&2
    exit 1
fi
source "$TTY_LIB"

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

if [ "$SKIP_PREFLIGHT" -eq 0 ] && ! janus_tty_has_stdin && [ -z "${JANUS_ORCH_TTY_REEXEC:-}" ]; then
    export JANUS_ORCH_TTY_REEXEC=1
    if ensure_tty python3 "$PY_ENTRY" "$@"; then
        tty_rc=0
    else
        tty_rc=$?
    fi
    unset JANUS_ORCH_TTY_REEXEC

    if [ "$tty_rc" -eq 0 ]; then
        exit 0
    fi

    if [ "$tty_rc" -eq "$JANUS_TTY_UNAVAILABLE_RC" ]; then
        printf '[WARN] Pseudo-TTY is unavailable. Falling back to headless mode (--list-languages).\n' >&2
        exec python3 "$PY_ENTRY" --list-languages
    fi

    exit "$tty_rc"
fi

exec python3 "$PY_ENTRY" "$@"
