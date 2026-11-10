#!/usr/bin/env bash
#
# tv-fit.sh — give an unknown TV a usable mode and scale.
#
# A screen no kanshi profile names gets the catch-all rule (monitors.fallback:
# preferred mode, auto scale). On a TV both are wrong: TVs commonly advertise
# 4K@30 as preferred (the living-room Samsung did), and Hyprland's auto scale
# is PPI-based, so a large panel always comes out at 1x — tiny text from the
# sofa. `highres` doesn't help: it treats 4096x2160 and 3840x2160 as
# incomparable, so it can land on DCI 4K@24/30.
#
# So, once kanshi has settled on its generic external/external-lid profile
# (the exact profiles — the office desk, kanshi.tv — already pin their own),
# any external output that looks like a TV (EDID size >= 32" diagonal, or no
# size at all, as projectors and some TVs report) is re-ruled by description:
#   mode  — the most pixels at 49–61 Hz, at most 3840 wide and 16:9, so a
#           4K@30 preference loses to 4K@60, and DCI 4096 or a 4K@120 the HDMI
#           expansion card can't carry is never picked. No such mode: unchanged.
#   scale — ~1080p logical: 2 at 2160 lines, 1.25 at 1440, else 1.
#   position — centred above, like the fallback.
# kanshi's generic profiles set nothing on that output, so they keep this.
# The rule is runtime-only (hyprctl eval) and keyed by description, so it
# lasts until the next config reload and touches no other screen.
#
# hyprland.lua runs this on every monitor.added. A no-op without kanshi.

set -euo pipefail

KANSHI_WAIT=30
MIN_DIAG_IN=32

systemctl --user is-active --quiet kanshi || exit 0

since=$(($(date +%s) - 1))
sleep 1

# Wait for kanshi's modeset (as dock-kick.sh does), so its profile is current.
for _ in $(seq "$KANSHI_WAIT"); do
    journalctl --user -u kanshi --since "@$since" -o cat -q 2>/dev/null |
        grep -q '^configuration for profile .* applied' && break
    sleep 0.1
done

profile=$(kanshictl status 2>/dev/null | jq -r '.current_profile // empty')
case "$profile" in
external | external-lid) ;;
*) exit 0 ;;
esac

hyprctl monitors -j | jq -c --argjson min "$MIN_DIAG_IN" '
    .[]
    | select(.name | startswith("eDP") | not)
    | select(
        (.physicalWidth == 0 or .physicalHeight == 0)
        or ((((.physicalWidth * .physicalWidth) + (.physicalHeight * .physicalHeight)) | sqrt) / 25.4 >= $min)
      )
    | . as $m
    | ([.availableModes[]
        | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz$")
        | {w: (.w | tonumber), h: (.h | tonumber), r: (.r | tonumber)}
        | select(.w <= 3840 and .r >= 49 and .r <= 61 and (.w * 9 - .h * 16 | fabs) <= 16)
      ] | sort_by(.w * .h, .r) | last) as $best
    | {
        name: $m.name,
        desc: $m.description,
        cur: {w: $m.width, h: $m.height, r: $m.refreshRate, s: $m.scale},
        best: $best
      }' |
    while read -r out; do
        desc=$(jq -r '.desc' <<<"$out")
        # Lua long brackets below: a description containing them can't be quoted.
        [[ "$desc" == *"]]"* ]] && continue

        if [[ "$(jq '.best != null' <<<"$out")" == "true" ]]; then
            w=$(jq -r '.best.w' <<<"$out")
            h=$(jq -r '.best.h' <<<"$out")
            mode="${w}x${h}@$(jq -r '.best.r' <<<"$out")"
        else
            h=$(jq -r '.cur.h' <<<"$out")
            mode="preferred"
        fi

        if ((h >= 2160)); then
            scale=2
        elif ((h >= 1440)); then
            scale=1.25
        else
            scale=1
        fi

        # Already fitted (a replug, or a second monitor.added): leave it.
        if jq -e --arg s "$scale" --arg m "$mode" '
            ($m == "preferred" or ($m | startswith("\(.cur.w)x\(.cur.h)@")))
            and ((.cur.s - ($s | tonumber)) | fabs) < 0.01
            and (.best == null or ((.cur.r - .best.r) | fabs) < 0.5)' <<<"$out" >/dev/null; then
            continue
        fi

        hyprctl eval "hl.monitor({ output = [[desc:$desc]], mode = \"$mode\", position = \"auto-center-up\", scale = $scale })" >/dev/null
    done
