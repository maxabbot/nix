#!/usr/bin/env bash
#
# shell-ipc.sh — route a panel action to whichever desktop shell is active.
#
# The panel keybinds in config/hypr/hyprland.lua (and waybar's buttons) all
# come through here instead of straight to qs_manager.sh, so SUPER+I opens
# Noctalia's settings under Noctalia, DMS's under DMS, and this config's own
# Settings panel under the own shell.
#
# Where a shell has no counterpart, the action falls back to our own panels —
# they run alongside the third-party shells as shell-utility.service (see
# modules/home/wm/shell-switcher.nix), so the fallback is always available.
#
#   shell-ipc.sh <power|notifications|overview|settings|control|clipboard|screenshot|keybinds|wallpaper>
#
# wallpaper always opens this config's own picker: it is awww-backed, so it
# works under every shell, and Noctalia greys its own pickers out once its
# wallpaper layer is disabled.
#
# Anything else is passed straight through to qs_manager.sh, which is what the
# per-tab waybar buttons (settings audio, settings monitors, …) rely on.

set -euo pipefail

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
    echo "usage: shell-ipc.sh <action> [subtarget]" >&2
    exit 1
fi
shift

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Fall back to this config's own panels. Deployed 0444, so go through bash.
own() { bash "$SCRIPTS_DIR/qs_manager.sh" toggle "$@"; }

case "$(bash "$SCRIPTS_DIR/shell-switch.sh" current)" in
    noctalia)
        case "$ACTION" in
            power)         noctalia-shell ipc call sessionMenu toggle ;;
            notifications) noctalia-shell ipc call notifications toggleHistory ;;
            settings)      noctalia-shell ipc call settings toggle ;;
            control)       noctalia-shell ipc call controlCenter toggle ;;
            clipboard)     noctalia-shell ipc call launcher clipboard ;;
            # Noctalia ships no exposé, screenshot tool or cheat sheet at all.
            overview | screenshot | keybinds | wallpaper) own "$ACTION" ;;
            *) own "$ACTION" "$@" ;;
        esac
        ;;
    dms)
        case "$ACTION" in
            power)         dms ipc powermenu toggle ;;
            notifications) dms ipc notifications toggle ;;
            settings)      dms ipc settings toggle ;;
            control)       dms ipc control-center toggle ;;
            clipboard)     dms ipc clipboard toggle ;;
            overview)      dms ipc hypr toggleOverview ;;
            keybinds)      dms ipc hypr toggleBinds ;;
            # No screenshot IPC target; the CLI is the interface.
            screenshot)    dms screenshot region ;;
            wallpaper)     own "$ACTION" ;;
            *) own "$ACTION" "$@" ;;
        esac
        ;;
    *)
        # own shell (and any unrecognised value — shell-switch.sh already
        # falls back to "own" for those).
        own "$ACTION" "$@"
        ;;
esac
