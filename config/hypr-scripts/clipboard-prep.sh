#!/usr/bin/env bash
# clipboard-prep.sh — emit cliphist history as JSON lines for ClipboardPanel.qml.
#
# One JSON object per line: { id, kind: text|image|binary, preview, full?, thumb? }
#   • image entries are decoded to a thumbnail file under the quickshell cache
#   • text entries are decoded in full (capped at 4000 chars) so the panel can
#     show the whole entry when a row is hover-expanded
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "clipboard"

thumb_dir="$QS_CACHE_CLIPBOARD/thumbs"
rm -rf "$thumb_dir"
mkdir -p "$thumb_dir"
export CLIP_THUMB_DIR="$thumb_dir"

python3 - <<'EOF'
import json, os, re, subprocess

thumb_dir = os.environ["CLIP_THUMB_DIR"]
listing = subprocess.run(["cliphist", "list"], capture_output=True)
lines = listing.stdout.decode("utf-8", "replace").splitlines()[:60]

def decode(entry_id):
    return subprocess.run(["cliphist", "decode"], input=entry_id.encode(),
                          capture_output=True).stdout

for line in lines:
    if "\t" not in line:
        continue
    entry_id, preview = line.split("\t", 1)
    entry = {"id": entry_id, "preview": preview.strip()}

    if "binary data" in preview:
        ext = re.search(r"\b(png|jpe?g|gif|bmp|webp)\b", preview, re.I)
        if ext:
            path = os.path.join(thumb_dir, f"{entry_id}.{ext.group(1).lower()}")
            with open(path, "wb") as f:
                f.write(decode(entry_id))
            entry.update(kind="image", thumb=path)
        else:
            entry["kind"] = "binary"
    else:
        text = decode(entry_id).decode("utf-8", "replace")
        if len(text) > 4000:
            text = text[:4000] + " …"
        entry.update(kind="text", full=text)

    print(json.dumps(entry, ensure_ascii=False))
EOF
