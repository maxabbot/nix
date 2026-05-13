# wip/swaync.nix — Swaync notification daemon, removed from active config 2026-05-14.
# Re-add once ready to wire behind a proper toggle.
# Static config + theme live at wip/config/swaync/ — move back to
# config/swaync/ before restoring the symlinks below.
#
# ── modules/nixos/productivity.nix ────────────────────────────────────────────
# Add to environment.systemPackages:
#
#   swaynotificationcenter
#
# ── modules/home/apps.nix ─────────────────────────────────────────────────────
# Restore config symlinks:
#
#   xdg.configFile."swaync/config.json".source = ../../config/swaync/config.json;
#   xdg.configFile."swaync/style.css".source = ../../config/swaync/style.css;
#
# ── modules/home/wm/hyprland.nix ──────────────────────────────────────────────
# Add to exec-once:
#
#   "swaync"
