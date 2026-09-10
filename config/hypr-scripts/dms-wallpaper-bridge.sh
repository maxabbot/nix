#!/usr/bin/env bash
#
# dms-wallpaper-bridge.sh — apply wallpapers picked in DMS through awww.
#
# DMS's own wallpaper layer is switched off (screenPreferences.wallpaper = [],
# which is what its "Disable Built-in Wallpapers" toggle writes) so awww stays
# the single wallpaper owner. But a pick in DMS's picker then only lands in its
# session.json and nothing draws it. dms-wallpaper-bridge.path watches that
# file and runs this; see modules/home/wm/shell-switcher.nix.
#
# A global pick skips the outputs in $PORTRAIT_OUTPUTS, which carry the
# rendered cheat-sheet. A per-monitor pick is honoured exactly as given.

set -euo pipefail

SESSION="${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell/session.json"
# Runtime dir, not state: wallpaper.lua resets awww to the leaves at every
# login, so a stamp that outlived the session would wrongly skip re-applying.
APPLIED="${XDG_RUNTIME_DIR:-/tmp}/hypr/dms-wallpaper-applied"

[[ -s "$SESSION" ]] || exit 0

# session.json is rewritten for unrelated state too (do-not-disturb, notepad…),
# so compare only the wallpaper fields with what was last applied.
want=$(jq -c '{perMonitorWallpaper, wallpaperPath, monitorWallpapers}' "$SESSION")
if [[ -f "$APPLIED" && "$(cat "$APPLIED")" == "$want" ]]; then
    exit 0
fi

# DMS stores a solid colour as "#rrggbb"; awww clear wants it without the '#'.
apply() {
    local output=$1 src=$2
    case "$src" in
        "") return 0 ;;
        \#*) awww clear "${src#\#}" --outputs "$output" ;;
        *) awww img "$src" --outputs "$output" --resize crop \
            --transition-type wipe --transition-fps 60 ;;
    esac
}

IFS=',' read -r -a portrait <<<"${PORTRAIT_OUTPUTS:-}"
is_portrait() {
    local o
    for o in "${portrait[@]}"; do
        [[ "$o" == "$1" ]] && return 0
    done
    return 1
}

if [[ "$(jq -r '.perMonitorWallpaper' <<<"$want")" == "true" ]]; then
    # Keys are connector names under displayNameMode "system" (the default).
    while IFS=$'\t' read -r output src; do
        apply "$output" "$src"
    done < <(jq -r '.monitorWallpapers // {} | to_entries[] | [.key, .value] | @tsv' <<<"$want")
else
    src=$(jq -r '.wallpaperPath // ""' <<<"$want")
    while read -r output; do
        is_portrait "$output" || apply "$output" "$src"
    done < <(hyprctl monitors -j | jq -r '.[].name')
fi

mkdir -p "$(dirname "$APPLIED")"
printf '%s\n' "$want" >"$APPLIED"
