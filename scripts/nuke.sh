#!/usr/bin/env bash
# nuke.sh — remove packages not in current Ansible vars, then re-apply.
#
# Compares pacman's explicitly-installed list against every *_packages var
# across all roles. Anything installed but no longer managed gets removed,
# then the system playbook re-runs to restore the desired state.
#
# Usage:
#   ./scripts/nuke.sh [-l PROFILE] [--dry-run]
#
# Options:
#   -l PROFILE   Ansible limit (home_desktop | work_laptop | minimal).
#                Defaults to auto-detect from current hostname.
#   --dry-run    Show what would be removed; do not change anything.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLES_DIR="$REPO_ROOT/system/roles"
GROUP_VARS="$REPO_ROOT/system/inventory/group_vars"
HOSTS_YML="$REPO_ROOT/system/inventory/hosts.yml"

# ── argument parsing ──────────────────────────────────────────────────────────
PROFILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l) PROFILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── sanity checks ─────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: nuke.sh must run on the target Arch Linux system." >&2
  exit 1
fi

if ! command -v pacman &>/dev/null; then
  echo "Error: pacman not found." >&2
  exit 1
fi

if ! python3 -c "import yaml" &>/dev/null; then
  echo "Error: python-yaml required. Install with: pacman -S python-yaml" >&2
  exit 1
fi

# ── auto-detect profile ───────────────────────────────────────────────────────
if [[ -z "$PROFILE" ]]; then
  HOST=$(hostname)
  if grep -q "home_desktop" "$HOSTS_YML" 2>/dev/null; then
    PROFILE=$(grep -oP '(?<=ansible_host: ).*' "$HOSTS_YML" 2>/dev/null | head -1 || true)
  fi
  # Simple fallback: prompt
  if [[ -z "$PROFILE" ]]; then
    echo "Select profile:"
    echo "  1) home_desktop"
    echo "  2) work_laptop"
    echo "  3) minimal"
    read -rp "Choice [1-3]: " choice
    case "$choice" in
      1) PROFILE="home_desktop" ;;
      2) PROFILE="work_laptop" ;;
      3) PROFILE="minimal" ;;
      *) echo "Invalid choice." >&2; exit 1 ;;
    esac
  fi
fi

echo "Profile : $PROFILE"
echo "Dry run : $DRY_RUN"
echo ""

# ── build managed package set from all role vars ──────────────────────────────
echo "Parsing Ansible vars..."

MANAGED=$(python3 - "$ROLES_DIR" <<'PYEOF'
import sys
from pathlib import Path
import yaml

roles_dir = Path(sys.argv[1])
managed = set()

for vars_file in sorted(roles_dir.glob("*/vars/main.yml")):
    with vars_file.open() as f:
        data = yaml.safe_load(f) or {}
    for key, value in data.items():
        # power_management_packages is a dict of lists — include all options
        if key == "power_management_packages" and isinstance(value, dict):
            for pkgs in value.values():
                if isinstance(pkgs, list):
                    managed.update(str(p) for p in pkgs if p)
        # *_packages lists are pacman or AUR packages
        elif key.endswith("_packages") and isinstance(value, list):
            managed.update(str(p) for p in value if p)

# Flatpak app IDs contain dots and aren't pacman packages — remove them
managed = {p for p in managed if "." not in p}

print("\n".join(sorted(managed)))
PYEOF
)

# Add the AUR helper (bootstrapped inline, not in a vars list)
AUR_HELPER=$(python3 -c "
import yaml, sys
with open('$GROUP_VARS/all.yml') as f:
    d = yaml.safe_load(f)
print(d.get('aur_helper', 'yay'))
")
MANAGED="${MANAGED}"$'\n'"${AUR_HELPER}"

# ── diff against explicitly installed packages ────────────────────────────────
INSTALLED=$(pacman -Qqe | sort)
TO_REMOVE=$(comm -23 \
  <(echo "$INSTALLED" | sort) \
  <(echo "$MANAGED"   | sort | grep -v "^$") \
  || true)

if [[ -z "$TO_REMOVE" ]]; then
  echo "No drift detected — all explicitly installed packages match current Ansible vars."
  exit 0
fi

COUNT=$(echo "$TO_REMOVE" | grep -c "." || true)
echo "Found $COUNT package(s) not in current Ansible vars:"
echo ""
echo "$TO_REMOVE" | sed 's/^/  /'
echo ""

if $DRY_RUN; then
  echo "Dry run — no changes made."
  exit 0
fi

# ── confirm removal ───────────────────────────────────────────────────────────
read -rp "Remove these $COUNT package(s)? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

# Save the list before removing (useful if something goes wrong)
BACKUP="$REPO_ROOT/.nuke-removed-$(date +%Y%m%d-%H%M%S).txt"
echo "$TO_REMOVE" > "$BACKUP"
echo "Package list saved to $BACKUP"
echo ""

# Remove packages; --nodeps avoids cascading failures for packages that
# may be partially depended on — orphan cleanup follows below.
sudo pacman -Rns --noconfirm $TO_REMOVE 2>/dev/null || \
  sudo pacman -Rn --noconfirm $TO_REMOVE || \
  echo "Warning: some packages could not be removed (may be required by others)."

# Remove any newly orphaned dependencies
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n "$ORPHANS" ]]; then
  echo ""
  echo "Removing orphaned dependencies:"
  echo "$ORPHANS" | sed 's/^/  /'
  sudo pacman -Rns --noconfirm $ORPHANS
fi

echo ""
echo "Package cleanup done."

# ── re-run Ansible playbook ───────────────────────────────────────────────────
echo ""
read -rp "Re-run Ansible playbook for '$PROFILE' now? [Y/n] " run_ansible
if [[ "${run_ansible,,}" == "n" ]]; then
  echo "Skipped. Re-run manually:"
  echo "  cd system && ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l $PROFILE --ask-become-pass"
  exit 0
fi

cd "$REPO_ROOT/system"
ansible-playbook playbooks/site.yml \
  -i inventory/hosts.yml \
  -l "$PROFILE" \
  --ask-become-pass
