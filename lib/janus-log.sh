#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Logging Compatibility Entry Point
# ----------------------------------------------------------------------------
# This file keeps backward compatibility while delegating to the new runtime
# logging implementation under lib/core/runtime/.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_LOG_LIB_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_LOG_LIB_LOADED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core/runtime/logging.sh
source "$SCRIPT_DIR/core/runtime/logging.sh"
