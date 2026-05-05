#!/bin/bash
# Install global npm tools via mise-managed node.
# chezmoi re-runs this when the file content changes — bump the hash to upgrade.
# hash: 2

set -euo pipefail

# Activate mise to get its node/npm in PATH
MISE_BIN="${MISE_BIN:-$(command -v mise 2>/dev/null || echo /usr/bin/mise)}"

if [[ ! -x "$MISE_BIN" ]]; then
  echo "mise not found — skipping npm tools (re-run 'chezmoi apply' after mise is installed)"
  exit 0
fi

eval "$("$MISE_BIN" activate bash)"
"$MISE_BIN" install node 2>/dev/null || true

if ! command -v npm &>/dev/null; then
  echo "npm not available after mise activation"
  exit 1
fi

echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

echo "Done. Claude Code: $(claude --version 2>/dev/null || echo 'installed')"
