#!/usr/bin/env bash
# shortcuts-wallpaper.sh — render ~/.config/hypr/shortcuts.md into a portrait
# Gruvbox cheat-sheet PNG and set it as the wallpaper on the given output
# (used for the rotated 4K secondary monitor).
#
# Usage: shortcuts-wallpaper.sh <connector>     e.g. shortcuts-wallpaper.sh DP-2
set -euo pipefail

OUTPUT="${1:?usage: shortcuts-wallpaper.sh <connector>}"

SRC="$HOME/.config/hypr/shortcuts.md"
CSS="$HOME/.config/hypr/shortcuts.css"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
HTML="$CACHE/shortcuts.html"
PNG="$CACHE/shortcuts-wallpaper.png"

# Need pandoc (md->html), Chrome (html->png) and awww (set wallpaper). If any
# is missing, bail quietly so Hyprland startup is never blocked.
for bin in pandoc google-chrome-stable awww; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "shortcuts-wallpaper: '$bin' not found, skipping" >&2
    exit 0
  fi
done

mkdir -p "$CACHE"

# Build a self-contained page (own wrapper so pandoc's standalone template,
# title block, etc. don't interfere with the stylesheet).
{
  printf '<!DOCTYPE html><html><head><meta charset="utf-8">'
  printf '<link rel="stylesheet" href="file://%s"></head><body>' "$CSS"
  pandoc "$SRC" -f gfm -t html
  printf '</body></html>'
} >"$HTML"

# Render at the monitor's portrait resolution. Isolated profile so this never
# touches the user's real Chrome session.
google-chrome-stable \
  --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
  --user-data-dir="$CACHE/chrome-shot" \
  --window-size=2160,3840 \
  --screenshot="$PNG" "file://$HTML" >/dev/null 2>&1

# Image is already 2160x3840, so crop is an exact 1:1 fit on the rotated output.
awww img "$PNG" --outputs "$OUTPUT" --resize crop \
  --transition-type wipe --transition-fps 60
