#!/usr/bin/env bash
# =============================================================================
# setup.sh — NixOS rebuild wrapper
#
# Detects the current host and runs:
#   nixos-rebuild switch --flake .#<host>
#
# Also supports first-time NixOS installation guidance.
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

# ─── Helpers ─────────────────────────────────────────────────────────────────

detect_host() {
  hostname --short 2>/dev/null || hostname
}

require_nixos() {
  if [[ ! -f /etc/nixos/configuration.nix && ! -f /run/current-system/nixos-version ]]; then
    log_error "This script must be run on a NixOS system."
    log_error "For first-time installation, see the README."
    exit 1
  fi
}

# ─── Host Selection ───────────────────────────────────────────────────────────

select_host() {
  local detected
  detected=$(detect_host)

  log_header "Host Selection"
  echo "Available hosts:"
  echo ""
  echo "  ${BOLD}1)${RESET} home-desktop  — RTX 40-series gaming workstation (Hyprland)"
  echo "  ${BOLD}2)${RESET} work-laptop   — Development laptop (Sway, TLP)"
  echo "  ${BOLD}3)${RESET} minimal       — Headless / base only"
  echo ""

  if echo "home-desktop work-laptop minimal" | grep -qw "$detected"; then
    log_info "Detected hostname: ${BOLD}${detected}${RESET}"
    read -rp "Use detected host '${detected}'? [Y/n] " use_detected
    if [[ "${use_detected,,}" != "n" ]]; then
      HOST="$detected"
      return
    fi
  fi

  read -rp "Select host [1-3]: " choice
  case "$choice" in
    1) HOST="home-desktop" ;;
    2) HOST="work-laptop" ;;
    3) HOST="minimal" ;;
    *) log_warn "Invalid choice, using detected host: ${detected}"; HOST="$detected" ;;
  esac

  log_info "Selected host: ${BOLD}${HOST}${RESET}"
}

# ─── NixOS Rebuild ────────────────────────────────────────────────────────────

run_rebuild() {
  log_header "NixOS Rebuild"

  local flake_ref="${SCRIPT_DIR}#${HOST}"

  log_info "Running: nixos-rebuild switch --flake ${flake_ref}"
  sudo nixos-rebuild switch --flake "$flake_ref"

  log_success "System rebuilt successfully for host: ${HOST}"
}

# ─── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
  log_header "Rebuild Complete"

  cat <<EOF
${GREEN}✓${RESET} NixOS switched to flake config for host: ${BOLD}${HOST}${RESET}

${BOLD}Useful commands:${RESET}
  Rebuild system:   ${CYAN}sudo nixos-rebuild switch --flake /etc/nixos#${HOST}${RESET}
  Test (no switch): ${CYAN}sudo nixos-rebuild test   --flake /etc/nixos#${HOST}${RESET}
  Build only:       ${CYAN}sudo nixos-rebuild build  --flake /etc/nixos#${HOST}${RESET}
  Update flake:     ${CYAN}cd /etc/nixos && nix flake update${RESET}
  GC old gens:      ${CYAN}sudo nix-collect-garbage -d${RESET}
  List generations: ${CYAN}sudo nix-env --list-generations --profile /nix/var/nix/profiles/system${RESET}
EOF
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  log_header "NixOS Flake Setup"

  echo "This script rebuilds your NixOS system from the flake in:"
  echo "  ${CYAN}${SCRIPT_DIR}${RESET}"
  echo ""

  require_nixos

  read -rp "Continue? [Y/n] " confirm
  if [[ "${confirm,,}" == "n" ]]; then
    log_info "Aborted."
    exit 0
  fi

  select_host
  run_rebuild
  print_summary
}

main "$@"
