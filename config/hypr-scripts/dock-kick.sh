#!/usr/bin/env bash
#
# dock-kick.sh — blank and wake newly docked external outputs once hotplug
# settles, so they get a real modeset.
#
# On the framework's dock, a replug renumbers the MST connectors (DP-5/DP-7 ->
# DP-6/DP-9) and the new ones inherit the dead ones' CRTCs. Sometimes they are
# then left without a modeset: Hyprland and kanshi report them enabled while
# the screens sit at "no signal". A DPMS off/on cycle recovers them. This is
# aquamarine's stale-CRTC handling, a milder relative of aquamarine#386 (a
# 0.15.0 regression, fixed in 0.15.1).
#
# hyprland.lua runs this on every monitor.added/removed, and with `seed` once
# at hyprland.start. Only the run holding the newest stamp acts, after
# $SETTLE second of quiet and once kanshi has applied its profile. It kicks
# only the external outputs it hasn't seen since they last
# connected. The lid flipping kanshi between docked and docked-lid only
# toggles eDP-1, so it never flashes the externals.
#
#   dock-kick.sh        settle, then kick new externals
#   dock-kick.sh seed   record the current externals without kicking (login)
#
# A no-op wherever kanshi isn't running: the desktops have no dock.

set -euo pipefail

SETTLE=1
KANSHI_WAIT=30
DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr"
STAMP="$DIR/dock-kick.stamp"
SEEN="$DIR/dock-kick.seen"

mkdir -p "$DIR"

# Enabled, non-internal outputs. `monitors` (not `all`) leaves out disabled
# ones, which have no modeset to recover.
externals() {
    hyprctl monitors -j | jq -r '.[] | select(.name | startswith("eDP") | not) | .name' | sort
}

# Seed before the kanshi check: at hyprland.start kanshi may not be up yet.
if [[ "${1:-}" == "seed" ]]; then
    externals >"$SEEN"
    exit 0
fi

systemctl --user is-active --quiet kanshi || exit 0

token="$$-$(date +%s%N)"
printf '%s\n' "$token" >"$STAMP"
since=$(( $(date +%s) - 1 ))

sleep "$SETTLE"

[[ "$(cat "$STAMP" 2>/dev/null)" == "$token" ]] || exit 0

# Kick after kanshi's modeset, not before it, or kanshi's own modeset could
# leave the outputs dark again. It usually lands about a second after
# connect: go as soon as kanshi logs it, or give up waiting after
# $KANSHI_WAIT tenths of a second (an event kanshi applied nothing for).
for _ in $(seq "$KANSHI_WAIT"); do
    journalctl --user -u kanshi --since "@$since" -o cat -q 2>/dev/null \
        | grep -q '^configuration for profile .* applied' && break
    sleep 0.1
done

present=$(externals)
touch "$SEEN"
mapfile -t new < <(comm -23 <(printf '%s\n' "$present" | sed '/^$/d') "$SEEN")
# Overwrite rather than append: an output that went away drops out, so the same
# connector name coming back on a replug counts as new.
printf '%s\n' "$present" | sed '/^$/d' >"$SEEN"

[[ ${#new[@]} -gt 0 ]] || exit 0

# Leave alone an output the user blanked on purpose: dpms.sh's off/on would
# otherwise light it.
lit=()
for m in "${new[@]}"; do
    [[ "$(hyprctl monitors -j | jq -r --arg n "$m" '.[] | select(.name==$n) | .dpmsStatus')" == "true" ]] \
        && lit+=("$m")
done
[[ ${#lit[@]} -gt 0 ]] || exit 0

bash ~/.config/hypr/scripts/dpms.sh off "${lit[@]}"
sleep 0.5
bash ~/.config/hypr/scripts/dpms.sh on "${lit[@]}"
