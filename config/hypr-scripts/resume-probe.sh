#!/bin/bash
# resume-probe.sh — capture what the session looks like across a resume.
#
# Exists because the 2026-09-09 resume failure could not be diagnosed after the
# fact: the screens came back lit and painting but showing nothing, and every
# useful witness was either silent or gone by the time anyone could look.
#
#   - dpms.sh routes every hyprctl through `>/dev/null 2>&1 || true`, so what it
#     decided (and whether it decided to do nothing) leaves no trace at all.
#   - hyprlock only logs on events. It was quiet for the whole 88 minutes it held
#     the lock, so its silence after a resume says nothing either way — which is
#     exactly the inference that sent the first diagnosis down the wrong path.
#   - Hyprland's own log lives in $XDG_RUNTIME_DIR and dies with the reboot. It
#     is the one witness that would have settled things, and it is the one that
#     never survives.
#
# The open question this is built to answer: when the compositor is painting but
# showing nothing, is hyprlock failing to commit its lock surfaces, or is every
# client's buffer stale after the VRAM restore? Those look identical from the
# outside, because the lock covers everything. They do not look identical here:
# a live hyprlock keeps burning CPU and forking a shell every second for
# hyprlock.conf's `cmd[update:1000]` clock, so a stalled event loop shows up as
# CPU ticks that stop advancing while the compositor keeps answering hyprctl.
#
# Deliberately NOT `set -e`. This runs against a session that is already broken,
# where commands failing is the expected case and the failures are the evidence;
# aborting on the first one would throw away the rest of the capture. Every
# external call is instead wrapped in `timeout` and records its own failure —
# a hyprctl that hangs is itself a finding, so it must never hang the probe.
set -uo pipefail

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
LOG="$LOG_DIR/resume-probe.log"

# Sample offsets in seconds from the resume signal. The early ones bracket the
# nvidia-resume wait and dpms.sh; the late ones cover the window in which a user
# would still be staring at a black screen deciding whether to hit the power key
# (20s, on 2026-09-09).
SAMPLES=(0 2 5 10 20 30)

mkdir -p "$LOG_DIR" || exit 0

# Keep the file bounded — this appends on every single resume, forever.
if [ -f "$LOG" ] && [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 4000 ]; then
    tail -n 2000 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

say() { printf '%s\n' "$*" >>"$LOG"; }

# hyprctl, but it can never wedge the probe. Prints the output, or a marker.
hc() {
    local out
    if out=$(timeout 3 hyprctl "$@" 2>&1); then
        printf '%s' "$out"
    else
        printf 'HYPRCTL-FAILED-OR-TIMED-OUT(rc=%s)' "$?"
    fi
}

# Cumulative CPU ticks for a pid. /proc/<pid>/stat's comm field can contain
# spaces and parens, so slice past the final ')' rather than counting fields
# from the left; utime/stime are then fields 12 and 13 of what remains.
cpu_ticks() {
    local stat rest
    stat=$(cat "/proc/$1/stat" 2>/dev/null) || { printf 'n/a'; return; }
    rest=${stat##*') '}
    # shellcheck disable=SC2086 # deliberate word splitting into positionals
    set -- $rest
    printf '%s' "$((${12:-0} + ${13:-0}))"
}

lock_state() {
    local pid
    pid=$(pidof hyprlock 2>/dev/null | awk '{print $1}')
    if [ -z "$pid" ]; then
        printf 'hyprlock: ABSENT'
        return
    fi
    printf 'hyprlock: pid=%s cpu_ticks=%s children=%s' \
        "$pid" "$(cpu_ticks "$pid")" "$(pgrep -P "$pid" 2>/dev/null | wc -l)"
}

monitors() {
    hc monitors all -j \
        | jq -c '.[] | {name, dpmsStatus, disabled, vrr, mode: "\(.width)x\(.height)@\(.refreshRate)"}' \
            2>/dev/null \
        || printf 'monitors: UNPARSEABLE'
}

# What the kernel thinks is plugged in, independent of what Hyprland believes.
# A display in real standby with a dropped link reads "disconnected" here while
# Hyprland may still be listing it as an output that is on.
drm_status() {
    local f
    for f in /sys/class/drm/card*-*/status; do
        [ -r "$f" ] || continue
        local d=${f%/status}
        printf '%s=%s ' "${d##*/}" "$(cat "$f" 2>/dev/null)"
    done
}

{
    say ""
    say "════════════════════════════════════════════════════════════════════"
    say "RESUME $(date -Is)  boot=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
    say "  uptime:$(cut -d' ' -f1 /proc/uptime 2>/dev/null)s  sig=${HYPRLAND_INSTANCE_SIGNATURE:-unset}"
    say "  nvidia-resume: load=$(systemctl show -p LoadState --value nvidia-resume.service 2>/dev/null) active=$(systemctl show -p ActiveState --value nvidia-resume.service 2>/dev/null)"
    say "  drm: $(drm_status)"

    # Where hyprland.log stands right now, so the dump at the end can slice
    # exactly the resume window out of it.
    hl_log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/hyprland.log"
    hl_mark=$(wc -l <"$hl_log" 2>/dev/null || echo 0)

    start=$(date +%s)
    prev=0
    for t in "${SAMPLES[@]}"; do
        now=$(( $(date +%s) - start ))
        [ "$t" -gt "$now" ] && sleep "$((t - prev))"
        prev=$t
        say ""
        say "── t+${t}s ─────────────────────────────────────────────────────────"
        say "  $(lock_state)"
        say "  nvidia-resume: $(systemctl show -p ActiveState --value nvidia-resume.service 2>/dev/null)"
        say "  clients: $(hc clients -j | jq -r 'length' 2>/dev/null || echo '?')"
        while IFS= read -r line; do
            [ -n "$line" ] && say "  mon $line"
        done < <(monitors)
    done

    # The whole reason this script exists: Hyprland's log is the best witness and
    # it does not survive a reboot. Copy the tail somewhere persistent while the
    # session is still up.
    say ""
    if [ -r "$hl_log" ]; then
        say "── hyprland.log, resume window only (from line $hl_mark) ──"
        # Slice from where the log stood when this resume began, so the capture
        # is exactly the resume window however long it took — a fixed tail would
        # get pushed off the top by libinput debounce spam, which is ~30% of the
        # file and never once diagnostic.
        tail -n "+$((hl_mark + 1))" "$hl_log" 2>/dev/null \
            | grep -viE 'debounce|\[libinput\]' \
            | grep -v '^[[:space:]]*$' \
            | head -n 400 \
            | while IFS= read -r line; do say "  | $line"; done
    else
        say "── hyprland.log NOT READABLE at $hl_log ──"
    fi
    say "── end of resume capture ──"
} 2>/dev/null

exit 0
