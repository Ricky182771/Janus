# Janus Module API v1

## Status

- API version: `1`
- Stability: pre-alpha but treated as contract for module contributions.

## Scope

This document defines the contract for files under `modules/**/*.sh`.

A module may run in either mode:

- library mode (loaded by core with `source`);
- command mode (executed directly as `bash module.sh <action>`).

## Required Metadata

Every module must define all fields below as non-empty values:

```bash
JANUS_MODULE_TYPE="gpu"
JANUS_MODULE_ID="gpu-template"
JANUS_MODULE_VERSION="0.1.0"
JANUS_MODULE_COMPAT_API="1"
```

Rules:

- `JANUS_MODULE_ID` must be unique across repository modules.
- `JANUS_MODULE_COMPAT_API` must match the core-supported API version.
- `JANUS_MODULE_VERSION` follows semver-like format (`MAJOR.MINOR.PATCH`).

## Required Lifecycle Functions

Every module must define:

1. `janus_module_check`
2. `janus_module_apply`
3. `janus_module_rollback`

Function semantics:

- `janus_module_check`: validate capability and prerequisites without mutation.
- `janus_module_apply`: apply deterministic/idempotent configuration changes.
- `janus_module_rollback`: revert side effects from apply (best-effort but explicit).

## Return Codes

- `0`: success
- `1`: expected validation/configuration failure
- `2+`: unexpected/internal failure

## Logging Contract (Mandatory)

Modules must use shared logging:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/janus-log.sh"
janus_log INFO "[module-id] message"
```

Do not use ad-hoc `echo` for critical operational actions.

## Naming And Symbol Hygiene

- Required public function names are fixed (`janus_module_*`).
- Helper functions should use module-scoped prefixes (example: `gpu_template_*`).
- Modules should avoid setting shell options globally when sourced.

Recommended guard:

```bash
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi
```

## Command Mode Contract

When executed directly, modules should support:

- `check`
- `apply`
- `rollback`
- `meta` (prints machine-readable metadata)

Example:

```bash
bash modules/gpu/template.sh meta
```

## Backward Compatibility

Legacy function aliases are optional but recommended while migrating:

- `check_capability -> janus_module_check`
- `apply_config -> janus_module_apply`
- `rollback -> janus_module_rollback`

## Prohibitions

Modules must not:

- mutate state during `janus_module_check`;
- write outside explicit target/runtime paths without a clear reason;
- hide failures from critical operations;
- rely on interactive prompts for core flow correctness.

## Core Loader Integration

`lib/modules/main.sh` is the reference loader for discovery and execution.

Key functions:

- `janus_modules_find`
- `janus_modules_discover`
- `janus_module_load`
- `janus_module_run_action`

Execution mode is controlled via:

```bash
JANUS_MODULE_EXEC_MODE=source   # default, in-process orchestration
JANUS_MODULE_EXEC_MODE=subshell # isolated process execution
```
