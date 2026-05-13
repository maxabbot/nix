# wip/cava.nix — Cava audio visualizer, removed from active config 2026-05-14.
# Re-add once ready to wire behind a proper toggle.
#
# ── modules/nixos/productivity.nix ────────────────────────────────────────────
# Add to environment.systemPackages:
#
#   # Audio visualizer
#   cava
#
# ── modules/home/apps.nix ─────────────────────────────────────────────────────
# Restore config_base symlink:
#
#   # Wrapper merges static config_base with matugen-generated colors at launch
#   xdg.configFile."cava/config_base".source = ../../config/cava/config;
#
# Add to home.packages:
#
#   # cava with matugen color merging: combines config_base + colors at launch
#   (lib.hiPrio (pkgs.writeShellScriptBin "cava" ''
#     mkdir -p ~/.config/cava
#     cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config 2>/dev/null
#     exec ${pkgs.cava}/bin/cava "$@"
#   ''))
