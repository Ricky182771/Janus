#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus TTY Compatibility Shim
# ----------------------------------------------------------------------------
# Keep a stable source path at lib/tty.sh while implementation lives in
# lib/core/runtime/tty.sh.
# ----------------------------------------------------------------------------

if [ -n "${JANUS_TTY_SHIM_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
JANUS_TTY_SHIM_LOADED=1

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/core/runtime/tty.sh"

