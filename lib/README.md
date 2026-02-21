# Janus `lib/` Architecture Guide

## Purpose

The `lib/` tree is the modular runtime layer for Janus shell commands.

Primary goals:

- keep `bin/*.sh` entrypoints thin;
- isolate each responsibility in small, focused scripts;
- centralize cross-cutting runtime concerns (logging, paths, root gates, prompts).

## Current Structure

```text
lib/
  core/runtime/
    paths.sh      Writable path resolution with fallback handling.
    logging.sh    Shared log API + session log routing.
    safety.sh     Interactive confirmation and root helpers.
    tty.sh        ensure_tty pseudo-TTY fallback helper.

  init/
    cli/          janus-init argument handling.
    core/         janus-init shared context/state.
    steps/        janus-init workflow steps.
    main.sh       janus-init orchestration entry.

  check/
    cli/          janus-check argument handling.
    core/         janus-check counters/state.
    probes/       diagnostics by category.
    main.sh       janus-check orchestration entry.

  bind/
    cli/          janus-bind argument handling.
    core/         bind context + low-level helpers.
    ops/          list/resolve/safety/apply operations.
    main.sh       janus-bind orchestration entry.

  vm/
    cli/          janus-vm CLI + guided wizard.
    core/         vm context/helpers/validation.
    xml/          XML block builders and renderer.
    storage/      unattended media generation.
    actions/      create/start/stop/status workflows.
    main.sh       janus-vm orchestration entry.

  modules/
    main.sh       Module API v1 loader (discover/load/run actions).

  janus-log.sh    Backward-compatible logging entrypoint.
  tty.sh          Backward-compatible shim for runtime tty helpers.
```

## Logging Contract

`lib/core/runtime/logging.sh` provides:

- standardized log API (`janus_log`, `janus_log_info`, etc.);
- per-command log files with timestamp;
- centralized append-only `janus.log`.

Default log target:

- `~/.cache/janus/logs/`

Fallback when unavailable:

- `/tmp/janus/logs/`

Each command writes to both:

- command-specific log (for traceability);
- `janus.log` (for chronological cross-command analysis).

## Runtime Safety Contract

`lib/core/runtime/safety.sh` provides:

- `janus_confirm` (safe yes/no prompts);
- `janus_require_root` (explicit privilege guard);
- `janus_has_flag` (thin wrapper-friendly flag detection).

`lib/core/runtime/tty.sh` provides:

- `ensure_tty` (executes commands directly on real TTY, or through pseudo-TTY fallback);
- `JANUS_TTY_UNAVAILABLE_RC` (return code signaling no TTY + no `script` support).

## Backward Compatibility

`lib/janus-log.sh` remains a compatibility shim so existing module code can still do:

```bash
source ".../lib/janus-log.sh"
janus_log INFO "message"
```

without knowing internal runtime path changes.

## Module Loader Contract

`lib/modules/main.sh` provides:

- API validation for `JANUS_MODULE_*` metadata and `janus_module_*` lifecycle functions;
- module discovery helpers (`janus_modules_find`, `janus_modules_discover`);
- hybrid execution (`source` or `subshell`) via `JANUS_MODULE_EXEC_MODE`.

## Design Rules

1. One file = one coherent responsibility.
2. New helpers go to `lib/core/runtime/` only when reused by multiple commands.
3. Command-specific logic belongs under `lib/<command>/`.
4. Keep public functions documented with short, direct comments in English.
5. Maintain non-destructive defaults unless explicitly in apply mode.
