# Janus `tests/` Directory

This directory contains repository-level validation scripts.

## Current test scripts

- `smoke.sh`: non-destructive smoke checks for CLI behavior, syntax validation, error paths, and VM XML generation defaults.

## Test philosophy

- fast and safe to run on a regular workstation;
- no destructive host changes;
- focused on catching regressions in command contracts and generated artifacts.

## Run

```bash
bash tests/smoke.sh
```
