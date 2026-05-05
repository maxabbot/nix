#!/usr/bin/env python3
"""
Package List Generator
======================
Parses every Ansible role's vars file and emits a complete Markdown document
covering all packages, flatpaks, and extras that the playbooks install.

Captures:
- Standard *_packages list vars (pacman + AUR)
- power_management_packages (dict-of-lists, both options shown)
- *_apps vars (flatpak apps)
- Hardcoded inline installs (flatpak itself, hardcoded flatpaks, microcode, AUR helper)

Usage:
    python list_packages.py [--output PATH]

Requirements:
    python-yaml  (pacman -S python-yaml)
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML not found. Install it with: pacman -S python-yaml", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Inline extras not captured from vars files
# Maps role name → list of (var_label, [packages], source, note)
# source: "pacman" | "aur" | "flatpak"
# ---------------------------------------------------------------------------
INLINE_EXTRAS: dict[str, list[tuple[str, list[str], str, str]]] = {
    "base": [
        (
            "microcode",
            ["amd-ucode", "intel-ucode"],
            "pacman",
            "auto-detected from CPU vendor at runtime — only one is installed",
        ),
    ],
    "aur": [
        (
            "aur_helper",
            ["yay"],
            "aur",
            "value of `aur_helper` in group_vars/all.yml — bootstrapped from git, not a list var",
        ),
    ],
    "productivity": [
        (
            "flatpak (runtime)",
            ["flatpak"],
            "pacman",
            "installed inline in tasks before any Flatpak apps",
        ),
        (
            "hardcoded_flatpak_apps",
            ["com.stremio.Stremio", "com.github.tchx84.Flatseal", "io.smarttube.app"],
            "flatpak",
            "installed inline in tasks, not in a var list",
        ),
    ],
}


def _is_aur_var(key: str) -> bool:
    return "_aur_" in key or key.endswith("_aur_packages")


def _is_flatpak_var(key: str) -> bool:
    return key.endswith("_apps")


def _load_yaml(path: Path) -> dict:
    with path.open() as fh:
        return yaml.safe_load(fh) or {}


def extract_role_data(vars_file: Path) -> dict:
    """
    Returns:
      pacman:  {var_name: [pkg, ...]}
      aur:     {var_name: [pkg, ...]}
      flatpak: {var_name: [app_id, ...]}
      power:   {option_name: [pkg, ...]}   — from power_management_packages
    """
    data = _load_yaml(vars_file)

    pacman: dict[str, list[str]] = {}
    aur: dict[str, list[str]] = {}
    flatpak: dict[str, list[str]] = {}
    power: dict[str, list[str]] = {}

    for key, value in data.items():
        if key == "power_management_packages" and isinstance(value, dict):
            for option, pkgs in value.items():
                if isinstance(pkgs, list):
                    power[option] = [str(p) for p in pkgs if p]
        elif _is_flatpak_var(key) and isinstance(value, list):
            flatpak[key] = [str(p) for p in value if p]
        elif key.endswith("_packages") and isinstance(value, list):
            bucket = aur if _is_aur_var(key) else pacman
            bucket[key] = [str(p) for p in value if p]

    return {"pacman": pacman, "aur": aur, "flatpak": flatpak, "power": power}


def _render_group(title: str, groups: dict[str, list[str]], *, empty_label: str = "_None._") -> list[str]:
    lines = [f"### {title}", ""]
    if not groups:
        lines += [empty_label, ""]
        return lines
    for var_name, packages in sorted(groups.items()):
        lines.append(f"#### `{var_name}` ({len(packages)})")
        lines.append("")
        for pkg in packages:
            lines.append(f"- `{pkg}`")
        lines.append("")
    return lines


def _render_power(power: dict[str, list[str]]) -> list[str]:
    if not power:
        return []
    lines = ["### Power management (either/or)", ""]
    lines.append("Exactly one option is installed based on the `power_management` group_var.")
    lines.append("")
    for option, pkgs in sorted(power.items()):
        lines.append(f"#### `{option}`")
        lines.append("")
        for pkg in pkgs:
            lines.append(f"- `{pkg}`")
        lines.append("")
    return lines


def _render_extras(role: str) -> tuple[list[str], int, int, int]:
    """Returns (lines, extra_pacman_count, extra_aur_count, extra_flatpak_count)."""
    extras = INLINE_EXTRAS.get(role, [])
    if not extras:
        return [], 0, 0, 0

    pacman_lines: list[str] = []
    aur_lines: list[str] = []
    flatpak_lines: list[str] = []
    ep = ea = ef = 0

    for label, pkgs, source, note in extras:
        block = [f"#### `{label}` ({len(pkgs)})"]
        if note:
            block += ["", f"_{note}_"]
        block.append("")
        for pkg in pkgs:
            block.append(f"- `{pkg}`")
        block.append("")
        if source == "aur":
            aur_lines.extend(block)
            ea += len(pkgs)
        elif source == "flatpak":
            flatpak_lines.extend(block)
            ef += len(pkgs)
        else:
            pacman_lines.extend(block)
            ep += len(pkgs)

    out: list[str] = []
    if pacman_lines:
        out += ["### Inline pacman installs", ""] + pacman_lines
    if aur_lines:
        out += ["### Inline AUR installs", ""] + aur_lines
    if flatpak_lines:
        out += ["### Inline Flatpak installs", ""] + flatpak_lines

    return out, ep, ea, ef


def render_role(role: str, role_data: dict) -> tuple[str, int, int, int]:
    pacman = role_data["pacman"]
    aur = role_data["aur"]
    flatpak = role_data["flatpak"]
    power = role_data["power"]

    pac_count = sum(len(v) for v in pacman.values())
    aur_count = sum(len(v) for v in aur.values())
    flat_count = sum(len(v) for v in flatpak.values())

    # Power packages add to pacman count (pick the larger option for the summary)
    power_count = max((sum(len(v) for v in power.values()), 0), default=0)
    if power:
        pac_count += power_count

    lines: list[str] = [f"## {role}", ""]

    lines.extend(_render_group("Pacman packages", pacman))
    lines.extend(_render_power(power))
    lines.extend(_render_group("AUR packages", aur))

    if flatpak:
        lines.extend(_render_group("Flatpak apps", flatpak))

    extra_lines, ep, ea, ef = _render_extras(role)
    lines.extend(extra_lines)

    pac_count += ep
    aur_count += ea
    flat_count += ef

    return "\n".join(lines), pac_count, aur_count, flat_count


def render_summary(rows: list[tuple[str, int, int, int]]) -> str:
    lines = [
        "## Summary",
        "",
        "| Role | Pacman | AUR | Flatpak | Total |",
        "|------|-------:|----:|--------:|------:|",
    ]
    tot_pac = tot_aur = tot_flat = 0
    for role, pac, aur, flat in rows:
        total = pac + aur + flat
        lines.append(f"| {role} | {pac} | {aur} | {flat} | {total} |")
        tot_pac += pac
        tot_aur += aur
        tot_flat += flat
    grand = tot_pac + tot_aur + tot_flat
    lines.append(f"| **Total** | **{tot_pac}** | **{tot_aur}** | **{tot_flat}** | **{grand}** |")
    lines.append("")
    return "\n".join(lines)


def build_document(roles_dir: Path) -> str:
    role_dirs = sorted(
        d for d in roles_dir.iterdir()
        if d.is_dir() and (d / "vars" / "main.yml").exists()
    )

    role_sections: list[str] = []
    summary_rows: list[tuple[str, int, int, int]] = []

    for role_dir in role_dirs:
        role_data = extract_role_data(role_dir / "vars" / "main.yml")
        has_content = any(role_data[k] for k in ("pacman", "aur", "flatpak", "power"))
        has_extras = role_dir.name in INLINE_EXTRAS
        if not has_content and not has_extras:
            continue
        section, pac, aur, flat = render_role(role_dir.name, role_data)
        role_sections.append(section)
        summary_rows.append((role_dir.name, pac, aur, flat))

    header = (
        "# Ansible Packages\n\n"
        "_Generated by `scripts/list_packages.py`. Do not edit by hand._\n"
    )
    return "\n".join([header, render_summary(summary_rows), *role_sections])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate ANSIBLE_PACKAGES.md from Ansible role vars."
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=None,
        help="Output path (default: <repo-root>/ANSIBLE_PACKAGES.md).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent.parent
    roles_dir = repo_root / "system" / "roles"

    if not roles_dir.is_dir():
        print(f"Error: roles directory not found: {roles_dir}", file=sys.stderr)
        sys.exit(1)

    output_path = args.output or (repo_root / "ANSIBLE_PACKAGES.md")
    document = build_document(roles_dir)
    output_path.write_text(document, encoding="utf-8")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
