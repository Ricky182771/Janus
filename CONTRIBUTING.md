# Contributing to Janus

Janus is currently a pre-alpha project focused on safe VFIO/KVM tooling and modular foundations.

This guide defines the minimum quality and consistency bar for contributions.

## Core Principles

Every contribution should preserve these principles:

- **Modularity**: isolate responsibilities; avoid monolithic scripts.
- **Transparency**: log intent and outcomes clearly.
- **Determinism**: repeated runs should produce predictable results.
- **Safety-first defaults**: prefer dry-run/read-only behavior where possible.

## Where To Start

Current contribution-friendly areas:

- GPU module implementations under `modules/gpu/`
- CPU topology/pinning modules under `modules/cpu/`
- VM template and definition workflows under `templates/libvirt/` and `bin/janus-vm.sh`
- Additional shared helpers under `lib/`
- Diagnostic coverage and edge-case handling in `bin/`
- Documentation and tested usage examples

## Contracts You Must Follow

Before coding, read:

- `modules/README.md` (module lifecycle contract)
- `lib/README.md` (shared library and logging contract)

### Module contract

Each module must implement:

- `check_capability`
- `apply_config`
- `rollback`

Use `modules/gpu/template.sh` as baseline.

### Logging contract

Operational logs should use `lib/janus-log.sh` (`janus_log` and wrappers), not ad-hoc `echo` for critical actions.

## Coding Standards

- Bash scripts should be explicit and fail safely.
- Validate required commands/files before critical actions.
- Prefer clear error paths over silent partial behavior.
- Keep comments focused on **why** a block exists.
- Preserve non-destructive defaults unless explicitly required otherwise.

## Local Validation Before PR

Run these checks before opening a pull request:

```bash
bash tests/smoke.sh
for f in bin/*.sh lib/*.sh modules/gpu/template.sh tests/smoke.sh; do
  bash -n "$f"
done
bash bin/janus-vm.sh --help
```

## Pull Request Expectations

A strong PR includes:

1. A clear problem statement.
2. Scope boundaries (what changed / what did not).
3. Risk notes for behavior or safety changes.
4. Updated docs if contracts or workflows changed.
5. Validation evidence (commands and outcomes).

## Bug Reports

When opening an issue, include:

- distribution and kernel version;
- CPU/GPU information;
- command invoked and full output;
- relevant Janus logs:
  - `~/.cache/janus/last_check_*.log`
  - `~/.cache/janus/logs/janus-bind_*.log`
  - fallback path in restricted environments: `/tmp/janus/`.

## Code of Conduct

Keep feedback technical, specific, and respectful. Focus criticism on behavior and implementation details, not people.
