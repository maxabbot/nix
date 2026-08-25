#!/bin/bash
# Gaming mode toggle for Hyprland
# Kills waybar/notifications, disables blur+animations, and blanks the other
# screens (DPMS off) so only the main gaming panel is lit.
# Run again to restore the normal desktop session (screens back on).
#
# It deliberately launches nothing. This used to wrap Steam Big Picture in
# gamescope, which broke more than it fixed — and because the toggle owned the
# launch, leaving gaming mode had to pkill steam/gamescope/lutris, which killed
# whatever was actually running. Start games however you like; this only sets
# the desktop up around them and puts it back afterwards.

GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

# home-desktop connectors.
MAIN_MON="DP-3"      # AOC 1440p @ 165

# DPMS goes through dpms.sh, which owns the toggle-only dispatch quirk and the
# wake-on-input arming — see its header. `hold-off` is the right verb here: it
# disarms mouse_move/key_press_enables_dpms before blanking, or a mouse twitch
# during a game would light the other screens straight back up.
DPMS="$HOME/.config/hypr/scripts/dpms.sh"

if [ -f "$GAMING_STATE_FILE" ]; then
    # Exit gaming mode
    rm "$GAMING_STATE_FILE"

    # Wake every screen that's currently off, which also re-arms DPMS-on-input.
    bash "$DPMS" on

    # Restore compositor effects. `hyprctl keyword` doesn't work with the Lua
    # config parser ("keyword can't work with non-legacy parsers") — use eval
    # with a partial hl.config, which merges into the running config.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } }, animations = { enabled = true } })'

    # Re-apply wallpapers. The DPMS cycle drops awww's per-output images, so the
    # desktop comes back with a blank DP-2 and the portrait shortcuts cheat-sheet
    # gone. Mirror the startup wallpaper.lua: leaves on every output, then
    # override the rotated DP-2 with the cheat-sheet (backgrounded — it
    # re-renders via headless Chrome and shouldn't block exit).
    awww img ~/.config/hypr/wallpaper.png --resize crop --transition-type wipe --transition-fps 60
    bash ~/.config/hypr/scripts/shortcuts-wallpaper.sh DP-2 &
    disown

    # Restore bar and notifications. Waybar is a systemd user service
    # (programs.waybar.systemd.enable) — manage it through systemctl, not a
    # raw `waybar &`, or the unit is left failed and the process unmanaged.
    systemctl --user start waybar.service
    quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml >/dev/null 2>&1 &
    disown
else
    # Enter gaming mode
    target="$MAIN_MON"

    touch "$GAMING_STATE_FILE"

    # Kill distractions (waybar via its systemd unit, see exit branch)
    systemctl --user stop waybar.service
    pkill -f "quickshell.*Shell.qml" 2>/dev/null || true

    # Disable compositor effects for performance (eval, not keyword — see above).
    # DPMS-on-input is disarmed by the hold-off below, not here.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })'

    # Park focus on the gaming panel before the others go dark, so a game
    # launched from here opens on it and the cursor isn't stranded on a
    # blanked output. hl.dsp.focus{monitor=...} — plain `hyprctl dispatch
    # focusmonitor` fails under the Lua config parser.
    hyprctl dispatch "hl.dsp.focus{monitor=\"$target\"}" >/dev/null 2>&1

    # Blank every screen except the gaming monitor, and keep them blanked.
    mapfile -t other_mons < <(hyprctl monitors all -j | jq -r --arg t "$target" \
        '.[] | select(.name!=$t) | .name')
    if [ ${#other_mons[@]} -gt 0 ]; then
        bash "$DPMS" hold-off "${other_mons[@]}"
    fi
fi
