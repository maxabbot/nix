#!/usr/bin/env bash
# list-apps.sh — Output installed desktop applications as "Name\tExec" pairs for AppLauncher.qml.
set -uo pipefail

for dir in \
    /run/current-system/sw/share/applications \
    /etc/profiles/per-user/max/share/applications \
    "$HOME/.local/share/applications"
do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        grep -q "^Type=Application" "$f" 2>/dev/null || continue
        grep -q "^NoDisplay=true"   "$f" 2>/dev/null && continue
        name=$(grep -m1 "^Name=" "$f" | cut -d= -f2-)
        exc=$(grep -m1 "^Exec=" "$f" | sed 's/^Exec=//;s/ *%[A-Za-z]//g' | awk '{print $1}')
        [ -z "$name" ] && continue
        [ -z "$exc"  ] && continue
        printf '%s\t%s\n' "$name" "$exc"
    done < <(find "$dir" -maxdepth 1 -name "*.desktop" -type f 2>/dev/null)
done | sort -u
