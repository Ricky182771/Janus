#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Janus Init Command Wrapper
# ----------------------------------------------------------------------------
# This thin entrypoint delegates to modular implementation under lib/init/.
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JANUS_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/init/main.sh
source "$JANUS_ROOT_DIR/lib/init/main.sh"

janus_init_main "$@"
