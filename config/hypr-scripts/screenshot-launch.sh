#!/usr/bin/env bash
# Closes the screenshot overlay, waits for the compositor to clear the surface,
# then runs the requested screenshot mode.
MODE="$1"
SCRIPTS="$HOME/.config/hypr/scripts"

bash "$SCRIPTS/qs_manager.sh" close
sleep 0.2

case "$MODE" in
    region)   GEOM=$(slurp 2>/dev/null) && [ -n "$GEOM" ] && bash "$SCRIPTS/screenshot.sh" --geometry "$GEOM" ;;
    annotate) GEOM=$(slurp 2>/dev/null) && [ -n "$GEOM" ] && bash "$SCRIPTS/screenshot.sh" --edit --geometry "$GEOM" ;;
    full)     bash "$SCRIPTS/screenshot.sh" --full ;;
    window)   bash "$SCRIPTS/screenshot.sh" --window ;;
    record)   bash "$SCRIPTS/screenshot.sh" --record --full ;;
    qr)       bash "$SCRIPTS/screenshot.sh" --scan-qr-notify ;;
esac
