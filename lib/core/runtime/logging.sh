#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Runtime Logging
# ----------------------------------------------------------------------------
# This file defines shared logging helpers and session log wiring.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_RUNTIME_LOGGING_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_RUNTIME_LOGGING_LOADED=1

# shellcheck source=paths.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

JANUS_LOG_ENABLE_COLOR="${JANUS_LOG_ENABLE_COLOR:-1}"
JANUS_LOG_FILE="${JANUS_LOG_FILE:-}"
JANUS_MAIN_LOG_FILE="${JANUS_MAIN_LOG_FILE:-}"

# Map log levels to ANSI colors.
janus_log_color() {
    case "$1" in
        INFO) printf '%s' $'\033[0;34m' ;;
        OK) printf '%s' $'\033[0;32m' ;;
        WARN) printf '%s' $'\033[1;33m' ;;
        ERROR|CRITICAL) printf '%s' $'\033[0;31m' ;;
        DEBUG) printf '%s' $'\033[0;36m' ;;
        *) printf '' ;;
    esac
}

# Print a standardized Janus log message.
janus_log() {
    local level="${1:-INFO}"
    shift || true

    local message="$*"
    local color=""
    local reset=""

    if [ "$JANUS_LOG_ENABLE_COLOR" = "1" ]; then
        color="$(janus_log_color "$level")"
        reset=$'\033[0m'
    fi

    if [ -n "$color" ]; then
        printf '%b[%s]%b %s\n' "$color" "$level" "$reset" "$message"
    else
        printf '[%s] %s\n' "$level" "$message"
    fi
}

janus_log_info() { janus_log INFO "$*"; }
janus_log_ok() { janus_log OK "$*"; }
janus_log_warn() { janus_log WARN "$*"; }
janus_log_error() { janus_log ERROR "$*"; }
janus_log_critical() { janus_log CRITICAL "$*"; }
janus_log_debug() { janus_log DEBUG "$*"; }

# Initialize command logging to both command-specific file and janus.log.
janus_runtime_start_logging() {
    local prefix="$1"
    local log_dir=""
    local tee_pid=""

    [ -n "$prefix" ] || prefix="janus"
    log_dir="$(janus_runtime_resolve_log_dir)" || {
        echo "[ERROR] Unable to resolve log directory." >&2
        return 1
    }

    JANUS_LOG_FILE="$log_dir/${prefix}_$(date +%Y%m%d_%H%M%S).log"
    JANUS_MAIN_LOG_FILE="$log_dir/janus.log"

    if ! command -v tee >/dev/null 2>&1; then
        echo "[ERROR] 'tee' is required for logging but was not found." >&2
        return 1
    fi

    if ! touch "$JANUS_LOG_FILE" 2>/dev/null || ! touch "$JANUS_MAIN_LOG_FILE" 2>/dev/null; then
        echo "[ERROR] Unable to create log files in $log_dir." >&2
        return 1
    fi

    # Route all command output to terminal and both log files.
    exec > >(tee -a "$JANUS_LOG_FILE" "$JANUS_MAIN_LOG_FILE") 2>&1
    tee_pid=$!

    if [ -n "$tee_pid" ] && ! kill -0 "$tee_pid" 2>/dev/null; then
        echo "[ERROR] Log pipe process failed to start." >&2
        return 1
    fi

    export JANUS_LOG_FILE
    export JANUS_MAIN_LOG_FILE
}
