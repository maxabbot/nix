#!/bin/bash
# Turn every monitor back on. Used as hypridle's after_sleep_cmd.
#
# `hyprctl dispatch dpms on` does NOT work: dispatch args are evaluated as Lua,
# so the bare word `on` is a parse error ("')' expected near 'on'") and the
# monitors silently stay dark after resume.
#
# The hl.dsp.dpms dispatch also IGNORES its state arg and simply TOGGLES on
# every call, so we can't set an absolute state blindly — read each monitor's
# dpmsStatus and toggle ONLY the ones that are currently off. Same approach as
# dpms_set() in gaming-toggle.sh.
set -euo pipefail

hyprctl monitors all -j \
    | jq -r '.[] | select(.dpmsStatus == false) | .name' \
    | while read -r mon; do
        hyprctl dispatch "hl.dsp.dpms{monitor=\"$mon\", state=\"toggle\"}" >/dev/null 2>&1 || true
        sleep 0.4
    done
