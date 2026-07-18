#!/usr/bin/env bash
# emoji-picker.sh — fuzzel-driven emoji + glyph picker via bemoji. Copies the
# chosen glyph to the Wayland clipboard and shows a confirmation. Bound to
# Super+Period (mirrors the GNOME/Windows emoji shortcut).
set -euo pipefail

# bemoji auto-detects the installed picker (fuzzel here) and keeps a
# frecency-ranked history so recent picks float to the top. By default it pipes
# the pick straight to wl-copy with no stdout; BEMOJI_DEFAULT_CMD=cat routes it
# to stdout instead so we own the clipboard + notification (as color-picker.sh
# does). -n drops the trailing newline.
export BEMOJI_DEFAULT_CMD="cat"
glyph="$(bemoji -n)" || exit 0
[ -z "$glyph" ] && exit 0

printf '%s' "$glyph" | wl-copy
notify-send -a "Emoji picker" "$glyph" "Copied to clipboard"
