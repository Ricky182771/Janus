#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init Context
# ----------------------------------------------------------------------------
# This file defines shared state used across janus-init modules.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_CONTEXT_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_CONTEXT_LOADED=1

JANUS_INIT_VERSION="0.1"

# Define user-scoped directories and files.
JANUS_INIT_CONFIG_DIR="${HOME}/.config/janus"
JANUS_INIT_CACHE_DIR="${HOME}/.cache/janus"
JANUS_INIT_LOG_DIR="$JANUS_INIT_CACHE_DIR/logs"
JANUS_INIT_STATE_DIR="$JANUS_INIT_CONFIG_DIR/state"
JANUS_INIT_PROFILE_DIR="$JANUS_INIT_CONFIG_DIR/profiles"

JANUS_INIT_CONF_FILE="$JANUS_INIT_CONFIG_DIR/janus.conf"
JANUS_INIT_STATE_FILE="$JANUS_INIT_STATE_DIR/janus.state"

# Track warning/info metrics for the summary.
JANUS_INIT_WARN_COUNT=0
JANUS_INIT_INFO_COUNT=0

# Emit an INFO message and increment counter.
janus_init_log_info() {
    janus_log_info "$*"
    JANUS_INIT_INFO_COUNT=$((JANUS_INIT_INFO_COUNT + 1))
}

# Emit an OK message.
janus_init_log_ok() {
    janus_log_ok "$*"
}

# Emit a WARN message and increment counter.
janus_init_log_warn() {
    janus_log_warn "$*"
    JANUS_INIT_WARN_COUNT=$((JANUS_INIT_WARN_COUNT + 1))
}

# Emit an ERROR message.
janus_init_log_error() {
    janus_log_error "$*"
}

# Exit the command with an error message.
janus_init_die() {
    janus_init_log_error "$1"
    exit 1
}
