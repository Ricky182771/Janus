# Janus `lib/` Architecture Guide

## Purpose

The `lib/` directory is the shared runtime layer for Janus shell tools.  
Its goal is to centralize cross-cutting concerns (logging, reusable checks, parsing helpers) so scripts in `bin/` and modules in `modules/` stay small and deterministic.

In the current phase, `lib/` provides a single library:

- `janus-log.sh`: standard logging contract for scripts and modules.

## Design Rationale

Janus favors transparent and idempotent orchestration. Shared libraries in `lib/` exist to:

- avoid copy/paste utility logic between scripts;
- keep output format stable across commands;
- make future module behavior observable and debuggable.

## Loading Model

`janus-log.sh` uses a guard variable:

- `JANUS_LOG_LIB_LOADED`

This prevents duplicate function redefinitions when the library is sourced more than once in a process.

Example:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/janus-log.sh"
```

## Logging API Contract

Primary API:

- `janus_log LEVEL "message"`

Helper wrappers:

- `janus_log_info`
- `janus_log_ok`
- `janus_log_warn`
- `janus_log_error`
- `janus_log_critical`
- `janus_log_debug`

Supported levels:

- `INFO`, `OK`, `WARN`, `ERROR`, `CRITICAL`, `DEBUG`

Color behavior:

- Colors are enabled by default.
- Color mapping is handled by `janus_log_color`.
- Output format with color: `[LEVEL] message`.

## Environment Knobs

The logger currently supports:

- `JANUS_LOG_ENABLE_COLOR` (default: `1`)
  - `1`: colored output
  - `0`: plain text output

Example:

```bash
JANUS_LOG_ENABLE_COLOR=0 bash bin/janus-check.sh --version
```

## Usage Patterns

### From `bin/` scripts

```bash
source "$SCRIPT_DIR/../lib/janus-log.sh"
janus_log INFO "Running diagnostics"
```

### From `modules/`

```bash
source "$SCRIPT_DIR/../../lib/janus-log.sh"
janus_log WARN "Module entered degraded mode"
```

## Conventions For New Libraries

When adding files under `lib/`:

1. Use `set -u` safe code (no implicit globals).
2. Export only intentional function names.
3. Add a load guard variable (`*_LIB_LOADED`).
4. Keep side effects minimal (no automatic system mutation on source).
5. Document every public function in this README or a sibling doc.

## Backward Compatibility

The `janus_log` API is treated as a compatibility contract for Janus scripts and modules in this phase.

- New helper functions may be added.
- Existing function names and basic output shape should remain stable.
- Breaking changes should be documented in `README.md` and `CONTRIBUTING.md`.

## Extension Guidelines

Recommended near-term additions to `lib/`:

- command/dependency helpers;
- argument parsing helpers;
- shared filesystem/state path helpers.

Each new helper should include:

- clear function contract;
- failure semantics (return code vs hard exit);
- at least one usage example.
