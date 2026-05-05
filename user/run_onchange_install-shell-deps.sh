#!/bin/bash
# chezmoi run_onchange script — sets default shell to zsh and installs antidote
# antidote is installed via git clone (recommended method); plugins managed via ~/.zsh_plugins.txt

set -euo pipefail

if [[ "$SHELL" != */zsh ]]; then
  echo "Changing default shell to zsh..."
  chsh -s "$(which zsh)" || echo "Could not change shell automatically. Run: chsh -s $(which zsh)"
fi

if [[ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]]; then
  echo "Installing antidote..."
  git clone --depth=1 https://github.com/mattmc3/antidote.git "${ZDOTDIR:-$HOME}/.antidote"
fi

echo "Shell setup complete!"
