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
for bin in pandoc google-chrome-stable awww python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "shortcuts-wallpaper: '$bin' not found, skipping" >&2
    exit 0
  fi
done

mkdir -p "$CACHE"

# Split markdown at the first ## heading that should start the right column.
# Left column: Window Manager + Tmux. Right column: everything from ## Zsh on.
# The path goes in via the environment — never interpolate shell strings into
# Python source.
export SHORTCUTS_SRC="$SRC"
LEFT_MD=$(python3 -c '
import os, re
md = open(os.environ["SHORTCUTS_SRC"]).read()
m = re.search(r"^## Zsh", md, re.MULTILINE)
# header block = H1 + intro paragraph (everything before first ## section)
hdr_end = re.search(r"^## ", md, re.MULTILINE).start()
print(md[hdr_end:m.start()], end="")
')
RIGHT_MD=$(python3 -c '
import os, re
md = open(os.environ["SHORTCUTS_SRC"]).read()
m = re.search(r"^## Zsh", md, re.MULTILINE)
print(md[m.start():], end="")
')
HEADER_MD=$(python3 -c '
import os, re
md = open(os.environ["SHORTCUTS_SRC"]).read()
hdr_end = re.search(r"^## ", md, re.MULTILINE).start()
print(md[:hdr_end], end="")
')

LEFT_HTML=$(printf '%s' "$LEFT_MD"   | pandoc -f gfm -t html)
RIGHT_HTML=$(printf '%s' "$RIGHT_MD"  | pandoc -f gfm -t html)
HEADER_HTML=$(printf '%s' "$HEADER_MD" | pandoc -f gfm -t html)

# Build a self-contained page with explicit flexbox columns — avoids
# headless-Chrome CSS multi-column rendering bugs.
{
  printf '<!DOCTYPE html><html><head><meta charset="utf-8">'
  printf '<link rel="stylesheet" href="file://%s"></head><body>' "$CSS"
  printf '<div class="header">%s</div>' "$HEADER_HTML"
  printf '<div class="cols">'
  printf '<div class="col">%s</div>' "$LEFT_HTML"
  printf '<div class="col-rule"></div>'
  printf '<div class="col">%s</div>' "$RIGHT_HTML"
  printf '</div>'
  printf '</body></html>'
} >"$HTML"

# Render at the monitor's portrait resolution. Isolated profile so this never
# touches the user's real Chrome session.
google-chrome-stable \
  --headless=new --disable-gpu --hide-scrollbars \
  --user-data-dir="$CACHE/chrome-shot" \
  --window-size=2160,3840 \
  --screenshot="$PNG" "file://$HTML" >/dev/null 2>&1

# Image is already 2160x3840, so crop is an exact 1:1 fit on the rotated output.
awww img "$PNG" --outputs "$OUTPUT" --resize crop \
  --transition-type wipe --transition-fps 60
