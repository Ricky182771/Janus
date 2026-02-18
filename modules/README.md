# Janus Modules Architecture Guide

## Purpose

The `modules/` tree contains hardware-focused building blocks used by Janus orchestration flows.

Modules are expected to be:

- deterministic (`same input -> same result`);
- idempotent (`safe on re-run`);
- transparent (clear logs, explicit failures);
- rollback-capable when they modify runtime state.

## Directory Strategy

Current structure:

- `modules/gpu/`: GPU/VFIO-related module implementations.
- `modules/cpu/`: CPU topology, affinity, and isolation modules.

Growth path:

- Add vendor or generation-specific modules under the domain folder.
- Keep each module responsible for one coherent capability.
- Prefer small composable modules over monolithic scripts.

## Module Lifecycle Contract

Every module must implement these entrypoints:

1. `check_capability`
2. `apply_config`
3. `rollback`

### `check_capability`

- Validates whether the host/hardware matches module assumptions.
- Must not mutate system state.
- Returns `0` if compatible, non-zero if incompatible.

### `apply_config`

- Applies module-specific runtime configuration.
- Must log intent and outcome for each critical step.
- Should fail fast on critical errors.

### `rollback`

- Reverts side effects produced by `apply_config`.
- Must be safe to run even after partial apply failures.
- Should log what was restored and what could not be restored.

## Execution Semantics

Recommended return code policy:

- `0`: success
- `1`: expected validation/configuration failure
- `2+`: unexpected/internal failure

Runtime guarantees:

- Re-running `check_capability` should not change machine state.
- Re-running `apply_config` should not duplicate persistent side effects.
- `rollback` should be best-effort but explicit about incomplete restores.

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

- `check` command -> `check_capability`
- `apply` command -> `apply_config`
- `rollback` command -> `rollback`

Command examples:

```bash
bash modules/gpu/template.sh check
bash modules/gpu/template.sh apply
bash modules/gpu/template.sh rollback
```

## Module Quality Checklist

Before proposing a module:

1. Implements all three lifecycle functions.
2. Uses `lib/janus-log.sh` for operational logs.
3. Has explicit validation for required commands/files/interfaces.
4. Has deterministic behavior on repeated runs.
5. Supports rollback for all `apply_config` side effects.
6. Passes repository smoke validation (`bash tests/smoke.sh`).
