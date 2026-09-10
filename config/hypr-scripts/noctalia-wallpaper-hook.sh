#!/usr/bin/env bash
#
# noctalia-wallpaper-hook.sh — apply wallpapers picked in Noctalia through awww.
#
# Noctalia's own wallpaper layer is patched off at build time (Background.qml,
# see modules/home/wm/shell-switcher.nix) so awww stays the single wallpaper
# owner, while wallpaper.enabled stays on so every Noctalia picker works. Its
# hooks.wallpaperChange runs this once per screen with the picked path.
#
# Usage (from the hook): noctalia-wallpaper-hook.sh <path> [screen]
#
# While setWallpaperOnAllMonitors is on, portrait outputs are skipped — they
# carry the rendered cheat-sheet. With it off, a per-monitor pick is honoured.

set -euo pipefail

SRC="${1:-}"
SCREEN="${2:-}"
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/settings.json"

[[ -n "$SRC" ]] || exit 0
# Noctalia's bundled default, reported when nothing has been picked.
[[ "$SRC" == */Assets/Wallpaper/noctalia.png ]] && exit 0

all_monitors=$(jq -r '.wallpaper.setWallpaperOnAllMonitors // true' "$SETTINGS" 2>/dev/null || echo true)

is_portrait() {
    case "$(hyprctl monitors -j | jq -r --arg o "$1" '.[] | select(.name == $o) | .transform')" in
        1 | 3 | 5 | 7) return 0 ;;
        *) return 1 ;;
    esac
}

apply() {
    local output=$1
    if [[ "$all_monitors" == "true" ]] && is_portrait "$output"; then
        return 0
    fi
    case "$SRC" in
        solid://*)
            local hex=${SRC#solid://}
            hex=${hex#\#}
            # Qt writes an alpha colour as #AARRGGBB; awww wants RRGGBB[AA].
            [[ ${#hex} -eq 8 ]] && hex="${hex:2}${hex:0:2}"
            awww clear "$hex" --outputs "$output"
            ;;
        *)
            [[ -f "$SRC" ]] || return 0
            # Noctalia re-emits on dark-mode flips; don't replay a transition
            # for the image that's already up.
            if awww query 2>/dev/null | grep -F ": $output:" | grep -qF "$SRC"; then
                return 0
            fi
            awww img "$SRC" --outputs "$output" --resize crop \
                --transition-type wipe --transition-fps 60
            ;;
    esac
}

if [[ -n "$SCREEN" ]]; then
    apply "$SCREEN"
else
    while read -r output; do
        apply "$output"
    done < <(hyprctl monitors -j | jq -r '.[].name')
fi
