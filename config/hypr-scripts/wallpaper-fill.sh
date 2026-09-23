#!/usr/bin/env bash
#
# wallpaper-fill.sh — dress hotplugged outputs that awww has never drawn on.
#
# awww restores a returning output from its per-connector cache
# (~/.cache/awww/<version>/<connector>), but an output it has never set an
# image on has no entry and comes up plain black. That is every dock monitor
# first connected after login: wallpaper.lua runs once at hyprland.start and
# only reaches the outputs present then. Once dressed here, awww caches them
# and restores them itself on later hotplugs.
#
# A bare output copies what a dressed one is showing, so a pick from a shell's
# wallpaper picker carries over rather than being reset to the leaves. The
# portrait cheat-sheet is never copied. Called from the monitor.added handler
# in config/hypr/hyprland.lua; the optional argument is the portrait secondary,
# handed on to wallpaper-redress.sh afterwards so the two never race.
#
# Usage: wallpaper-fill.sh [secondary-connector]

set -euo pipefail

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"
FALLBACK="$HOME/.config/hypr/wallpaper.png"
CHEATSHEET="shortcuts-wallpaper.png"

mapfile -t outputs < <(hyprctl monitors -j | jq -r '.[].name')

# monitor.added can fire before awww has attached to the new output.
state=""
for _ in $(seq 20); do
    state=$(awww query 2>/dev/null || true)
    attached=1
    for o in "${outputs[@]}"; do
        grep -qF ": $o:" <<<"$state" || attached=0
    done
    ((attached)) && break
    sleep 0.5
done

src=$(sed -n 's/.*currently displaying: image: //p' <<<"$state" | grep -vF "$CHEATSHEET" | head -n1 || true)
[[ -n "$src" ]] || src=$FALLBACK

# awww's never-drawn state. A solid black picked deliberately in a shell's
# picker looks the same and would be overwritten — an accepted edge case.
while IFS= read -r line; do
    [[ "$line" == *"currently displaying: color: 000000" ]] || continue
    output=${line#: }
    output=${output%%:*}
    awww img "$src" --outputs "$output" --resize crop \
        --transition-type wipe --transition-fps 60
done <<<"$state"

if [[ -n "${1:-}" ]]; then
    exec bash "$SCRIPTS_DIR/wallpaper-redress.sh" "$1"
fi
