#!/bin/bash
# Gaming mode toggle for Hyprland
# Kills waybar/notifications, launches Lutris+Steam, disables blur/animations
# Run again to restore normal desktop session

GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

if [ -f "$GAMING_STATE_FILE" ]; then
    # Exit gaming mode
    rm "$GAMING_STATE_FILE"

    # Restore compositor effects
    hyprctl keyword decoration:blur:enabled 1
    hyprctl keyword animations:enabled 1

    # Kill game launchers
    pkill -x lutris 2>/dev/null || true
    pkill -x steam 2>/dev/null || true

    # Restore bar and notifications
    waybar &
    disown
    swaync &
    disown
else
    # Enter gaming mode
    touch "$GAMING_STATE_FILE"

    # Kill distractions
    pkill -f waybar 2>/dev/null || true
    pkill -f swaync 2>/dev/null || true

    # Disable compositor effects for performance
    hyprctl keyword decoration:blur:enabled 0
    hyprctl keyword animations:enabled 0

    # Launch game launchers
    lutris &
    disown
    steam -silent &
    disown
fi
