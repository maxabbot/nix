#!/usr/bin/env bash
# =============================================================================
# deploy.sh — nixos-anywhere wrapper with drive confirmation gate
#
# Usage:
#   ./deploy.sh <target-ip> [host]
#
# Examples:
#   ./deploy.sh 192.168.0.235
#   ./deploy.sh 192.168.0.235 home-desktop
#
# Reads the target disk from hosts/<host>/disk-config.nix, SSHes in to show
# lsblk, then requires an explicit "yes" before formatting anything.
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

log_info()    { printf "${BLUE}[INFO]${RESET}    %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}      %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET}    %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET}   %s\n" "$*" >&2; }
log_header()  { printf "\n${BOLD}${CYAN}━━━ %s ━━━${RESET}\n\n" "$*"; }

# ─── Args ─────────────────────────────────────────────────────────────────────

TARGET_IP="${1:-}"
HOST="${2:-}"

usage() {
  echo "Usage: $0 <target-ip> [host]"
  echo ""
  echo "  target-ip   IP of the NixOS live ISO (e.g. 192.168.0.235)"
  echo "  host        Flake host to deploy (default: home-desktop)"
  echo ""
  echo "Available hosts: home-desktop  work-laptop  minimal"
  exit 1
}

if [[ -z "$TARGET_IP" ]]; then
  log_error "No target IP provided."
  echo ""
  usage
fi

if [[ -z "$HOST" ]]; then
  HOST="home-desktop"
  log_info "No host specified — defaulting to ${BOLD}${HOST}${RESET}"
fi

DISK_CONFIG="${SCRIPT_DIR}/hosts/${HOST}/disk-config.nix"

if [[ ! -f "$DISK_CONFIG" ]]; then
  log_error "No disk-config.nix found at: ${DISK_CONFIG}"
  exit 1
fi

# ─── Read target disk from disk-config.nix ───────────────────────────────────

TARGET_DISK=$(grep -oP '(?<=device = ")[^"]+' "$DISK_CONFIG" | head -1)

if [[ -z "$TARGET_DISK" ]]; then
  log_error "Could not extract disk device from ${DISK_CONFIG}"
  exit 1
fi

# ─── Drive picker ────────────────────────────────────────────────────────────

log_header "Select Target Drive  (${TARGET_IP})"

echo "Fetching disks from ${BOLD}nixos@${TARGET_IP}${RESET} ..."
echo ""

# Fetch physical disks only (-d = no partitions)
RAW_DISKS=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "nixos@${TARGET_IP}" \
  "lsblk -d -o NAME,SIZE,MODEL --noheadings 2>/dev/null" 2>/dev/null) || true

if [[ -z "$RAW_DISKS" ]]; then
  log_warn "Could not reach ${TARGET_IP} — is the NixOS ISO booted and sshd running?"
  log_warn "Falling back to disk in config: ${TARGET_DISK}"
  SELECTED_DISK="$TARGET_DISK"
else
  # Build indexed arrays
  declare -a DISK_NAMES
  declare -a DISK_LABELS
  i=1
  while IFS= read -r line; do
    name=$(awk '{print $1}' <<< "$line")
    rest=$(awk '{$1=""; print $0}' <<< "$line" | xargs)
    DISK_NAMES+=("$name")
    DISK_LABELS+=("$rest")
    # Mark the one currently in disk-config.nix
    marker=""
    [[ "/dev/$name" == "$TARGET_DISK" ]] && marker=" ${YELLOW}← in config${RESET}"
    printf "  ${BOLD}%d)${RESET} /dev/%-12s %s%b\n" "$i" "$name" "$rest" "$marker"
    (( i++ ))
  done <<< "$RAW_DISKS"
  echo ""

  # Default selection — match current config
  default_idx=1
  for j in "${!DISK_NAMES[@]}"; do
    [[ "/dev/${DISK_NAMES[$j]}" == "$TARGET_DISK" ]] && default_idx=$(( j + 1 ))
  done

  read -rp "  Select drive [1-${#DISK_NAMES[@]}] (default ${default_idx}): " pick
  pick=${pick:-$default_idx}

  if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#DISK_NAMES[@]} )); then
    log_error "Invalid selection."
    exit 1
  fi

  SELECTED_DISK="/dev/${DISK_NAMES[$(( pick - 1 ))]}"
fi

# Update disk-config.nix if the selection differs from what's there
if [[ "$SELECTED_DISK" != "$TARGET_DISK" ]]; then
  log_info "Updating disk-config.nix: ${TARGET_DISK} → ${SELECTED_DISK}"
  sed -i "s|device = \"${TARGET_DISK}\"|device = \"${SELECTED_DISK}\"|" "$DISK_CONFIG"
  TARGET_DISK="$SELECTED_DISK"
fi

# ─── Final warning ────────────────────────────────────────────────────────────

echo ""
printf "${RED}${BOLD}  !! WARNING !!${RESET}\n\n"
printf "  Host   : ${BOLD}${HOST}${RESET}\n"
printf "  Target : ${BOLD}nixos@${TARGET_IP}${RESET}\n"
printf "  Disk   : ${RED}${BOLD}${TARGET_DISK}${RESET} will be completely wiped\n"
echo ""
read -rp "  Wipe ${TARGET_DISK} and install NixOS? [y/N] " confirm
echo ""

if [[ "${confirm,,}" != "y" ]]; then
  log_info "Aborted. Nothing was changed."
  exit 0
fi

# ─── Deploy ───────────────────────────────────────────────────────────────────

log_header "Deploying ${HOST} → ${TARGET_IP}"

sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/nixos-anywhere -- \
  --flake "${SCRIPT_DIR}#${HOST}" \
  --build-on remote \
  --option max-jobs 4 \
  --option cores 4 \
  "nixos@${TARGET_IP}"

log_success "nixos-anywhere completed. The machine will reboot into NixOS."
echo ""
echo "  If there is no boot entry after reboot, see:"
echo "  ${CYAN}docs/guides/nix-install.md${RESET} → Troubleshooting → No boot option"
