#!/usr/bin/env bash
# color-picker.sh — eyedropper. Pick a pixel colour with hyprpicker, copy the
# hex to the clipboard, and show a notification swatch. Bound to Super+Shift+P.
set -euo pipefail

# hyprpicker exits non-zero when cancelled (Esc) — swallow it quietly.
hex="$(hyprpicker -f hex)" || exit 0
[ -z "$hex" ] && exit 0

printf '%s' "$hex" | wl-copy
notify-send -a "Color picker" "$hex" "Copied to clipboard"
