# Janus Project: The Two-Faced Orchestrator
Janus: Seamless hybrid Linux-Windows orchestrator. VFIO + Looking Glass + Ghost Shell mode for running Windows applications natively on Fedora KDE with full integration and brutal performance. Community-driven project in early blueprint stage.

> "Uniting the sovereignty of Linux with the raw power of Windows under a single deterministic architecture."

Janus is a modular orchestration framework designed for high-performance hybrid systems. Its main goal is to eliminate technical friction between Fedora KDE and Windows, turning hardware into a dynamic, shared resource instead of an operational barrier.

 Project Vision  
In Roman mythology, Janus is the god of beginnings, transitions, and dualities—depicted with two faces looking to the past and the future. This project embraces that philosophy: one face rests on the stability and privacy of Linux, while the other faces the raw performance and compatibility of Windows.

Janus is not just an automation script; it's a true "Glass Box" technology: it automates complex processes (VFIO, core isolation, memory management) while maintaining total transparency and absolute user control.

 Core Objectives

| Objective                  | Description                                                                 |
|----------------------------|-----------------------------------------------------------------------------|
| Modular Abstraction        | Plugin-based architecture supporting diverse CPU (Intel/AMD) and GPU (NVIDIA/AMD/Intel) topologies. |
| Seamless Integration       | Run .exe binaries via "The Bridge" with a simple double-click from the native desktop. |
| Resource Efficiency        | "Ghost Shell" mode that eliminates Windows graphical environment for maximum performance in games and professional applications. |
| Deterministic Stability    | Installation and update processes with pre-validation and full rollback capability. |
| Data Sovereignty           | Secure hybrid Dual-Boot management, protecting physical disk integrity with automated mount locks. |

 Technical Architecture  
Janus operates through a decoupled structure, ensuring distro-agnostic behavior and resistance to kernel updates.

1. The Orchestrator (Core)  
   Main engine managing the VM lifecycle, loading hardware-specific modules. Built on libvirt and QEMU, optimized for ultra-low latency.

2. The Bridge (EXE Bridge)  
   Integration system associating Windows files on the host. When executing a .exe, Janus:  
   - Checks VM status  
   - Injects command via qemu-guest-agent  
   - Displays the application via Looking Glass with single-frame latency

3. User Experience Modes  
   - Immersive Mode: Full Windows desktop for traditional workflows  
   - Transparent Mode: Suppresses explorer.exe and unnecessary services. Windows apps appear as independent windows on the Fedora desktop.

 Resilience and Security  
To provide peace of mind for enthusiasts, Janus includes active safety protocols:  
- Pre-Flight Checks: Validates IOMMU capabilities and CPU topology before any persistent changes  
- Safety Hooks: Prevents VM boot if physical Windows partitions are mounted on the host, eliminating data corruption risk  
- Rescue Mode (--rescue): Emergency command to restore native Windows shell and full desktop from Linux terminal

 Community Collaboration  
Janus is a community project by definition. Its modularity allows developers and enthusiasts to contribute support for exotic hardware, network optimizations, or integration with other desktop environments (GNOME, XFCE).

> We are looking for: Bash/Python developers, VFIO experts, and users willing to test system robustness across configurations.

 Project Status: Phase 1 (Blueprint)  
Currently in architectural design and base module development.  
- [x] Manifesto and Objectives definition  
- [ ] Universal Diagnostic Module (janus-check)  
- [ ] Boot Orchestrator and Kernel Parameter Management  
- [ ] Implementation of "The Bridge" for file integration

How to get started? 🗿  
If this project resonates with your vision of computing, check our contribution guide and join the legion working to end the friction between operating systems.

Licensed under the GNU General Public License v3.0 (or later). See [LICENSE](LICENSE) for details.
