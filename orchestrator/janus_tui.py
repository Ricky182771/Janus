#!/usr/bin/env python3
"""Terminal orchestrator for Janus workflows."""

from __future__ import annotations

import argparse
import curses
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
from typing import Callable, Dict, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[1]
BIN_DIR = REPO_ROOT / "bin"
LANG_DIR = REPO_ROOT / "languages"

DEPENDENCY_COMMANDS: Tuple[str, ...] = (
    "virsh",
    "qemu-img",
    "lspci",
    "virt-manager",
)

PACKAGE_BY_MANAGER: Dict[str, Dict[str, str]] = {
    "apt": {
        "virsh": "libvirt-clients",
        "qemu-img": "qemu-utils",
        "lspci": "pciutils",
        "virt-manager": "virt-manager",
    },
    "dnf": {
        "virsh": "libvirt-client",
        "qemu-img": "qemu-img",
        "lspci": "pciutils",
        "virt-manager": "virt-manager",
    },
    "pacman": {
        "virsh": "libvirt",
        "qemu-img": "qemu-img",
        "lspci": "pciutils",
        "virt-manager": "virt-manager",
    },
    "zypper": {
        "virsh": "libvirt-client",
        "qemu-img": "qemu-tools",
        "lspci": "pciutils",
        "virt-manager": "virt-manager",
    },
}

MenuOption = Tuple[str, Callable[[], None]]


def parse_kv_file(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip().replace("\\n", "\n")
    return data


def load_languages() -> Dict[str, Dict[str, str]]:
    languages: Dict[str, Dict[str, str]] = {}
    if not LANG_DIR.is_dir():
        return languages

    for lang_file in sorted(LANG_DIR.glob("*.txt")):
        code = lang_file.stem.lower()
        parsed = parse_kv_file(lang_file)
        if parsed:
            languages[code] = parsed
    return languages


def read_os_release() -> Dict[str, str]:
    data: Dict[str, str] = {}
    path = Path("/etc/os-release")
    if not path.exists():
        return data

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"')
        data[key] = value
    return data


def detect_package_manager(os_release: Dict[str, str]) -> Optional[str]:
    distro = f"{os_release.get('ID', '')} {os_release.get('ID_LIKE', '')}".lower()

    if "debian" in distro or "ubuntu" in distro:
        return "apt" if shutil.which("apt-get") else None
    if "fedora" in distro or "rhel" in distro or "centos" in distro:
        return "dnf" if shutil.which("dnf") else None
    if "arch" in distro or "manjaro" in distro:
        return "pacman" if shutil.which("pacman") else None
    if "suse" in distro or "opensuse" in distro:
        return "zypper" if shutil.which("zypper") else None

    if shutil.which("apt-get"):
        return "apt"
    if shutil.which("dnf"):
        return "dnf"
    if shutil.which("pacman"):
        return "pacman"
    if shutil.which("zypper"):
        return "zypper"

    return None


def pick_default_language(available: Sequence[str]) -> str:
    env_lang = os.environ.get("LANG", "")
    code = env_lang.split(".", 1)[0].split("_", 1)[0].lower()
    if code in available:
        return code
    if "en" in available:
        return "en"
    return available[0] if available else "en"


class JanusTUI:
    def __init__(self, stdscr: curses.window, language: str, bundles: Dict[str, Dict[str, str]]):
        self.stdscr = stdscr
        self.language = language
        self.bundles = bundles
        self.status = ""

    def t(self, key: str, **kwargs: object) -> str:
        value = self.bundles.get(self.language, {}).get(key)
        if value is None:
            value = self.bundles.get("en", {}).get(key, key)
        try:
            return value.format(**kwargs)
        except Exception:
            return value

    def setup(self) -> None:
        curses.curs_set(0)
        self.stdscr.keypad(True)

        if curses.has_colors():
            curses.start_color()
            curses.use_default_colors()
            curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)
            curses.init_pair(2, curses.COLOR_CYAN, -1)
            curses.init_pair(3, curses.COLOR_BLACK, curses.COLOR_WHITE)
            curses.init_pair(4, curses.COLOR_YELLOW, -1)
            curses.init_pair(5, curses.COLOR_GREEN, -1)
            curses.init_pair(6, curses.COLOR_RED, -1)

        self.status = self.t("status_ready")

    def safe_addstr(self, y: int, x: int, text: str, attr: int = 0) -> None:
        height, width = self.stdscr.getmaxyx()
        if y < 0 or y >= height or x >= width:
            return
        clipped = text[: max(0, width - x - 1)]
        try:
            self.stdscr.addstr(y, x, clipped, attr)
        except curses.error:
            return

    def draw_chrome(self, title: str) -> None:
        self.stdscr.erase()
        height, width = self.stdscr.getmaxyx()

        if curses.has_colors():
            self.safe_addstr(0, 0, " " * (width - 1), curses.color_pair(1))
            self.safe_addstr(0, 2, self.t("app_title"), curses.color_pair(1) | curses.A_BOLD)
            subtitle = self.t("app_subtitle")
            self.safe_addstr(0, max(2, width - len(subtitle) - 2), subtitle, curses.color_pair(1))
            self.safe_addstr(2, 2, title, curses.color_pair(2) | curses.A_BOLD)
        else:
            self.safe_addstr(0, 2, self.t("app_title"), curses.A_BOLD)
            self.safe_addstr(2, 2, title, curses.A_BOLD)

        if self.status:
            attr = curses.color_pair(4) if curses.has_colors() else curses.A_BOLD
            self.safe_addstr(height - 2, 2, self.status, attr)

        self.safe_addstr(height - 1, 2, self.t("menu_hint"))

    def show_text(self, title: str, lines: Sequence[str]) -> None:
        offset = 0
        entries = list(lines) if lines else [""]

        while True:
            self.draw_chrome(title)
            height, width = self.stdscr.getmaxyx()
            max_lines = max(1, height - 6)

            for row in range(max_lines):
                idx = offset + row
                if idx >= len(entries):
                    break
                self.safe_addstr(4 + row, 2, entries[idx][: width - 4])

            self.stdscr.refresh()
            key = self.stdscr.getch()

            if key in (ord("q"), 27, 10, 13):
                return
            if key in (curses.KEY_DOWN, ord("j")) and offset + max_lines < len(entries):
                offset += 1
            elif key in (curses.KEY_UP, ord("k")) and offset > 0:
                offset -= 1
            elif key == curses.KEY_NPAGE:
                offset = min(max(0, len(entries) - max_lines), offset + max_lines)
            elif key == curses.KEY_PPAGE:
                offset = max(0, offset - max_lines)

    def prompt(self, text: str, default: str = "") -> str:
        while True:
            self.draw_chrome(self.t("prompt_title"))
            height, width = self.stdscr.getmaxyx()

            message = text
            if default:
                message = f"{message} [{default}]"

            self.safe_addstr(4, 2, message)
            self.safe_addstr(6, 2, "> ")
            self.stdscr.refresh()

            curses.echo()
            curses.curs_set(1)
            try:
                raw = self.stdscr.getstr(6, 4, max(1, width - 6))
            finally:
                curses.noecho()
                curses.curs_set(0)

            value = raw.decode("utf-8", errors="ignore").strip()
            if value:
                return value
            if default:
                return default
            return ""

    def confirm(self, text: str, default_yes: bool = False) -> bool:
        suffix = self.t("prompt_yes_no_default_yes") if default_yes else self.t("prompt_yes_no_default_no")
        answer = self.prompt(f"{text} {suffix}").strip().lower()

        if not answer:
            return default_yes
        return answer in ("y", "yes", "s", "si")

    def menu(self, title: str, options: Sequence[MenuOption]) -> Optional[Callable[[], None]]:
        index = 0

        while True:
            self.draw_chrome(title)
            height, _width = self.stdscr.getmaxyx()

            for i, (label, _callback) in enumerate(options):
                y = 4 + i
                if y >= height - 3:
                    break
                prefix = f"{i + 1}. "
                line = f"{prefix}{label}"
                if i == index:
                    attr = curses.color_pair(3) | curses.A_BOLD if curses.has_colors() else curses.A_REVERSE
                    self.safe_addstr(y, 2, line, attr)
                else:
                    self.safe_addstr(y, 2, line)

            self.stdscr.refresh()
            key = self.stdscr.getch()

            if key in (curses.KEY_UP, ord("k")):
                index = (index - 1) % len(options)
            elif key in (curses.KEY_DOWN, ord("j")):
                index = (index + 1) % len(options)
            elif key in (10, 13, curses.KEY_ENTER):
                return options[index][1]
            elif key in (ord("q"), 27):
                return None
            elif ord("1") <= key <= ord("9"):
                picked = key - ord("1")
                if picked < len(options):
                    return options[picked][1]

    def run_shell_command(self, cmd: Sequence[str], requires_root: bool = False, pause: bool = True) -> bool:
        final_cmd = list(cmd)

        if requires_root and os.geteuid() != 0:
            if not self.ensure_sudo():
                self.status = self.t("sudo_cancelled")
                return False
            final_cmd = ["sudo", "-n", *final_cmd]

        curses.def_prog_mode()
        curses.endwin()

        try:
            print("\n" + "=" * 72)
            print(self.t("running_command"))
            print("$", shlex.join(final_cmd))
            print("-" * 72)
            result = subprocess.run(final_cmd, cwd=str(REPO_ROOT), check=False)
            print("-" * 72)
            if result.returncode == 0:
                print(self.t("command_success"))
                self.status = self.t("status_done")
            else:
                print(self.t("command_failed", code=result.returncode))
                self.status = self.t("status_failed", code=result.returncode)

            if pause:
                try:
                    input(self.t("prompt_enter_to_continue"))
                except EOFError:
                    pass
            return result.returncode == 0
        finally:
            curses.reset_prog_mode()
            self.stdscr.refresh()
            curses.curs_set(0)

    def ensure_sudo(self) -> bool:
        if os.geteuid() == 0:
            return True

        quick = subprocess.run(
            ["sudo", "-n", "true"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if quick.returncode == 0:
            return True

        if not self.confirm(self.t("sudo_request"), default_yes=True):
            return False

        return self.run_shell_command(["sudo", "-v"], pause=False)

    def known_vm_names(self) -> List[str]:
        vm_def_dir = Path.home() / ".config" / "janus" / "vm" / "definitions"
        if not vm_def_dir.is_dir():
            return []
        names = [path.stem for path in sorted(vm_def_dir.glob("*.xml"))]
        return names

    def select_from_values(self, title: str, options: Sequence[Tuple[str, str]]) -> Optional[str]:
        index = 0

        while True:
            self.draw_chrome(title)
            height, _width = self.stdscr.getmaxyx()

            for i, (label, _value) in enumerate(options):
                y = 4 + i
                if y >= height - 3:
                    break
                line = f"{i + 1}. {label}"
                if i == index:
                    attr = curses.color_pair(3) | curses.A_BOLD if curses.has_colors() else curses.A_REVERSE
                    self.safe_addstr(y, 2, line, attr)
                else:
                    self.safe_addstr(y, 2, line)

            self.stdscr.refresh()
            key = self.stdscr.getch()

            if key in (curses.KEY_UP, ord("k")):
                index = (index - 1) % len(options)
            elif key in (curses.KEY_DOWN, ord("j")):
                index = (index + 1) % len(options)
            elif key in (10, 13, curses.KEY_ENTER):
                return options[index][1]
            elif key in (ord("q"), 27):
                return None
            elif ord("1") <= key <= ord("9"):
                picked = key - ord("1")
                if picked < len(options):
                    return options[picked][1]

    def dependency_summary(self) -> Tuple[Dict[str, str], Optional[str], List[str], List[str]]:
        os_release = read_os_release()
        manager = detect_package_manager(os_release)
        missing_commands = [cmd for cmd in DEPENDENCY_COMMANDS if shutil.which(cmd) is None]

        packages: List[str] = []
        if manager in PACKAGE_BY_MANAGER:
            pkg_map = PACKAGE_BY_MANAGER[manager]
            packages = sorted({pkg_map[cmd] for cmd in missing_commands if cmd in pkg_map})

        return os_release, manager, missing_commands, packages

    def install_dependencies(self, manager: str, packages: Sequence[str]) -> bool:
        if manager == "apt":
            steps = [
                ["apt-get", "update"],
                ["apt-get", "install", "-y", *packages],
            ]
        elif manager == "dnf":
            steps = [["dnf", "install", "-y", *packages]]
        elif manager == "pacman":
            steps = [["pacman", "-Sy", "--noconfirm", *packages]]
        elif manager == "zypper":
            steps = [["zypper", "--non-interactive", "install", *packages]]
        else:
            self.show_text(self.t("deps_title"), [self.t("deps_unsupported")])
            return False

        for step in steps:
            if not self.run_shell_command(step, requires_root=True):
                return False
        return True

    def action_guided_setup(self) -> None:
        lines = [
            self.t("guided_intro"),
            "",
            f"1. {self.t('guided_step_dependencies')}",
            f"2. {self.t('guided_step_check')}",
            f"3. {self.t('guided_step_init')}",
            f"4. {self.t('guided_step_bind_list')}",
        ]
        self.show_text(self.t("guided_title"), lines)

        self.action_dependencies()
        self.run_shell_command(["bash", str(BIN_DIR / "janus-check.sh"), "--no-interactive"])
        self.run_shell_command(["bash", str(BIN_DIR / "janus-init.sh")])

        if self.confirm(self.t("guided_step_bind_list"), default_yes=True):
            self.run_shell_command(["bash", str(BIN_DIR / "janus-bind.sh"), "--list"])

        self.status = self.t("guided_done")

    def action_dependencies(self) -> None:
        os_release, manager, missing_commands, packages = self.dependency_summary()
        distro = os_release.get("PRETTY_NAME") or os_release.get("NAME") or "unknown"

        lines = [
            self.t("deps_distro", distro=distro),
            self.t("deps_manager", manager=(manager or "unknown")),
            "",
        ]

        if not missing_commands:
            lines.append(self.t("deps_missing_none"))
            self.show_text(self.t("deps_title"), lines)
            return

        lines.append(self.t("deps_missing_header"))
        for cmd in missing_commands:
            lines.append(f"- {cmd}")

        if packages:
            lines.append("")
            lines.append("Packages:")
            for pkg in packages:
                lines.append(f"- {pkg}")

        self.show_text(self.t("deps_title"), lines)

        if not manager or not packages:
            self.show_text(self.t("deps_title"), [self.t("deps_unsupported")])
            return

        if self.confirm(self.t("deps_install_question"), default_yes=False):
            self.install_dependencies(manager, packages)

    def action_run_check(self) -> None:
        self.run_shell_command(["bash", str(BIN_DIR / "janus-check.sh")])

    def action_run_init(self) -> None:
        self.run_shell_command(["bash", str(BIN_DIR / "janus-init.sh")])

    def action_change_language(self) -> None:
        options: List[Tuple[str, str]] = []
        for code in sorted(self.bundles.keys()):
            name = self.bundles[code].get("language_name", code)
            options.append((f"{name} ({code})", code))

        picked = self.select_from_values(self.t("lang_menu_title"), options)
        if picked is None:
            return

        self.language = picked
        self.status = self.t("status_language_switched", lang=picked)

    def action_vfio_menu(self) -> None:
        while True:
            options: List[MenuOption] = [
                (self.t("vfio_menu_list_devices"), self.action_vfio_list),
                (self.t("vfio_menu_dry_run"), self.action_vfio_dry_run),
                (self.t("vfio_menu_apply"), self.action_vfio_apply),
                (self.t("vfio_menu_rollback"), self.action_vfio_rollback),
                (self.t("menu_back_generic"), lambda: None),
            ]
            picked = self.menu(self.t("vfio_menu_title"), options)
            if picked is None or picked == options[-1][1]:
                return
            picked()

    def action_vfio_list(self) -> None:
        self.run_shell_command(["bash", str(BIN_DIR / "janus-bind.sh"), "--list"])

    def action_vfio_dry_run(self) -> None:
        pci = self.prompt(self.t("vfio_input_pci"), "0000:03:00.0")
        if not pci:
            return
        self.run_shell_command(
            [
                "bash",
                str(BIN_DIR / "janus-bind.sh"),
                "--device",
                pci,
                "--dry-run",
                "--yes",
            ]
        )

    def action_vfio_apply(self) -> None:
        pci = self.prompt(self.t("vfio_input_pci"), "0000:03:00.0")
        if not pci:
            return
        if not self.confirm(self.t("vfio_confirm_apply"), default_yes=False):
            return

        self.run_shell_command(
            [
                "bash",
                str(BIN_DIR / "janus-bind.sh"),
                "--device",
                pci,
                "--apply",
                "--yes",
            ],
            requires_root=True,
        )

    def action_vfio_rollback(self) -> None:
        self.run_shell_command(
            ["bash", str(BIN_DIR / "janus-bind.sh"), "--rollback", "--yes"],
            requires_root=True,
        )

    def action_vm_menu(self) -> None:
        while True:
            options: List[MenuOption] = [
                (self.t("vm_menu_list"), self.action_vm_list),
                (self.t("vm_menu_create_guided"), self.action_vm_create_guided),
                (self.t("vm_menu_create_quick"), self.action_vm_create_quick),
                (self.t("vm_menu_start"), self.action_vm_start),
                (self.t("vm_menu_stop"), self.action_vm_stop),
                (self.t("vm_menu_status"), self.action_vm_status),
                (self.t("menu_back_generic"), lambda: None),
            ]
            picked = self.menu(self.t("vm_menu_title"), options)
            if picked is None or picked == options[-1][1]:
                return
            picked()

    def action_vm_list(self) -> None:
        self.run_shell_command(["virsh", "-c", "qemu:///system", "list", "--all"])

    def action_vm_create_guided(self) -> None:
        self.run_shell_command(["bash", str(BIN_DIR / "janus-vm.sh"), "create", "--guided"])

    def action_vm_create_quick(self) -> None:
        name = self.prompt(self.t("input_vm_name"), "janus-win11")
        if not name:
            return

        iso_path = self.prompt(self.t("input_iso_path"), "")
        memory = self.prompt(self.t("input_memory"), "16384")
        vcpus = self.prompt(self.t("input_vcpus"), "8")

        mode = self.select_from_values(
            self.t("choose_mode_title"),
            [
                (self.t("choose_mode_base"), "base"),
                (self.t("choose_mode_passthrough"), "passthrough"),
            ],
        )
        if mode is None:
            return

        storage = self.select_from_values(
            self.t("choose_storage_title"),
            [
                (self.t("choose_storage_file"), "file"),
                (self.t("choose_storage_block"), "block"),
            ],
        )
        if storage is None:
            return

        cmd: List[str] = [
            "bash",
            str(BIN_DIR / "janus-vm.sh"),
            "create",
            "--name",
            name,
            "--mode",
            mode,
            "--memory-mib",
            memory,
            "--vcpus",
            vcpus,
            "--storage",
            storage,
            "--no-guided",
            "--yes",
        ]

        if iso_path:
            cmd.extend(["--iso", iso_path])

        if mode == "base":
            single_mode = self.select_from_values(
                self.t("choose_single_gpu_title"),
                [
                    (self.t("choose_single_gpu_shared"), "shared-vram"),
                    (self.t("choose_single_gpu_cpu"), "cpu-only"),
                ],
            )
            if single_mode is None:
                return
            cmd.extend(["--single-gpu-mode", single_mode])
        else:
            gpu = self.prompt(self.t("input_gpu_pci"), "0000:03:00.0")
            gpu_audio = self.prompt(self.t("input_gpu_audio_pci"), "0000:03:00.1")
            if not gpu or not gpu_audio:
                return
            cmd.extend(["--gpu", gpu, "--gpu-audio", gpu_audio])

        if storage == "file":
            default_disk = str(Path.home() / ".local" / "share" / "janus" / "vms" / f"{name}.qcow2")
            disk_path = self.prompt(self.t("input_disk_path"), default_disk)
            disk_size = self.prompt(self.t("input_disk_size"), "120G")
            if disk_path:
                cmd.extend(["--disk-path", disk_path])
            if disk_size:
                cmd.extend(["--disk-size", disk_size])
        else:
            disk_path = self.prompt(self.t("input_disk_path"), "/dev/nvme0n1p3")
            if not disk_path:
                return
            cmd.extend(["--disk-path", disk_path])

        if self.confirm(self.t("confirm_unattended"), default_yes=False):
            win_user = self.prompt(self.t("input_win_user"), "janus")
            win_pass = self.prompt(self.t("input_win_pass_optional"), "")
            if win_user:
                cmd.extend(["--unattended", "--win-user", win_user])
                if win_pass:
                    cmd.extend(["--win-password", win_pass])

        apply_now = self.confirm(self.t("confirm_apply"), default_yes=False)
        if apply_now:
            cmd.append("--apply")

        self.run_shell_command(cmd, requires_root=apply_now)

    def ask_vm_name(self, action_key: str) -> Optional[str]:
        known = self.known_vm_names()
        default_name = known[0] if known else "janus-win11"
        name = self.prompt(self.t(action_key), default_name)
        if not name:
            return None
        return name

    def action_vm_start(self) -> None:
        name = self.ask_vm_name("vm_action_start")
        if not name:
            return
        self.run_shell_command(["bash", str(BIN_DIR / "janus-vm.sh"), "start", "--name", name])

    def action_vm_stop(self) -> None:
        name = self.ask_vm_name("vm_action_stop")
        if not name:
            return

        cmd = ["bash", str(BIN_DIR / "janus-vm.sh"), "stop", "--name", name]
        if self.confirm(self.t("confirm_force_stop"), default_yes=False):
            cmd.append("--force")
        self.run_shell_command(cmd, requires_root=("--force" in cmd))

    def action_vm_status(self) -> None:
        name = self.ask_vm_name("vm_action_status")
        if not name:
            return
        self.run_shell_command(["bash", str(BIN_DIR / "janus-vm.sh"), "status", "--name", name])

    def run(self) -> None:
        self.setup()

        while True:
            options: List[MenuOption] = [
                (self.t("main_menu_guided_setup"), self.action_guided_setup),
                (self.t("main_menu_dependencies"), self.action_dependencies),
                (self.t("main_menu_run_check"), self.action_run_check),
                (self.t("main_menu_run_init"), self.action_run_init),
                (self.t("main_menu_vfio_manager"), self.action_vfio_menu),
                (self.t("main_menu_vm_manager"), self.action_vm_menu),
                (self.t("main_menu_change_language"), self.action_change_language),
                (self.t("main_menu_exit"), lambda: None),
            ]

            picked = self.menu(self.t("main_menu_title"), options)
            if picked is None or picked == options[-1][1]:
                return
            picked()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Janus terminal orchestrator")
    parser.add_argument("--lang", default=None, help="Language code (e.g. en, es)")
    parser.add_argument("--list-languages", action="store_true", help="List available language packs")
    return parser.parse_args()


def validate_entrypoints() -> List[str]:
    expected = [
        BIN_DIR / "janus-check.sh",
        BIN_DIR / "janus-init.sh",
        BIN_DIR / "janus-bind.sh",
        BIN_DIR / "janus-vm.sh",
    ]
    missing: List[str] = []
    for path in expected:
        if not path.exists():
            missing.append(str(path))
    return missing


MIN_PYTHON = (3, 7)


def main() -> int:
    if sys.version_info < MIN_PYTHON:
        print(
            f"[ERROR] Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+ required, "
            f"found {sys.version}",
            file=sys.stderr,
        )
        return 1

    args = parse_args()

    bundles = load_languages()
    if not bundles:
        print("[ERROR] Missing language packs under ./languages/*.txt", file=sys.stderr)
        return 1

    if args.list_languages:
        for code in sorted(bundles.keys()):
            print(f"{code}\t{bundles[code].get('language_name', code)}")
        return 0

    available = sorted(bundles.keys())
    language = args.lang.lower() if args.lang else pick_default_language(available)
    if language not in bundles:
        print(f"[ERROR] Unknown language: {language}", file=sys.stderr)
        print("Available:", ", ".join(available), file=sys.stderr)
        return 1

    missing_scripts = validate_entrypoints()
    if missing_scripts:
        print("[ERROR] Required scripts are missing:", file=sys.stderr)
        for item in missing_scripts:
            print(f"  - {item}", file=sys.stderr)
        return 1

    if not sys.stdin.isatty() or not sys.stdout.isatty():
        msg = bundles.get(language, {}).get("error_no_tty") or "Interactive TTY required."
        print(f"[ERROR] {msg}", file=sys.stderr)
        return 1

    def run_curses(stdscr: curses.window) -> None:
        app = JanusTUI(stdscr, language=language, bundles=bundles)
        app.run()

    try:
        curses.wrapper(run_curses)
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
