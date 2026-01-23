🤝 Contributing to Janus Project

Welcome to the Legion! If you're here, you share the vision of a Linux desktop without software compatibility limitations. Janus is an ambitious, modular project, and your help is essential to make it work on every imaginable hardware combination.

To maintain the technical stability and transparency promised in our manifesto, we ask all contributors to follow these guidelines.

💎 Our Philosophy: "The Glass Box"  
Every contribution to Janus must respect these three pillars:  
- **Modularity**: Don't write monolithic functions. Create small modules that do one thing well.  
- **Transparency**: The user must know exactly what's happening. Every system change must be preceded by validation and followed by clear logging.  
- **Determinism**: If a script runs twice, the result must be the same (idempotency). We must not break the system on re-execution.

🛠️ Areas Where You Can Help

| Area                  | Description                                                                 | Languages       |
|-----------------------|-----------------------------------------------------------------------------|-----------------|
| GPU Modules           | Isolation logic (VFIO) for specific models (NVIDIA, AMD, Intel)             | Bash, XML       |
| CPU Modules           | Topology optimization, core pinning, power management                       | Bash            |
| The Bridge (Agent)    | Development of the agent living inside Windows to execute .exe files        | Python, PowerShell |
| Interface (UI/UX)     | Visual integration with KDE Plasma (notifications, dialogs, widgets)        | QML, Bash       |
| Documentation         | Verified hardware guides and BIOS tutorials                                 | Markdown        |

📜 Code Standards

1. Module Structure  
   If adding support for a new GPU, place the file in `modules/gpu/` and follow this structure:  
   - `check_capability()`: Validates if the hardware is present  
   - `apply_config()`: Applies changes (e.g., XML patches)  
   - `rollback()`: **Mandatory** function to revert changes on error

2. Bash Style  
   - Use clear, UPPERCASE variable names for configurations (e.g., `GPU_ID`)  
   - Always use the project logging function: `janus_log "Message"` instead of `echo`  
   - Comment complex sections explaining **why**, not just **what**

🚀 Pull Request (PR) Process  
- Fork the repository and create your branch from main (e.g., `feature/nvidia-3000-support`)  
- Test your change: If it touches GRUB or libvirt, test on real hardware or a controlled environment  
- Document: If you add a new variable to `janus.conf`, update the example file  
- Submit the PR: Clearly describe what problem it solves or what hardware it supports

⚠️ Bug Reports (Issues)  
When reporting a bug, please include:  
- Your distribution (e.g., Fedora 41 KDE)  
- Your hardware (CPU and detected GPUs)  
- Janus log located at `~/.cache/janus/last_run.log`

🏛️ Code of Conduct  
In Janus, we value technical rigor and mutual respect. We are a community of enthusiasts helping other enthusiasts. Criticism must be constructive and code-focused.

Thank you for helping us tear down the borders between Windows and Linux!
