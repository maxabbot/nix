#!/bin/bash
# Gaming mode toggle for Hyprland
# Kills waybar/notifications, disables blur+animations, and drops every other
# screen out of the layout entirely, so the gaming panel is the only display
# Hyprland — and anything running on it — can see.
# Run again to restore the normal desktop session (screens back).
#
# Disabling, not blanking. `dpms off` only darkens an output: it stays in the
# layout, so games still enumerate two displays, a window can still land on the
# dark one, and XWayland still lists it in RANDR (which is the whole reason
# hyprland.lua has to pin the RANDR primary). `hl.monitor({disabled = true})`
# takes the output out altogether. Hyprland migrates that output's workspaces
# to what is left and — verified on 0.55.4 — puts them back on it when it
# returns, so the desktop arrangement survives the round trip.
#
# It deliberately launches nothing. This used to wrap Steam Big Picture in
# gamescope, which broke more than it fixed — and because the toggle owned the
# launch, leaving gaming mode had to pkill steam/gamescope/lutris, which killed
# whatever was actually running. Start games however you like; this only sets
# the desktop up around them and puts it back afterwards.

GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

# home-desktop connectors.
MAIN_MON="DP-3"      # AOC 1440p @ 165
SEC_MON="DP-2"       # rotated 4K portrait, carries the shortcuts cheat sheet

# Outputs Hyprland knows about but is not currently driving — i.e. the ones
# this script disabled. `monitors all` lists disabled outputs, plain `monitors`
# does not; disconnected connectors appear in neither, so the difference is
# exactly the disabled set. `.disabled` itself is no use as a readiness signal:
# it flips back to false the moment the config is accepted, well before the
# output is actually re-attached.
absent_outputs() {
    local live
    live=$(hyprctl monitors -j | jq -r '.[].name')
    hyprctl monitors all -j | jq -r '.[].name' | while read -r n; do
        printf '%s\n' "$live" | grep -qx "$n" || printf '%s\n' "$n"
    done
}

if [ -f "$GAMING_STATE_FILE" ]; then
    # Exit gaming mode
    rm "$GAMING_STATE_FILE"

    # Bring the other outputs back with a reload rather than by re-sending each
    # saved spec: re-applying a spec (even with an explicit disabled = false)
    # leaves the output config-enabled but not re-attached until a second
    # identical call — observed repeatedly on 0.55.4. `hyprctl reload` re-runs
    # monitors.lua, which is the Nix-declared layout plus any monitors-local.lua
    # saved from the Quickshell Monitors page, and re-attaches in about a
    # second. The cost is that Monitors-page tweaks made this session and never
    # saved are dropped; "Save layout" there is what makes them survive.
    #
    # Reload is asynchronous, and the config's top level only registers event
    # handlers (autostart hangs off hl.on("hyprland.start")), so this re-runs
    # nothing and spawns no duplicates. Nudge again if an output is still out.
    hyprctl reload >/dev/null
    for _ in 1 2 3; do
        sleep 0.7
        [ -z "$(absent_outputs)" ] && break
        hyprctl reload >/dev/null
    done

    # Restore compositor effects. `hyprctl keyword` doesn't work with the Lua
    # config parser ("keyword can't work with non-legacy parsers") — use eval
    # with a partial hl.config, which merges into the running config.
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } }, animations = { enabled = true } })'

    # awww keeps its per-output images across a disable/enable cycle (a DPMS
    # cycle, by contrast, drops them), so only redress the desktop if something
    # actually came back bare: leaves on every output, then the portrait
    # cheat-sheet back over the secondary. Backgrounded — it re-renders through
    # headless Chrome and shouldn't hold up the toggle.
    live_count=$(hyprctl monitors -j | jq 'length')
    dressed_count=$(awww query 2>/dev/null | grep -c 'displaying: image:')
    if [ "${dressed_count:-0}" -lt "${live_count:-0}" ]; then
        awww img ~/.config/hypr/wallpaper.png --resize crop --transition-type wipe --transition-fps 60
        bash ~/.config/hypr/scripts/shortcuts-wallpaper.sh "$SEC_MON" &
        disown
    fi

    # Restore whichever shell was selected before gaming mode — not
    # unconditionally this config's own one, since the shell is switchable
    # (shell-switch.sh / modules/home/wm/shell-switcher.nix). Waybar comes back
    # with it via shell-own.service's Wants=, and stays down for the other
    # three, which bring their own bars.
    bash ~/.config/hypr/scripts/shell-switch.sh restore
else
    # Enter gaming mode

    # Resolve the gaming panel. If DP-3 isn't there (cable out, or this script
    # running on another host) fall back to whatever holds focus — anything
    # rather than disabling every output and leaving a headless session.
    target="$MAIN_MON"
    if ! hyprctl monitors -j | jq -e --arg t "$target" 'any(.[]; .name == $t)' >/dev/null; then
        target=$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused) | .name) // empty')
    fi
    if [ -z "$target" ]; then
        echo "gaming-toggle: no monitor to game on, staying put" >&2
        exit 1
    fi

    touch "$GAMING_STATE_FILE"

    # Kill distractions: stop the active shell's unit rather than pkill'ing
    # Shell.qml, which would miss noctalia/dms/caelestia entirely. Waybar is
    # PartOf=shell-own.service so it goes down with it.
    systemctl --user stop "$(bash ~/.config/hypr/scripts/shell-switch.sh unit)"

    # Disable compositor effects for performance (eval, not keyword — see above).
    hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })'

    # Park focus on the gaming panel before the others go, so a game launched
    # from here opens on it and the cursor isn't stranded on a vanishing
    # output. hl.dsp.focus{monitor=...} — plain `hyprctl dispatch focusmonitor`
    # fails under the Lua config parser.
    hyprctl dispatch "hl.dsp.focus{monitor=\"$target\"}" >/dev/null 2>&1

    mapfile -t other_mons < <(hyprctl monitors -j | jq -r --arg t "$target" \
        '.[] | select(.name != $t) | .name')

    for m in "${other_mons[@]}"; do
        # Un-fullscreen first. Disabling an output migrates its windows to the
        # gaming panel, and moving a *fullscreen* window between monitors is
        # the known compositor SIGSEGV. Both flags go to 0 so nothing is left
        # half-fullscreen at migration time; a client that wants it back will
        # ask again.
        hyprctl eval "
            for _, w in ipairs(hl.get_windows({ monitor = \"$m\" })) do
                if w.fullscreen ~= 0 or w.fullscreen_client ~= 0 then
                    hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 0, client = 0 }))
                end
            end" >/dev/null 2>&1

        # Out of the layout. Hyprland applies asynchronously; back-to-back
        # calls across several outputs otherwise race.
        hyprctl eval "hl.monitor({ output = \"$m\", disabled = true })" >/dev/null 2>&1
        sleep 0.4
    done
fi
