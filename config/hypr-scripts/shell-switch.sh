#!/usr/bin/env bash
#
# shell-switch.sh — swap the active desktop shell.
#
# Three shells are installed: this config's own Quickshell panels (+ Waybar),
# Noctalia and DMS (DankMaterialShell). They are mutually exclusive
# — every one of them claims org.freedesktop.Notifications — so exclusion is
# enforced by Conflicts= in the systemd user units, NOT here. Starting one unit
# stops whichever was running; this script only picks a target, records it and
# reports. Units live in modules/home/wm/shell-switcher.nix.
#
# The recorded choice is re-applied at login by shell-restore.service, so a
# switch survives logout.
#
#   shell-switch.sh set <own|noctalia|dms>
#   shell-switch.sh cycle     # next in the list above, wrapping
#   shell-switch.sh current   # print the recorded shell name
#   shell-switch.sh unit      # print the systemd unit of the recorded shell
#   shell-switch.sh restore   # start the recorded shell (login, gaming-mode exit)

set -euo pipefail

SHELLS=(own noctalia dms)
DEFAULT_SHELL=own

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="$STATE_DIR/active-shell"

is_known() {
    local candidate=$1 s
    for s in "${SHELLS[@]}"; do
        [[ "$s" == "$candidate" ]] && return 0
    done
    return 1
}

unit_for() { printf 'shell-%s.service' "$1"; }

# The recorded shell, falling back to the default when the state file is
# missing or holds something no longer in SHELLS (e.g. a renamed entry).
current() {
    local recorded=""
    [[ -f "$STATE_FILE" ]] && read -r recorded < "$STATE_FILE" 2>/dev/null || true
    if is_known "${recorded:-}"; then
        printf '%s\n' "$recorded"
    else
        printf '%s\n' "$DEFAULT_SHELL"
    fi
}

# Hyprland's own OSD, deliberately not notify-send: during a swap the outgoing
# shell's notification daemon is already gone and the incoming one hasn't
# claimed the bus name yet, so a desktop notification would be dropped (or
# would hang waiting on DBus activation).
announce() {
    hyprctl notify -1 2000 "0" "Shell → $1" >/dev/null 2>&1 || true
}

# Caffeine on by default. Waybar's idle_inhibitor has start-activated for the
# own shell, but neither third-party shell persists its toggle, so flip theirs
# over IPC once they are up. Backgrounded and retried: the start above is
# --no-block, so the shell is not listening yet.
caffeine_on() {
    local target=$1
    [[ "$target" == "own" ]] && return 0

    (
        for _ in $(seq 20); do
            case "$target" in
                noctalia) noctalia-shell ipc call idleInhibitor enable ;;
                dms)      dms ipc inhibit enable ;;
                *)        exit 0 ;;
            esac >/dev/null 2>&1 && exit 0
            sleep 0.5
        done
    ) >/dev/null 2>&1 &
}

set_shell() {
    local want=$1
    if ! is_known "$want"; then
        printf 'shell-switch: unknown shell %q (want one of: %s)\n' \
            "$want" "${SHELLS[*]}" >&2
        exit 1
    fi

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$want" > "$STATE_FILE"

    # Conflicts= tears down the outgoing shell as part of this transaction.
    # --no-block: `restore` runs from inside a unit this same user manager
    # is starting, and a blocking start there would deadlock on its own job.
    systemctl --user --no-block start "$(unit_for "$want")"
    caffeine_on "$want"
    announce "$want"
}

cycle() {
    local cur idx=0 i
    cur=$(current)
    for i in "${!SHELLS[@]}"; do
        [[ "${SHELLS[$i]}" == "$cur" ]] && idx=$i && break
    done
    set_shell "${SHELLS[$(( (idx + 1) % ${#SHELLS[@]} ))]}"
}

case "${1:-}" in
    set)     set_shell "${2:?shell-switch: set needs a shell name}" ;;
    cycle)   cycle ;;
    current) current ;;
    unit)    unit_for "$(current)" ;;
    restore)
        systemctl --user --no-block start "$(unit_for "$(current)")"
        caffeine_on "$(current)"
        ;;
    *)
        printf 'usage: shell-switch.sh {set <%s>|cycle|current|unit|restore}\n' \
            "$(IFS='|'; echo "${SHELLS[*]}")" >&2
        exit 1
        ;;
esac
