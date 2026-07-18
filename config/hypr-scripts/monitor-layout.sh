#!/usr/bin/env bash
# monitor-layout.sh — persist or clear the Hyprland monitor layout edited from
# the Quickshell Monitors page (quickshell/MonitorManager.qml).
#
# The page applies changes with `hyprctl keyword monitor`, which is session-only:
# they vanish on unplug or reload. "Save layout" snapshots the live state here so
# it survives both.
#
#   save   snapshot every connected output's mode/position/scale/transform into
#          ~/.config/hypr/monitors-local.lua. monitors.lua loadfile()s that at
#          the end (see modules/home/wm/hyprland.nix), so it overrides the
#          per-host Nix declarations.
#   reset  delete the file and reload, returning to the Nix layout.
#
# Mirrored outputs are skipped deliberately — mirroring is a transient
# meeting-room state, and a persisted mirror is confusing to undo.
set -euo pipefail

OUT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors-local.lua"

case "${1:-}" in
save)
    mkdir -p "$(dirname "$OUT")"
    tmp=$(mktemp "${OUT}.XXXXXX")
    trap 'rm -f "$tmp"' EXIT

    {
        echo "-- Saved from the Quickshell Monitors page. Not managed by Nix."
        echo "-- Press Reset there (or delete this file) to fall back to the"
        echo "-- host layout declared in flake.nix."
        echo ""
        hyprctl monitors -j | jq -r '
            .[]
            | select(.disabled | not)
            | select(.mirrorOf == "none")
            | "hl.monitor({ output = \"\(.name)\""
              + ", mode = \"\(.width)x\(.height)@\(.refreshRate | round)\""
              + ", position = \"\(.x)x\(.y)\""
              + ", scale = \(.scale)"
              + ", transform = \(.transform) })"
        '
    } >"$tmp"

    # A layout with no monitor lines would silently persist nothing — treat an
    # empty snapshot as a failure rather than writing a useless file.
    if ! grep -q '^hl\.monitor' "$tmp"; then
        echo "no usable outputs to save" >&2
        exit 1
    fi

    mv "$tmp" "$OUT"
    trap - EXIT
    echo "saved"
    ;;
reset)
    rm -f "$OUT"
    hyprctl reload >/dev/null
    echo "reset"
    ;;
*)
    echo "usage: ${0##*/} {save|reset}" >&2
    exit 2
    ;;
esac
