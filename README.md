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
- `bin/janus-vm.sh`: creates VM definitions from templates and manages VM lifecycle (`create/start/stop/status`).

Implemented architecture scaffolding:

- `lib/core/runtime/`: shared runtime helpers (paths, logging, prompts, root-gating).
- `lib/check/`, `lib/init/`, `lib/bind/`, `lib/vm/`: modular command implementations grouped by function category.
- `lib/janus-log.sh`: compatibility entrypoint for shared logging API.
- `templates/libvirt/windows-base.xml`: baseline Windows VM template with injectable blocks for ISO, display stack, and GPU passthrough hostdev entries.
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
bin/                Thin user-facing wrappers (delegate to lib/)
lib/core/runtime/   Shared runtime/logging/safety helpers
lib/check/          Modular janus-check implementation
lib/init/           Modular janus-init implementation
lib/bind/           Modular janus-bind implementation
lib/vm/             Modular janus-vm implementation
lib/janus-log.sh    Backward-compatible logging entrypoint
templates/libvirt/  Libvirt XML templates (single base + injected blocks)
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
- [x] VM helper command and templates (`janus-vm`, `templates/libvirt/`)
- [x] Module scaffolding (`lib/`, `modules/`)
- [ ] Core orchestrator (`bin/janus`)
- [ ] Guest bridge implementation
- [ ] End-to-end VM profile lifecycle automation

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
bash bin/janus-vm.sh create --name win11 --guided
bash bin/janus-vm.sh create --name win11 --mode passthrough --gpu 0000:03:00.0 --gpu-audio 0000:03:00.1 --yes --no-guided
```

Notes:

- `janus-bind` defaults to dry-run.
- `--apply` requires explicit opt-in and root privileges.
- Running with temporary `HOME` isolates Janus state from your real profile.
- Runtime logs are written to both command logs and `~/.cache/janus/logs/janus.log` (fallback: `/tmp/janus/logs/janus.log`).
- Thin wrappers in `bin/` perform early root gating for mutating flows (`--apply`, `--rollback`, `--force`).
- VM templates enable anti-detection defaults for guests (KVM hidden state + CPU `hypervisor` bit disabled).
- `janus-vm create` runs guided by default when an interactive TTY is present.

## GPU Passthrough VM Flow (QEMU + virt-manager)

```bash
# 1) Define VM from Janus template (and persist disk/NVRAM + libvirt define)
bash bin/janus-vm.sh create \
  --name win11-gpu \
  --mode passthrough \
  --gpu 0000:03:00.0 \
  --gpu-audio 0000:03:00.1 \
  --iso /var/lib/libvirt/boot/win11.iso \
  --apply --yes

# 2) Open VM in virt-manager for install/runtime management
virt-manager --connect qemu:///system
```

The generated libvirt XML keeps VM-stealth defaults enabled by default for Windows guests.

## Guided Creation Flow

`janus-vm create --guided` now drives the full VM setup in 3 steps:

1. ISO selection (installation media path).
2. VM resources:
   - RAM + CPU cores.
   - Video profile:
     - Passthrough (isolated secondary GPU), or
     - Single-GPU with `shared-vram`, or
     - Single-GPU `cpu-only` (no 3D acceleration).
   - Storage backend:
     - `file` (creates/uses QCOW2), or
     - `block` (raw partition/real disk in `/dev/...`).
3. Optional unattended Windows local account setup (`Autounattend.xml` + attached ISO).

## Documentation Entry Points

- Module architecture: `modules/README.md`
- Shared library contract: `lib/README.md`
- Contribution process: `CONTRIBUTING.md`

## License

Licensed under the GNU General Public License v3.0 (or later). See `LICENSE` for details.
