#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init State Steps
# ----------------------------------------------------------------------------
# This file writes initial runtime state metadata.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_INIT_STEP_STATE_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_INIT_STEP_STATE_LOADED=1

# Create the state file used by Janus workflows.
janus_init_create_state() {
    janus_init_log_info "Writing Janus state file"

    cat > "$JANUS_INIT_STATE_FILE" <<EOF_STATE
# Janus runtime state
INIT_DONE=true
INIT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
LAST_ACTION="janus-init"
EOF_STATE

    [ -f "$JANUS_INIT_STATE_FILE" ] || janus_init_die "Failed to create state file: $JANUS_INIT_STATE_FILE"

    janus_init_log_ok "State file written"
}
