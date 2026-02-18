 Contributing to Janus Project

Welcome to the Legion! If you're here, you share the vision of a Linux desktop without software compatibility limitations. Janus is an ambitious, modular project, and your help is essential to make it work on every imaginable hardware combination.

To maintain the technical stability and transparency promised in our manifesto, we ask all contributors to follow these guidelines.

 Our Philosophy: "The Glass Box"  
Every contribution to Janus must respect these three pillars:  
- **Modularity**: Don't write monolithic functions. Create small modules that do one thing well.  
- **Transparency**: The user must know exactly what's happening. Every system change must be preceded by validation and followed by clear logging.  
- **Determinism**: If a script runs twice, the result must be the same (idempotency). We must not break the system on re-execution.

 Areas Where You Can Help

| Area                  | Description                                                                 | Languages       |
|-----------------------|-----------------------------------------------------------------------------|-----------------|
| GPU Modules           | Isolation logic (VFIO) for specific models (NVIDIA, AMD, Intel)             | Bash, XML       |
| CPU Modules           | Topology optimization, core pinning, power management                       | Bash            |
| The Bridge (Agent)    | Development of the agent living inside Windows to execute .exe files        | Python, PowerShell |
| Interface (UI/UX)     | Visual integration with KDE Plasma (notifications, dialogs, widgets)        | QML, Bash       |
| Documentation         | Verified hardware guides and BIOS tutorials                                 | Markdown        |

 Code Standards

1. Module Structure  
   If adding support for a new GPU, place the file in `modules/gpu/` and follow this structure:  
   - `check_capability()`: Validates if the hardware is present  
   - `apply_config()`: Applies changes (e.g., XML patches)  
   - `rollback()`: **Mandatory** function to revert changes on error
   - Start from `modules/gpu/template.sh` and keep the flow idempotent.

2. Bash Style  
   - Use clear, UPPERCASE variable names for configurations (e.g., `GPU_ID`)  
   - Use shared logger from `lib/janus-log.sh` (`janus_log LEVEL "Message"`) instead of raw `echo` for operational logs  
   - Comment complex sections explaining **why**, not just **what**

3. Local Validation
   - Run syntax checks and smoke tests before opening a PR:
   - `bash tests/smoke.sh`

 Pull Request (PR) Process  
- Fork the repository and create your branch from main (e.g., `feature/nvidia-3000-support`)  
- Test your change: If it touches GRUB or libvirt, test on real hardware or a controlled environment  
- Document: If you add a new variable to `janus.conf`, update the example file  
- Submit the PR: Clearly describe what problem it solves or what hardware it supports

 Bug Reports (Issues)  
When reporting a bug, please include:  
- Your distribution (e.g., Fedora 41 KDE)  
- Your hardware (CPU and detected GPUs)  
- Janus log located at `~/.cache/janus/last_check_*.log` (or `/tmp/janus/` fallback in restricted environments)

 Code of Conduct  
In Janus, we value technical rigor and mutual respect. We are a community of enthusiasts helping other enthusiasts. Criticism must be constructive and code-focused.

Thank you for helping us tear down the borders between Windows and Linux!
