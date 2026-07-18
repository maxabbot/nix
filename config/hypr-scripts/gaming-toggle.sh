#!/bin/bash
# Gaming mode toggle for Hyprland
# Prompts for a target monitor (main panel / TV — TV only when it's powered on),
# then kills waybar/notifications, disables blur+animations, blanks the other
# screens (DPMS off), and launches Steam Big Picture in gamescope fullscreen on
# the chosen monitor.
# Run again to restore the normal desktop session (screens back on).

GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

# home-desktop connectors.
MAIN_MON="DP-3"      # AOC 1440p @ 165
TV_MON="HDMI-A-1"    # Philips FTV 4K @ 60

# Is the TV actually on? It has no DDC/CI and its connector is force-on
# (video=HDMI-A-1:e), so DRM and hyprland always report it connected. The
# HDMI-audio ELD still tracks real HPD, so key off monitor_present on the pin
# whose EDID names the Philips TV.
tv_is_on() {
    local eld
    for eld in /proc/asound/card*/eld#*; do
        [ -f "$eld" ] || continue
        if grep -q "Philips" "$eld" && grep -q "^monitor_present[[:space:]]*1" "$eld"; then
            return 0
        fi
    done
    return 1
}

# "W H R" (rounded refresh) for a connector, from hyprland's live mode.
mon_mode() {
    hyprctl monitors -j | jq -r --arg n "$1" \
        '.[] | select(.name==$n) | "\(.width) \(.height) \(.refreshRate|round)"'
}

# Drive monitors to a DPMS state. $1 = on|off ; remaining args = monitor names.
#
# The hl.dsp.dpms dispatch IGNORES its state arg and simply TOGGLES on every
# call (verified: repeated "off" flips false→true→false). So we can't set an
# absolute state blindly — read each monitor's current dpmsStatus and toggle
# ONLY when it differs from what we want. This is idempotent and, critically,
# never toggles a monitor that's already correct — the old blind "on for every
# monitor" on exit toggled the never-blanked target screen *off* (black main).
# `hyprctl dispatch dpms ...` also fails outright under the Lua config parser,
# hence the hl.dsp.dpms{...} form.
dpms_set() {
    local want="$1"; shift
    local m cur
    for m in "$@"; do
        cur=$(hyprctl monitors all -j | jq -r --arg n "$m" \
            '.[] | select(.name==$n) | .dpmsStatus')
        if { [ "$want" = "on" ]  && [ "$cur" = "false" ]; } \
        || { [ "$want" = "off" ] && [ "$cur" = "true"  ]; }; then
            hyprctl dispatch "hl.dsp.dpms{monitor=\"$m\", state=\"toggle\"}" >/dev/null 2>&1
            sleep 0.4
        fi
    done
}

if [ -f "$GAMING_STATE_FILE" ]; then
    # Exit gaming mode
    rm "$GAMING_STATE_FILE"

    # Re-arm DPMS-on-input first, then wake every screen that's currently off.
    hyprctl eval 'hl.config({ misc = { mouse_move_enables_dpms = true, key_press_enables_dpms = true } })'
    mapfile -t all_mons < <(hyprctl monitors all -j | jq -r '.[].name')
    dpms_set on "${all_mons[@]}"

    # Restore compositor effects. `hyprctl keyword` doesn't work with the Lua
    # config parser ("keyword can't work with non-legacy parsers") — use eval
    # with a partial hl.config, which merges into the running config.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } }, animations = { enabled = true } })'

    # Re-apply wallpapers. The gamescope/DPMS cycle drops awww's per-output
    # images, so the desktop comes back with a blank/leaves DP-2 and the
    # portrait shortcuts cheat-sheet gone. Mirror the startup wallpaper.lua:
    # leaves on every output, then override the rotated DP-2 with the cheat-sheet
    # (backgrounded — it re-renders via headless Chrome and shouldn't block exit).
    awww img ~/.config/hypr/wallpaper.png --resize crop --transition-type wipe --transition-fps 60
    bash ~/.config/hypr/scripts/shortcuts-wallpaper.sh DP-2 &
    disown

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

    # Pick the target monitor first — before tearing anything down — so that
    # cancelling the picker is a clean no-op. Always offer the main panel; offer
    # the TV only when it's powered on.
    labels=("Main panel — 1440p @ 165")
    mons=("$MAIN_MON")
    if tv_is_on; then
        labels+=("TV — 4K @ 60")
        mons+=("$TV_MON")
    fi

    if [ "${#mons[@]}" -gt 1 ]; then
        idx=$(printf '%s\n' "${labels[@]}" | fuzzel --dmenu --index --prompt "Game on › ")
        [ -z "$idx" ] && exit 0            # cancelled — stay in desktop mode
        target="${mons[$idx]}"
    else
        target="$MAIN_MON"
    fi

    touch "$GAMING_STATE_FILE"

    # Kill distractions (waybar via its systemd unit, see exit branch)
    systemctl --user stop waybar.service
    pkill -f "quickshell.*Shell.qml" 2>/dev/null || true

    # Disable compositor effects for performance (eval, not keyword — see above).
    # Also disarm DPMS-on-input, or a mouse move / key press would wake the
    # screens we blank below (this host sets both enables = true).
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false }, misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = false } })'

    # Open gamescope on the chosen monitor: focus it first so the new gamescope
    # window (class "gamescope") lands there, then the fullscreen+immediate
    # window rule in hyprland.lua direct-scanouts it to that one display.
    # hl.dsp.focus{monitor=...} — plain `hyprctl dispatch focusmonitor` fails
    # under the Lua config parser.
    hyprctl dispatch "hl.dsp.focus{monitor=\"$target\"}" >/dev/null 2>&1

    # Blank every screen except the gaming monitor.
    mapfile -t other_mons < <(hyprctl monitors all -j | jq -r --arg t "$target" \
        '.[] | select(.name!=$t) | .name')
    dpms_set off "${other_mons[@]}"

    # Gamescope wraps BPM for direct GPU rendering; size/refresh come from the
    # chosen monitor's live mode.
    read -r GS_W GS_H GS_R < <(mon_mode "$target") || true
    gamescope -W "${GS_W:-2560}" -H "${GS_H:-1440}" -r "${GS_R:-165}" --rt -f -e -- steam -bigpicture &
    disown
fi
