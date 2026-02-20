#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Runtime Paths
# ----------------------------------------------------------------------------
# This file centralizes writable-path selection with safe fallbacks.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_RUNTIME_PATHS_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_RUNTIME_PATHS_LOADED=1

# Select a writable directory, preferring the primary path.
janus_runtime_pick_writable_dir() {
    local primary="$1"
    local fallback="$2"
    local candidate=""
    local probe=""

    for candidate in "$primary" "$fallback"; do
        [ -n "$candidate" ] || continue

        if ! mkdir -p "$candidate" 2>/dev/null; then
            continue
        fi

        probe="$candidate/.janus_probe_$$"
        if touch "$probe" >/dev/null 2>&1; then
            rm -f "$probe"
            printf '%s' "$candidate"
            return 0
        fi
    done

    return 1
}

# Create and return the runtime log directory.
janus_runtime_resolve_log_dir() {
    local primary="${HOME:-/tmp}/.cache/janus/logs"
    local fallback="/tmp/janus/logs"

    janus_runtime_pick_writable_dir "$primary" "$fallback" || return 1
}

# Create and return the runtime state directory.
janus_runtime_resolve_state_dir() {
    local primary="${HOME:-/tmp}/.config/janus/state"
    local fallback="/tmp/janus/state"

    janus_runtime_pick_writable_dir "$primary" "$fallback" || return 1
}
