# wip/matugen.nix — Matugen dynamic color theming, removed from active config 2026-05-14.
# Re-add once ready to wire behind a proper toggle.
#
# ── modules/nixos/productivity.nix ────────────────────────────────────────────
# Add to environment.systemPackages:
#
#   # Dynamic color theming
#   matugen
#
# ── modules/home/apps.nix ─────────────────────────────────────────────────────
# Add to programs.kitty:
#
#   # Load matugen-generated colors at runtime (overrides static palette above)
#   extraConfig = "include /tmp/kitty-matugen-colors.conf";
#
# ── modules/home/theme.nix ────────────────────────────────────────────────────
# Add to gtk.gtk3:
#
#   extraCss = ''@import url("file://${config.home.homeDirectory}/.cache/matugen/colors-gtk.css");'';
#
# Add to gtk.gtk4:
#
#   extraCss = ''@import url("file://${config.home.homeDirectory}/.cache/matugen/colors-gtk.css");'';
#
# Restore matugen config symlink:
#
#   xdg.configFile."matugen" = {
#     source = ../../config/matugen;
#     recursive = true;
#   };
#
# Restore fallback seed activation (GTK @import hard-fails if file missing on first boot):
#
#   home.activation.initMatugenFallbacks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
#     if [ ! -f "$HOME/.cache/matugen/colors-gtk.css" ]; then
#       mkdir -p "$HOME/.cache/matugen"
#       touch "$HOME/.cache/matugen/colors-gtk.css"
#     fi
#   '';
#
# ── modules/home/wm/hyprland.nix ──────────────────────────────────────────────
# Restore initHyprColors activation (creates fallback colors.conf before matugen runs):
#
#   home.activation.initHyprColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
#     if [ ! -f "$HOME/.config/hypr/colors.conf" ]; then
#       mkdir -p "$HOME/.config/hypr"
#       printf '$active_border = rgba(7daea3ee) rgba(d3869bee) 45deg\n$inactive_border = rgba(3c3836aa)\n' \
#         > "$HOME/.config/hypr/colors.conf"
#     fi
#   '';
#
# Restore source line in extraConfig:
#
#   source = ~/.config/hypr/colors.conf
