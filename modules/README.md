# Janus Modules Architecture Guide

## Purpose

The `modules/` tree contains hardware-focused building blocks used by Janus orchestration flows.

Modules are expected to be:

- deterministic (`same input -> same result`);
- idempotent (`safe on re-run`);
- transparent (clear logs, explicit failures);
- rollback-capable when they modify runtime state.

## Contract Source Of Truth

Formal module contract is defined in `docs/module-api.md` (Module API v1).

This file focuses on architecture and contributor workflow around that contract.

## Directory Strategy

Current structure:

- `modules/gpu/`: GPU/VFIO-related module implementations.
- `modules/cpu/`: CPU topology, affinity, and isolation modules.

Growth path:

- Add vendor or generation-specific modules under the domain folder.
- Keep each module responsible for one coherent capability.
- Prefer small composable modules over monolithic scripts.

## Module API v1 At A Glance

Every module must define metadata variables:

- `JANUS_MODULE_TYPE`
- `JANUS_MODULE_ID`
- `JANUS_MODULE_VERSION`
- `JANUS_MODULE_COMPAT_API`

Every module must implement these lifecycle functions:

1. `janus_module_check`
2. `janus_module_apply`
3. `janus_module_rollback`

Legacy aliases are still accepted for backward compatibility:

- `check_capability`
- `apply_config`
- `rollback`

## Execution Modes

Janus supports a hybrid execution strategy through `lib/modules/main.sh`:

- `source` mode (`JANUS_MODULE_EXEC_MODE=source`):
  - loads module as a library;
  - enables deep integration with orchestrator context.
- `subshell` mode (`JANUS_MODULE_EXEC_MODE=subshell`):
  - executes module action in a separate process;
  - provides stronger isolation from caller state.

Use `subshell` mode for untrusted/community modules when isolation is preferred.

## Execution Semantics

Recommended return code policy:

- `0`: success
- `1`: expected validation/configuration failure
- `2+`: unexpected/internal failure

Runtime guarantees:

- Re-running `janus_module_check` should not change machine state.
- Re-running `janus_module_apply` should not duplicate persistent side effects.
- `janus_module_rollback` should be best-effort but explicit about incomplete restores.

## Observability / Logging Requirements

Modules must use shared logging from `lib/janus-log.sh`.

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/janus-log.sh"
janus_log INFO "[module-name] message"
```

Minimum logging expectations:

- start/end of each lifecycle function;
- critical external command execution;
- user-actionable warnings;
- rollback outcomes.

## State Handling Recommendations

When a module needs state persistence:

- Store runtime state under `~/.config/janus/state/` or a subdirectory.
- Use module-scoped filenames, for example: `gpu_nvidia_bind.state`.
- Write machine-readable key/value lines for easy parsing.
- Avoid storing secrets in plain text.

## Failure-Mode Policy

Fail fast when:

- required kernel/sysfs interfaces are missing;
- target hardware identity is invalid;
- a critical bind/unbind/write operation fails.

Warn and continue when:

- optional tooling is absent but core path still works;
- informational probes fail without blocking safe operation.

## Template Walkthrough

Use `modules/gpu/template.sh` as the baseline implementation.

- `check` command -> `janus_module_check`
- `apply` command -> `janus_module_apply`
- `rollback` command -> `janus_module_rollback`
- `meta` command -> machine-readable metadata

Command examples:

```bash
bash modules/gpu/template.sh check
bash modules/gpu/template.sh apply
bash modules/gpu/template.sh rollback
bash modules/gpu/template.sh meta
```

Library mode examples:

```bash
source lib/modules/main.sh
janus_module_run_action modules/gpu/template.sh check
janus_modules_discover
```

## Module Quality Checklist

Before proposing a module:

1. Declares all required metadata fields.
2. Implements all three `janus_module_*` lifecycle functions.
3. Uses `lib/janus-log.sh` for operational logs.
4. Has explicit validation for required commands/files/interfaces.
5. Has deterministic behavior on repeated runs.
6. Supports rollback for all `janus_module_apply` side effects.
7. Passes repository smoke validation (`bash tests/smoke.sh`).
