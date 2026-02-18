#!/usr/bin/env bash
# Shared logging contract for Janus scripts and modules.

if [ -n "${JANUS_LOG_LIB_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_LOG_LIB_LOADED=1

JANUS_LOG_ENABLE_COLOR="${JANUS_LOG_ENABLE_COLOR:-1}"

janus_log_color() {
    case "$1" in
        INFO) echo $'\033[0;34m' ;;
        OK) echo $'\033[0;32m' ;;
        WARN) echo $'\033[1;33m' ;;
        ERROR|CRITICAL) echo $'\033[0;31m' ;;
        DEBUG) echo $'\033[0;36m' ;;
        *) echo "" ;;
    esac
}

janus_log() {
    local level message color reset
    level="${1:-INFO}"
    shift || true
    message="$*"

    color=""
    reset=""
    if [ "${JANUS_LOG_ENABLE_COLOR}" = "1" ]; then
        color="$(janus_log_color "$level")"
        reset=$'\033[0m'
    fi

    if [ -n "$color" ]; then
        printf "%b[%s]%b %s\n" "$color" "$level" "$reset" "$message"
    else
        printf "[%s] %s\n" "$level" "$message"
    fi
}

janus_log_info() { janus_log INFO "$*"; }
janus_log_ok() { janus_log OK "$*"; }
janus_log_warn() { janus_log WARN "$*"; }
janus_log_error() { janus_log ERROR "$*"; }
janus_log_critical() { janus_log CRITICAL "$*"; }
janus_log_debug() { janus_log DEBUG "$*"; }
