#!/usr/bin/env bash
# qs_clipboard.sh — Clipboard helper for the Quickshell ClipboardManager panel.
# Usage: qs_clipboard.sh <copy|delete> <entry-id>
#        qs_clipboard.sh wipe
set -euo pipefail

ACTION=${1:-}
ENTRY_ID=${2:-}

case "$ACTION" in
    copy)
        cliphist list | awk -F'\t' -v id="$ENTRY_ID" '$1 == id' | cliphist decode | wl-copy
        ;;
    delete)
        cliphist list | awk -F'\t' -v id="$ENTRY_ID" '$1 == id' | cliphist delete
        ;;
    wipe)
        cliphist wipe
        ;;
esac
