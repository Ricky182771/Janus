# Janus Project: The Two-Faced Orchestrator

Janus is a Linux-host orchestration toolkit for VFIO-oriented hybrid workflows.

Current focus (pre-alpha):

- host diagnostics for VFIO/KVM prerequisites;
- safe, explicit initialization of local Janus state;
- dry-run-first PCI binding workflow for vfio-pci;
- modular architecture scaffolding for future CPU/GPU modules.

## Vision

Janus aims to reduce friction between Linux sovereignty and Windows compatibility/performance by building transparent automation around virtualization primitives.

The project follows a "glass box" philosophy:

- each critical action is explicit;
- non-destructive paths are available by default;
- rollback paths are first-class where applicable.

## What Exists Today

Implemented commands:

- `bin/janus-check.sh`: diagnostic checks for CPU virtualization, IOMMU, tooling, modules, hugepages, and GPU/IOMMU visibility.
- `bin/janus-init.sh`: initializes Janus user config/state under `~/.config/janus` and cache/log paths.
- `bin/janus-bind.sh`: lists devices, validates targets, runs dry-run summaries, and supports explicit apply/rollback flows.

Implemented architecture scaffolding:

- `lib/janus-log.sh`: shared logging contract.
- `modules/gpu/template.sh`: baseline module lifecycle template.
- `modules/README.md`: module lifecycle and quality contract.
- `tests/smoke.sh`: non-destructive smoke checks.

## What Is Not Implemented Yet

Still in roadmap:

- full orchestrator command (`bin/janus`);
- VM lifecycle automation and profile orchestration;
- Windows guest bridge agent and desktop integration layer;
- libvirt XML templates and guest-side script bundles.

## Repository Map

```text
bin/                User-facing commands (check/init/bind)
lib/                Shared script libraries (logging contract)
modules/            Hardware/module scaffolding and templates
tests/              Smoke validation scripts
README.md           Project overview and current scope
CONTRIBUTING.md     Contributor workflow and quality gates
```

## Project Status

Phase: **Pre-alpha / Blueprint + Core Tooling**

Progress snapshot:

- [x] Manifesto and objectives
- [x] Diagnostic module (`janus-check`)
- [x] Initialization workflow (`janus-init`)
- [x] Safe VFIO bind workflow (`janus-bind`)
- [x] Module scaffolding (`lib/`, `modules/`)
- [ ] Core orchestrator (`bin/janus`)
- [ ] Guest bridge implementation
- [ ] VM template generation and lifecycle integration

## Non-Destructive Quickstart

```bash
cd /path/to/Janus

# Run smoke checks in temporary HOME
bash tests/smoke.sh

# Manual non-destructive diagnostics
export HOME=/tmp/janus-lab
mkdir -p "$HOME"

bash bin/janus-check.sh --no-interactive
bash bin/janus-bind.sh --list
bash bin/janus-bind.sh --device 0000:03:00.0 --dry-run --yes
```

Notes:

- `janus-bind` defaults to dry-run.
- `--apply` requires explicit opt-in and root privileges.
- Running with temporary `HOME` isolates Janus state from your real profile.

## Documentation Entry Points

- Module architecture: `modules/README.md`
- Shared library contract: `lib/README.md`
- Contribution process: `CONTRIBUTING.md`

## License

Licensed under the GNU General Public License v3.0 (or later). See `LICENSE` for details.
