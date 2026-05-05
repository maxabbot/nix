#!/usr/bin/env python3
"""
Package Health Check
====================
Parses all Ansible role vars files and checks whether each declared
package is installed on the current Arch Linux system via pacman.

Usage:
    python health_check.py [--role ROLE] [--missing-only] [--no-aur] [--no-color]

Requirements:
    python-yaml  (pacman -S python-yaml)
"""

import argparse
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML not found. Install it with: pacman -S python-yaml", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------

RESET   = "\033[0m"
BOLD    = "\033[1m"
RED     = "\033[31m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
CYAN    = "\033[36m"
DIM     = "\033[2m"

def _colour_enabled(flag: bool) -> None:
    global RESET, BOLD, RED, GREEN, YELLOW, CYAN, DIM
    if not flag:
        RESET = BOLD = RED = GREEN = YELLOW = CYAN = DIM = ""

# ---------------------------------------------------------------------------
# Package-list extraction
# ---------------------------------------------------------------------------

def _is_aur_var(key: str) -> bool:
    return "_aur_" in key or key.endswith("_aur_packages")


def extract_package_lists(vars_file: Path) -> dict[str, list[str]]:
    """Return {variable_name: [package, ...]} for every *_packages list found."""
    with vars_file.open() as fh:
        data = yaml.safe_load(fh) or {}

    result: dict[str, list[str]] = {}
    for key, value in data.items():
        if key.endswith("_packages") and isinstance(value, list):
            result[key] = [str(p) for p in value if p]
    return result


# ---------------------------------------------------------------------------
# Pacman query (bulk, fast)
# ---------------------------------------------------------------------------

def installed_packages() -> set[str]:
    """Return the set of all pacman-tracked package names (pacman + AUR)."""
    try:
        out = subprocess.check_output(
            ["pacman", "-Qq"], text=True, stderr=subprocess.DEVNULL
        )
        return set(out.splitlines())
    except FileNotFoundError:
        print(
            f"{YELLOW}Warning:{RESET} pacman not found — "
            "results will show all packages as missing.",
            file=sys.stderr,
        )
        return set()
    except subprocess.CalledProcessError:
        return set()


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def print_role_report(
    role: str,
    pkg_lists: dict[str, list[str]],
    installed: set[str],
    *,
    missing_only: bool,
    skip_aur: bool,
) -> tuple[int, int]:
    """Print the report for one role. Returns (installed_count, total_count)."""
    total = ok = 0

    # Collect all output lines first so we can skip the header if nothing prints
    lines: list[str] = []
    for var_name, packages in sorted(pkg_lists.items()):
        is_aur = _is_aur_var(var_name)
        if skip_aur and is_aur:
            continue

        source_tag = f"{DIM}[AUR]{RESET}" if is_aur else f"{DIM}[pacman]{RESET}"
        var_lines: list[str] = []

        for pkg in packages:
            is_installed = pkg in installed
            total += 1
            if is_installed:
                ok += 1
            if missing_only and is_installed:
                continue
            status = f"{GREEN}✔{RESET}" if is_installed else f"{RED}✘{RESET}"
            var_lines.append(f"    {status}  {pkg}")

        if var_lines:
            lines.append(f"  {CYAN}{var_name}{RESET} {source_tag}")
            lines.extend(var_lines)

    if lines:
        print(f"\n{BOLD}{role}{RESET}")
        print("\n".join(lines))

    return ok, total


def print_summary(roles_ok: int, roles_total: int) -> None:
    missing = roles_total - roles_ok
    pct = int(roles_ok / roles_total * 100) if roles_total else 0
    colour = GREEN if missing == 0 else (YELLOW if pct >= 70 else RED)
    print(
        f"\n{BOLD}Summary:{RESET} "
        f"{colour}{roles_ok}/{roles_total}{RESET} packages installed "
        f"({colour}{pct}%{RESET})"
    )
    if missing:
        print(f"  {RED}{missing} missing{RESET}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Health-check Ansible package lists against the live system."
    )
    parser.add_argument(
        "--role", "-r",
        metavar="ROLE",
        help="Only check the specified role (e.g. base, development, gaming).",
    )
    parser.add_argument(
        "--missing-only", "-m",
        action="store_true",
        help="Only show packages that are NOT installed.",
    )
    parser.add_argument(
        "--no-aur",
        action="store_true",
        help="Skip variables marked as AUR packages.",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colour output.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    _colour_enabled(not args.no_color)

    repo_root = Path(__file__).resolve().parent.parent
    roles_dir = repo_root / "system" / "roles"

    if not roles_dir.is_dir():
        print(f"Error: roles directory not found: {roles_dir}", file=sys.stderr)
        sys.exit(1)

    # Discover role dirs
    role_dirs = sorted(
        d for d in roles_dir.iterdir()
        if d.is_dir() and (d / "vars" / "main.yml").exists()
    )
    if args.role:
        role_dirs = [d for d in role_dirs if d.name == args.role]
        if not role_dirs:
            print(f"Error: role '{args.role}' not found in {roles_dir}", file=sys.stderr)
            sys.exit(1)

    print(f"{BOLD}Querying installed packages…{RESET}")
    installed = installed_packages()

    total_ok = total_all = 0

    for role_dir in role_dirs:
        vars_file = role_dir / "vars" / "main.yml"
        pkg_lists = extract_package_lists(vars_file)
        if not pkg_lists:
            continue
        ok, total = print_role_report(
            role_dir.name,
            pkg_lists,
            installed,
            missing_only=args.missing_only,
            skip_aur=args.no_aur,
        )
        total_ok += ok
        total_all += total

    print_summary(total_ok, total_all)


if __name__ == "__main__":
    main()
