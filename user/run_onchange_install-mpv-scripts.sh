#!/bin/bash
# Download mpv scripts: uosc (UI), thumbfast (thumbnail scrubber), sponsorblock.
# chezmoi re-runs this when the file content changes — bump the hash to update.
# hash: 3

set -uo pipefail

SCRIPTS_DIR="$HOME/.config/mpv/scripts"
OPTS_DIR="$HOME/.config/mpv/script-opts"
mkdir -p "$SCRIPTS_DIR" "$OPTS_DIR"

FAILED=()

echo "Installing uosc..."
UOSC_URL="https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip"
UOSC_TMP="$(mktemp /tmp/uosc.XXXXXX.zip)"
if curl -fsSL "$UOSC_URL" -o "$UOSC_TMP" && unzip -o -q "$UOSC_TMP" -d "$HOME/.config/mpv/"; then
  rm -f "$UOSC_TMP"
  echo "uosc installed."
else
  rm -f "$UOSC_TMP"
  echo "WARNING: uosc download failed — check the release URL and re-run 'chezmoi apply'"
  FAILED+=("uosc ($UOSC_URL)")
fi

echo "Installing thumbfast..."
if curl -fsSL "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua" \
    -o "$SCRIPTS_DIR/thumbfast.lua"; then
  echo "thumbfast installed."
else
  echo "WARNING: thumbfast download failed"
  FAILED+=("thumbfast")
fi

echo "Installing sponsorblock..."
if curl -fsSL "https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua" \
    -o "$SCRIPTS_DIR/sponsorblock.lua" && \
   curl -fsSL "https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock_shared/main.lua" \
    -o "$SCRIPTS_DIR/sponsorblock_shared.lua"; then
  echo "sponsorblock installed."
else
  echo "WARNING: sponsorblock download failed"
  FAILED+=("sponsorblock")
fi

# Write uosc config (overrides the default from the tarball)
cat > "$OPTS_DIR/uosc.conf" << 'EOF'
# uosc — Gruvbox Material Dark

# Layout
timeline_style=bar
timeline_line_width=2
timeline_size=24
controls=menu,gap,subtitles,<has_many_audio_tracks>audio,<has_many_video_tracks>video,<has_chapter_list>chapters,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
controls_size=32
controls_margin=8
controls_spacing=2
controls_persistency=

# Autohide
autohide=no
flash_duration=1000
proximity_in=40
proximity_out=60

# Appearance
font=FiraCode Nerd Font
font_scale=1
text_border=1.2
border_radius=4

# Colors — Gruvbox Material Dark (0xAARRGGBB)
color_foreground=d4be98
color_foreground_text=282828
color_background=282828
color_background_text=d4be98
color_primary=7daea3
color_error=ea6962

# Thumbnails (thumbfast integration)
thumbnail=yes
thumbnail_max_height=200
EOF

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "mpv scripts partially installed. Failed downloads:"
  printf '  - %s\n' "${FAILED[@]}"
  echo "Re-run 'chezmoi apply' to retry."
else
  echo "mpv scripts installed."
fi
