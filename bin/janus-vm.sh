#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus VM Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/vm/.
# It performs early root gating for explicitly mutating operations.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core/runtime/safety.sh
source "$JANUS_ROOT_DIR/lib/core/runtime/safety.sh"

# Request root early for mutating apply/force operations.
if janus_has_flag "--apply" "$@" || janus_has_flag "--force" "$@"; then
    janus_require_root "janus-vm" || exit 1
fi

# shellcheck source=../lib/vm/main.sh
source "$JANUS_ROOT_DIR/lib/vm/main.sh"

janus_vm_main "$@"
