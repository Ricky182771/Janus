#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init Filesystem Steps
# ----------------------------------------------------------------------------
# This file creates required user-scoped Janus directories.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_STEP_FILESYSTEM_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_STEP_FILESYSTEM_LOADED=1

# Create all Janus directories under the user's home.
janus_init_create_directories() {
    janus_init_log_info "Creating Janus directory structure..."

    mkdir -p \
        "$JANUS_INIT_CONFIG_DIR" \
        "$JANUS_INIT_CACHE_DIR" \
        "$JANUS_INIT_LOG_DIR" \
        "$JANUS_INIT_STATE_DIR" \
        "$JANUS_INIT_PROFILE_DIR" \
        || janus_init_die "Unable to create Janus directories under $HOME."

    janus_init_log_ok "Directories initialized under ~/.config and ~/.cache"
}
