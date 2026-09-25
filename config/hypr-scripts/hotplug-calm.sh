#!/usr/bin/env bash
#
# hotplug-calm.sh — turn animations back on once monitor hotplug settles.
#
# hyprland.lua switches animations off on every monitor.added/removed, so the
# windows Hyprland migrates between outputs jump into place instead of flying
# across from where the vanished monitor used to be. A flaky USB-C dock can
# flap for tens of seconds, firing an event every couple of seconds; each
# event runs this, and only the run holding the newest stamp re-enables, so
# animations stay off until the flapping has been quiet for $SETTLE seconds.

set -euo pipefail

SETTLE=2
STAMP="${XDG_RUNTIME_DIR:-/tmp}/hypr/hotplug-calm"
# gaming-toggle.sh keeps animations off for the whole of gaming mode, and
# its own monitor disabling fires these same events.
GAMING_STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprland-gaming-mode"

mkdir -p "$(dirname "$STAMP")"
token="$$-$(date +%s%N)"
printf '%s\n' "$token" >"$STAMP"

sleep "$SETTLE"

[[ "$(cat "$STAMP" 2>/dev/null)" == "$token" ]] || exit 0
[[ -f "$GAMING_STATE_FILE" ]] && exit 0

# eval, not keyword — keyword is rejected by the Lua config parser.
hyprctl eval 'hl.config({ animations = { enabled = true } })' >/dev/null
