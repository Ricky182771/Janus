#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Bind Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/bind/.
# It also performs early root gating for mutating modes.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"

# Request root early when a mutating bind action is requested.
if janus_has_flag "--apply" "$@" || janus_has_flag "--rollback" "$@"; then
    janus_require_root "janus-bind" || exit 1
fi

# shellcheck source=../lib/bind/main.sh
source "$JANUS_ROOT_DIR/lib/bind/main.sh"

janus_bind_main "$@"
