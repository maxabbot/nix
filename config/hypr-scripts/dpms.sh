#!/bin/bash
# dpms.sh — the one place that drives Hyprland monitor DPMS state.
#
# Two constraints shape everything below:
#
#   1. `hyprctl dispatch dpms off` fails outright under the Lua config parser —
#      dispatch args are evaluated as Lua, so a bare `off` is a parse error
#      ("')' expected near 'off'") and the screens silently stay as they were.
#      Hence the hl.dsp.dpms{...} table form.
#   2. hl.dsp.dpms IGNORES its state arg and simply TOGGLES on every call
#      (verified: repeated "off" flips false->true->false). An absolute state
#      therefore can't be set blindly — read each monitor's dpmsStatus and
#      toggle ONLY the ones that differ. That also makes every verb idempotent,
#      and, critically, never flips a monitor that is already correct.
#
# The other half of the problem is misc.{mouse_move,key_press}_enables_dpms,
# which hyprland.lua sets true: with those armed, anything blanked by hand is
# woken again by the very next mouse twitch. So "blank and stay blank" has to
# disarm them — and every wake re-arms them once nothing is left blanked, or a
# stale disarm would leave the session unable to wake on input at all.
#
# A third wrinkle, found the hard way: a DP display left blanked long enough to
# reach real standby drops its link, and Hyprland removes the output from
# `monitors all` altogether. It is then unreachable by name, so a toggle can
# never wake it — every wake path therefore checks the kernel's connector list
# and reloads the declared layout when something plugged in has gone missing.
#
#   on [mon...]        wake (default: all), recovering vanished outputs, then
#                      re-arm wake-on-input if no monitor is left blanked
#   off [mon...]       blank (default: all), leaving wake-on-input armed — the
#                      idle path, where a keypress *should* bring them back
#   hold-off [mon...]  disarm wake-on-input, then blank — the manual path
#   toggle <mon>       hold-off if that monitor is on, on if it is off
#   idle-off/idle-on   off/on for every monitor, but a no-op while gaming mode
#                      is on (see gaming-toggle.sh)
#
# Super + Shift + D is bound to `dpms.sh on` as the escape hatch: it is the way
# back after blanking the screen you were looking at.
set -euo pipefail

# Set by gaming-toggle.sh for as long as gaming mode is on.
GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

# `monitors all` rather than `monitors`: the plain form is fine for dpms-off
# outputs but drops disabled ones, and we want a stable view either way.
all_monitors() {
    hyprctl monitors all -j | jq -r '.[].name'
}

# "true" / "false", or empty for a name that isn't connected.
dpms_status() {
    hyprctl monitors all -j | jq -r --arg n "$1" '.[] | select(.name==$n) | .dpmsStatus'
}

any_blanked() {
    [ -n "$(hyprctl monitors all -j | jq -r '.[] | select(.dpmsStatus==false) | .name')" ]
}

# $1 = true|false — arm or disarm waking the screens on mouse/keyboard input.
# `hyprctl keyword` is rejected by the Lua parser ("keyword can't work with
# non-legacy parsers"), so this goes through eval with a partial hl.config,
# which merges into the running config.
set_input_wake() {
    hyprctl eval \
        "hl.config({ misc = { mouse_move_enables_dpms = $1, key_press_enables_dpms = $1 } })" \
        >/dev/null 2>&1 || true
}

# $1 = on|off ; remaining args = monitor names.
dpms_set() {
    local want="$1"; shift
    local m cur
    for m in "$@"; do
        cur=$(dpms_status "$m")
        if { [ "$want" = "on" ]  && [ "$cur" = "false" ]; } \
        || { [ "$want" = "off" ] && [ "$cur" = "true"  ]; }; then
            hyprctl dispatch "hl.dsp.dpms{monitor=\"$m\", state=\"toggle\"}" >/dev/null 2>&1 || true
            # Hyprland applies asynchronously; back-to-back toggles across
            # several outputs otherwise race and land on the wrong states.
            sleep 0.4
        fi
    done
}

# Connector names the kernel currently sees as plugged in, e.g. "DP-2".
# /sys/class/drm entries are "card1-DP-2"; strip the card prefix to get the
# name Hyprland uses.
drm_connected() {
    local f d n
    for f in /sys/class/drm/card*-*/status; do
        [ -r "$f" ] || continue
        [ "$(cat "$f")" = "connected" ] || continue
        d=${f%/status}
        n=${d##*/}
        printf '%s\n' "${n#*-}"
    done
}

# Outputs the kernel still sees but Hyprland has stopped driving. A DP display
# left blanked long enough to enter real standby drops its link, and Hyprland
# removes the output entirely — it is not merely dpmsStatus=false, it is gone
# from `monitors all`. That is why a plain toggle could never bring it back:
# there was no longer anything named DP-2 to dispatch at.
missing_outputs() {
    local live drm
    live=$(hyprctl monitors all -j | jq -r '.[].name')
    for drm in $(drm_connected); do
        printf '%s\n' "$live" | grep -qx "$drm" || printf '%s\n' "$drm"
    done
}

# Wake, then hand wake-on-input back if the session is fully lit again.
wake() {
    dpms_set on "$@"

    # Nothing above could touch an output that has vanished, so re-apply the
    # declared layout: reload re-runs monitors.lua, which re-declares every
    # output and forces a modeset.
    #
    # Check twice with a gap. An output legitimately drops out of `monitors all`
    # for a moment *during* its own wake modeset, so a single check would call
    # every ordinary wake a lost output and reload the whole config each time.
    if [ -n "$(missing_outputs)" ]; then
        sleep 2
    fi
    if [ -n "$(missing_outputs)" ]; then
        hyprctl reload >/dev/null 2>&1 || true
        sleep 1.5
        # Whatever came back may still be blanked.
        mapfile -t back < <(hyprctl monitors all -j | jq -r '.[] | select(.dpmsStatus==false) | .name')
        if [ ${#back[@]} -gt 0 ]; then
            dpms_set on "${back[@]}"
        fi
    fi

    any_blanked || set_input_wake true
}

# If the monitor holding focus has just been blanked, move focus to one that is
# still lit. Without this, blanking the screen you are working on strands you:
# Settings.qml anchors to Theme.focusedScreen(), so the panel — and the Wake
# chip that undoes the blank — reopens on the dark output every time, and
# wake-on-input is deliberately disarmed, so there is no pointer way back
# either. Only the manual paths call this; idle-off blanks everything, where
# there is nothing lit to move to and input-wake is left armed anyway.
refocus_if_dark() {
    local focused lit
    focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    [ -n "$focused" ] || return 0
    [ "$(dpms_status "$focused")" = "false" ] || return 0
    lit=$(hyprctl monitors all -j | jq -r 'first(.[] | select(.dpmsStatus) | .name) // empty')
    [ -n "$lit" ] || return 0
    hyprctl dispatch "hl.dsp.focus{monitor=\"$lit\"}" >/dev/null 2>&1 || true
}

verb="${1:-}"
shift || true
args=("$@")

# No monitors named = act on every connected output.
if [ ${#args[@]} -eq 0 ]; then
    mapfile -t targets < <(all_monitors)
else
    targets=("${args[@]}")
fi

case "$verb" in
on)
    wake "${targets[@]}"
    ;;
off)
    dpms_set off "${targets[@]}"
    ;;
hold-off)
    set_input_wake false
    dpms_set off "${targets[@]}"
    refocus_if_dark
    ;;
toggle)
    if [ ${#args[@]} -ne 1 ]; then
        echo "usage: ${0##*/} toggle <monitor>" >&2
        exit 2
    fi
    cur=$(dpms_status "${args[0]}")
    if [ -z "$cur" ] || [ "$cur" = "false" ]; then
        # Empty means Hyprland is no longer driving that output at all — a
        # blanked DP display that dropped its link. Either way the intent is
        # "bring it back", and wake() knows how to recover a vanished one.
        wake "${args[0]}"
    else
        set_input_wake false
        dpms_set off "${args[0]}"
        refocus_if_dark
    fi
    ;;
idle-off)
    # In gaming mode the gaming panel is the only output left (the others are
    # disabled outright, not blanked), and a controller-only game feeds the idle
    # timer no input — blanking here would black out the game itself.
    if [ -f "$GAMING_STATE_FILE" ]; then exit 0; fi
    dpms_set off "${targets[@]}"
    ;;
idle-on)
    if [ -f "$GAMING_STATE_FILE" ]; then exit 0; fi
    wake "${targets[@]}"
    ;;
*)
    echo "usage: ${0##*/} {on|off|hold-off|toggle|idle-off|idle-on} [monitor...]" >&2
    exit 2
    ;;
esac
