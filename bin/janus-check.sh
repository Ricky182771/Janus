#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Check Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/check/.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/check/main.sh
source "$JANUS_ROOT_DIR/lib/check/main.sh"

janus_check_main "$@"
