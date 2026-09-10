#!/usr/bin/env bash
#
# wallpaper-redress.sh — put the cheat-sheet back when its monitor returns.
#
# awww re-attaches a hotplugged output with the last image that was set for
# *all* outputs — the leaves — so the portrait cheat-sheet is silently lost
# whenever that monitor is unplugged or power-cycled. Called from the
# monitor.added handler in config/hypr/hyprland.lua.
#
# Checks which image the output is actually displaying rather than whether it
# is dressed at all: the returning output isn't bare, it shows the wrong one.
#
# Usage: wallpaper-redress.sh <connector>

set -euo pipefail

OUTPUT="${1:-}"
[[ -n "$OUTPUT" ]] || exit 0

PNG="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/shortcuts-wallpaper.png"
SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Only a rotated output carries the cheat-sheet (transform 1/3, or 5/7 when
# flipped). This also exits straight away when the monitor that was added is a
# different one and this connector isn't connected at all.
transform=$(hyprctl monitors -j | jq -r --arg o "$OUTPUT" '.[] | select(.name == $o) | .transform')
case "$transform" in
    1 | 3 | 5 | 7) ;;
    *) exit 0 ;;
esac

# monitor.added can fire before awww has attached to the new output.
line=""
for _ in $(seq 20); do
    line=$(awww query 2>/dev/null | grep -F ": $OUTPUT:" || true)
    [[ -n "$line" ]] && break
    sleep 0.5
done
[[ -n "$line" ]] || exit 0

# Already right — the event was for the other monitor.
[[ "$line" == *"$PNG"* ]] && exit 0

# Reuses the cached render when shortcuts.md/.css are unchanged, so in the
# common case this is a single awww call rather than a headless Chrome run.
exec bash "$SCRIPTS_DIR/shortcuts-wallpaper.sh" "$OUTPUT"
