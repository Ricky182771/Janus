# Janus `bin/` Directory

This directory contains the user-facing command entrypoints.

Each script in `bin/` is intentionally thin and delegates implementation
to modular logic under `lib/`.

## Included commands

- `janus-check.sh`: runs host diagnostics for virtualization, IOMMU, tools, and GPU grouping.
- `janus-init.sh`: initializes local Janus config/state directories and base config files.
- `janus-bind.sh`: handles VFIO bind workflows (list, dry-run, apply, rollback).
- `janus-vm.sh`: handles VM workflows (create/start/stop/status), including passthrough and guided setup.

## Notes

- Mutating flows perform explicit root checks.
- Runtime logs are written to command-specific logs and the shared `janus.log`.
