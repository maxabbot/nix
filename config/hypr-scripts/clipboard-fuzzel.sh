#!/usr/bin/env bash
# clipboard-fuzzel.sh — cliphist history picker via fuzzel.
#
# Improvements over the old `cliphist list | fuzzel -d | …` one-liner:
#   • Image entries are decoded to a thumbnail and shown inline (fuzzel's
#     dmenu icon protocol) instead of an opaque "[[ binary data … ]]" line.
#   • Cancelling (Esc / focus loss) is a clean no-op.
#   • Roomier window tuned for history browsing, without touching the
#     launcher's global fuzzel config.
set -euo pipefail

thumb_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbs"
rm -rf "$thumb_dir"
mkdir -p "$thumb_dir"

# Emit the menu. Each line is the raw `<id>\t<preview>` cliphist entry; image
# entries get a `\0icon\x1f<path>` suffix pointing at a decoded thumbnail.
menu() {
    cliphist list | while IFS=$'\t' read -r id preview; do
        if [[ "$preview" == *"binary data"* ]]; then
            ext=$(printf '%s' "$preview" | grep -oiE '(png|jpe?g|gif|bmp|webp)' | head -n1)
            if [[ -n "$ext" ]]; then
                img="$thumb_dir/$id.$ext"
                if printf '%s' "$id" | cliphist decode >"$img" 2>/dev/null; then
                    printf '%s\t%s\0icon\x1f%s\n' "$id" "$preview" "$img"
                    continue
                fi
            fi
        fi
        printf '%s\t%s\n' "$id" "$preview"
    done
}

choice=$(menu | fuzzel --dmenu --prompt='󰅇  ' --placeholder='Search clipboard…' \
    --lines=14 --width=60 || true)

[[ -z "$choice" ]] && exit 0

printf '%s' "$choice" | cliphist decode | wl-copy
