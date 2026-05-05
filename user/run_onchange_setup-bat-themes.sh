#!/bin/bash
# bat cache rebuild — gruvbox-dark is built-in, no download needed.
# This script ensures the cache is fresh after any custom themes are added manually.
# chezmoi re-runs this when the file content changes — bump the hash below to force a rebuild.
# hash: 2

set -euo pipefail

bat cache --build
echo "bat cache rebuilt. Active theme: ${BAT_THEME:-gruvbox-dark}"
