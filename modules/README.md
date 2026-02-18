# Janus Modules

This directory holds hardware-specific, idempotent modules loaded by Janus.

## Layout

- `modules/gpu/`: GPU vendor/model passthrough modules.
- `modules/cpu/`: CPU topology and pinning modules.

## Module contract

Each module must implement:

1. `check_capability`: returns success if the host is compatible.
2. `apply_config`: applies module changes.
3. `rollback`: reverts anything applied by `apply_config`.

Use the shared logger from `lib/janus-log.sh`:

```bash
source "$(dirname "$0")/../../lib/janus-log.sh"
janus_log INFO "message"
```
