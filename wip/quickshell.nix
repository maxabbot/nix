# wip/quickshell.nix — Quickshell top bar, removed from active config 2026-05-14.
# Re-add once ready to wire behind a proper toggle.
# QML sources live at wip/config/quickshell/ — move back to
# config/hypr-scripts/quickshell/ before restoring the exec-once below.
#
# ── modules/nixos/productivity.nix ────────────────────────────────────────────
# Add to system.activationScripts (currently present but can be kept for gaming-toggle.sh):
#
#   system.activationScripts.chmodHyprScripts.text = ''
#     if [ -d /etc/nixos/config/hypr-scripts ]; then
#       ${pkgs.findutils}/bin/find /etc/nixos/config/hypr-scripts \
#         -type f -name '*.sh' -exec chmod +x {} +
#     fi
#   '';
#
# Add to environment.systemPackages:
#
#   # Quickshell top bar + required Qt6 modules
#   quickshell
#   qt6.qtmultimedia
#   qt6.qt5compat
#   qt6.qtwebsockets
#   qt6.qtwebengine
#
#   # Shell utilities used by quickshell scripts
#   socat
#   acpi
#   iw
#   bluez
#   bc
#
# ── modules/home/wm/hyprland.nix ──────────────────────────────────────────────
# Add to exec-once:
#
#   "quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml"
#   "python3 ~/.config/hypr/scripts/quickshell/focustime/focus_daemon.py &"
#
# Add to bind:
#
#   "$mainMod, D, exec, ~/.config/hypr/scripts/qs_manager.sh toggle applauncher"
#   "$mainMod, C, exec, ~/.config/hypr/scripts/qs_manager.sh toggle clipboard"
#   "$mainMod, M, exec, ~/.config/hypr/scripts/qs_manager.sh toggle monitors"
#   "$mainMod, N, exec, ~/.config/hypr/scripts/qs_manager.sh toggle network"
#   "$mainMod, W, exec, ~/.config/hypr/scripts/qs_manager.sh toggle wallpaper"
#
# Restore the scripts symlink (also needed for gaming-toggle.sh, so restore it regardless):
#
#   home.file.".config/hypr/scripts".source =
#     config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/hypr-scripts";
