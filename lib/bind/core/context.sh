#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Context
# ----------------------------------------------------------------------------
# This file stores shared state for janus-bind modules.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_BIND_CONTEXT_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_BIND_CONTEXT_LOADED=1

JANUS_BIND_VERSION="0.1"

JANUS_BIND_STATE_DIR=""
JANUS_BIND_LOG_FILE=""

JANUS_BIND_MODE="dry-run"
JANUS_BIND_TARGET_DEVICE=""
JANUS_BIND_TARGET_GROUP=""
JANUS_BIND_ROLLBACK=0
JANUS_BIND_ASSUME_YES=0
JANUS_BIND_VERBOSE=0
JANUS_BIND_DEVICES=()

# Emit a standard INFO message.
janus_bind_log_info() {
    janus_log_info "$*"
}

# Emit a standard OK message.
janus_bind_log_ok() {
    janus_log_ok "$*"
}

# Emit a standard WARN message.
janus_bind_log_warn() {
    janus_log_warn "$*"
}

# Emit a standard ERROR message.
janus_bind_log_error() {
    janus_log_error "$*"
}

# Emit DEBUG only when verbose mode is enabled.
janus_bind_log_debug() {
    if [ "$JANUS_BIND_VERBOSE" -eq 1 ]; then
        janus_log_debug "$*"
    fi
}

# Exit with an error message.
janus_bind_die() {
    janus_bind_log_error "$1"
    exit 1
}
