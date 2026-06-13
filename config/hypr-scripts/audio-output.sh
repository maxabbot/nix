#!/usr/bin/env bash
# audio-output.sh — fuzzel picker to switch the active audio output.
#
# The NVIDIA GPU exposes one HDMI audio codec shared by all its HDMI ports,
# and ALSA only lets ONE HDMI port be active at a time (each is a separate
# card *profile*). So switching between HDMI displays means flipping the card
# profile, not just picking a sink. This script presents every available HDMI
# port (named after the connected display) plus any other live sink (analog,
# USB, Bluetooth), then on selection:
#   • switches the GPU card profile if an HDMI port was chosen,
#   • sets it as the default sink,
#   • moves all currently-playing streams onto it.
set -euo pipefail

# Build the menu. Each line: "<label>\t<action>". Action fields are '|'-delimited
# (profile names contain ':', so ':' can't be the separator):
#   profile|<card>|<profile>|<sink>   (HDMI — switch profile then default)
#   sink|<sink>                       (already-active sink — just switch)
build_menu() {
    # 1. NVIDIA HDMI ports — the card whose block carries hdmi-output ports.
    local card cardout=""
    while read -r _ card _; do
        if pactl list cards | awk -v c="$card" '
            $1=="Name:" {cur=($2==c)}
            cur && /hdmi-output-[0-9]+: / {found=1}
            END {exit !found}'; then
            cardout="$card"
            break
        fi
    done < <(pactl list cards short)

    if [[ -n "$cardout" ]]; then
        local sinkpre="${cardout/alsa_card/alsa_output}"
        # Walk this card's available hdmi-output-N ports. Ports have no blank-line
        # separators, so emit on the "Part of profile(s):" line (which also gives
        # the exact stereo profile name) and at end-of-block.
        pactl list cards | awk -v c="$cardout" '
            function flush() {
                if (idx!="" && avail && prof!="") print idx"\t"name"\t"prof
                idx=""; avail=0; name=""; prof=""
            }
            $1=="Name:" {flush(); cur=($2==c)}
            !cur {next}
            /hdmi-output-[0-9]+: / {
                flush()
                idx=$1; sub(/hdmi-output-/,"",idx); sub(/:/,"",idx)
                avail=($0 ~ /available\)/ && $0 !~ /not available/)
            }
            /device.product.name = / {
                if (name=="") { line=$0; sub(/.*= "/,"",line); sub(/"$/,"",line); name=line }
            }
            $1=="Part" && $3=="profile(s):" {
                prof=$4; sub(/,$/,"",prof)   # first profile = stereo variant
                flush()
            }
            END {flush()}
        ' | while IFS=$'\t' read -r idx name prof; do
            local sink="$sinkpre.${prof#output:}"
            local hn=$((idx + 1))
            printf '%s (HDMI %s)\tprofile|%s|%s|%s\n' \
                "${name:-Display}" "$hn" "$cardout" "$prof" "$sink"
        done
    fi

    # 2. Every other currently-active sink (analog, USB, Bluetooth, …).
    pactl list sinks short | while read -r _ sink _; do
        [[ "$sink" == ${sinkpre:-__none__}.* ]] && continue   # skip GPU HDMI sinks
        local desc
        desc=$(pactl list sinks | awk -v s="$sink" '
            $1=="Name:" {cur=($2==s)}
            cur && $1=="Description:" {sub(/^[[:space:]]*Description:[[:space:]]*/,""); print; exit}')
        printf '%s\tsink|%s\n' "${desc:-$sink}" "$sink"
    done
}

main() {
    local menu choice action
    menu=$(build_menu)
    [[ -z "$menu" ]] && { notify-send "Audio" "No outputs found"; exit 1; }

    choice=$(cut -f1 <<<"$menu" | fuzzel --dmenu --prompt "Audio out: ") || exit 0
    action=$(awk -F'\t' -v c="$choice" '$1==c {print $2; exit}' <<<"$menu")
    [[ -z "$action" ]] && exit 0

    local sink
    case "$action" in
        profile\|*)
            IFS='|' read -r _ card prof sink <<<"$action"
            pactl set-card-profile "$card" "$prof"
            sleep 0.3
            ;;
        sink\|*)
            sink="${action#sink|}"
            ;;
    esac

    pactl set-default-sink "$sink"
    # Move every live stream onto the new default.
    pactl list sink-inputs short | while read -r id _; do
        pactl move-sink-input "$id" "$sink" 2>/dev/null || true
    done

    notify-send "Audio output" "→ ${choice}"
}

main "$@"
