#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check Context
# ----------------------------------------------------------------------------
# This file holds mutable state and logging wrappers for janus-check.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_CHECK_CONTEXT_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_CHECK_CONTEXT_LOADED=1

JANUS_CHECK_VERSION="0.2"

JANUS_CHECK_NO_INTERACTIVE=0
JANUS_CHECK_INTERACTIVE_TTY=0

JANUS_CHECK_CRITICAL_COUNT=0
JANUS_CHECK_WARN_COUNT=0
JANUS_CHECK_INFO_COUNT=0

# Emit an INFO message and increment INFO count.
janus_check_log_info() {
    janus_log_info "$*"
    JANUS_CHECK_INFO_COUNT=$((JANUS_CHECK_INFO_COUNT + 1))
}

# Emit an OK message.
janus_check_log_ok() {
    janus_log_ok "$*"
}

# Emit a WARN message and increment WARN count.
janus_check_log_warn() {
    janus_log_warn "$*"
    JANUS_CHECK_WARN_COUNT=$((JANUS_CHECK_WARN_COUNT + 1))
}

# Emit a CRITICAL message and increment CRITICAL count.
janus_check_log_critical() {
    janus_log_critical "$*"
    JANUS_CHECK_CRITICAL_COUNT=$((JANUS_CHECK_CRITICAL_COUNT + 1))
}
