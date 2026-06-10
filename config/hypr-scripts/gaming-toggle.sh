#!/bin/bash
# Gaming mode toggle for Hyprland
# Kills waybar/notifications, launches Lutris+Steam, disables blur/animations
# Run again to restore normal desktop session

GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

if [ -f "$GAMING_STATE_FILE" ]; then
    # Exit gaming mode
    rm "$GAMING_STATE_FILE"

    # Restore compositor effects. `hyprctl keyword` doesn't work with the Lua
    # config parser ("keyword can't work with non-legacy parsers") — use eval
    # with a partial hl.config, which merges into the running config.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } }, animations = { enabled = true } })'

    # Kill game launchers
    pkill -x lutris 2>/dev/null || true
    pkill -x gamescope 2>/dev/null || true
    pkill -x steam 2>/dev/null || true

    # Restore bar and notifications. Waybar is a systemd user service
    # (programs.waybar.systemd.enable) — manage it through systemctl, not a
    # raw `waybar &`, or the unit is left failed and the process unmanaged.
    systemctl --user start waybar.service
    quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml >/dev/null 2>&1 &
    disown
else
    # Enter gaming mode
    touch "$GAMING_STATE_FILE"

    # Kill distractions (waybar via its systemd unit, see above)
    systemctl --user stop waybar.service
    pkill -f "quickshell.*Shell.qml" 2>/dev/null || true

    # Disable compositor effects for performance (eval, not keyword — see above)
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })'

    # Launch game launchers
    lutris &
    disown
    # Gamescope wraps BPM for direct GPU rendering — avoids XWayland lag.
    # Size/refresh come from the focused monitor so this works on any host.
    read -r GS_W GS_H GS_R < <(hyprctl monitors -j 2>/dev/null \
        | jq -r '.[] | select(.focused) | "\(.width) \(.height) \(.refreshRate|round)"') || true
    gamescope -W "${GS_W:-1920}" -H "${GS_H:-1080}" -r "${GS_R:-60}" -f -e -- steam -bigpicture &
    disown
fi
