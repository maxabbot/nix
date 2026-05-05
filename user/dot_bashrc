# ============================================================================
# Bash Configuration - Feature-Rich Setup
# ============================================================================

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ============================================================================
# Shell Options
# ============================================================================
shopt -s checkwinsize        # Check window size after each command
shopt -s histappend          # Append to history file
shopt -s cmdhist             # Save multi-line commands in one history entry
shopt -s cdspell             # Autocorrect typos in path names when using cd
shopt -s dirspell            # Autocorrect directory names during completion
shopt -s nocaseglob          # Case-insensitive globbing
shopt -s extglob             # Extended pattern matching
shopt -s dotglob             # Include hidden files in pathname expansion

# ============================================================================
# History Configuration
# ============================================================================
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT="%F %T "
HISTIGNORE="ls:ll:la:cd:pwd:exit:clear:history"

# Append to history file immediately
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# ============================================================================
# Environment Variables
# ============================================================================

# Set default editor
export EDITOR='nvim'
export VISUAL='nvim'

# Language environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ============================================================================
# Language-Specific Configurations
# ============================================================================

# Python
export PYTHONPATH="$HOME/.local/lib/python3.11/site-packages:$PYTHONPATH"
export PIP_REQUIRE_VIRTUALENV=false

# Rust
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
[[ -f "$CARGO_HOME/env" ]] && source "$CARGO_HOME/env"

# Node.js (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Go (if installed)
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# ============================================================================
# Path Modifications
# ============================================================================
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$CARGO_HOME/bin:$PATH"

# ============================================================================
# Prompt Configuration (Powerline-style)
# ============================================================================

# Color definitions
RED='\[\033[0;31m\]'
GREEN='\[\033[0;32m\]'
YELLOW='\[\033[0;33m\]'
BLUE='\[\033[0;34m\]'
MAGENTA='\[\033[0;35m\]'
CYAN='\[\033[0;36m\]'
WHITE='\[\033[0;37m\]'
BOLD='\[\033[1m\]'
RESET='\[\033[0m\]'

# Git prompt function
parse_git_branch() {
  git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Virtual environment indicator
show_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "($(basename "$VIRTUAL_ENV")) "
  fi
}

# Custom prompt with git support
PS1="${CYAN}\$(show_virtualenv)${GREEN}\u@\h${RESET}:${BLUE}\w${YELLOW}\$(parse_git_branch)${RESET}\$ "

# ============================================================================
# Aliases - General
# ============================================================================

# System & Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Editor shortcuts
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Package management (Arch)
alias pacup='sudo pacman -Syu'
alias pacin='sudo pacman -S'
alias pacrem='sudo pacman -Rns'
alias pacsearch='pacman -Ss'
alias pacinfo='pacman -Qi'
alias pacclean='sudo pacman -Sc'
alias yayup='yay -Syu'
alias yayin='yay -S'

# System management
alias srestart='sudo systemctl restart'
alias sstatus='sudo systemctl status'
alias senable='sudo systemctl enable'
alias sdisable='sudo systemctl disable'
alias jctl='journalctl -xe'

# Quick shortcuts
alias c='clear'
alias h='history'
alias j='jobs -l'
alias ports='netstat -tulanp'

# ============================================================================
# Aliases - Development
# ============================================================================

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gb='git branch'
alias gba='git branch -a'

# Docker
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dim='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'
alias drmi='docker rmi $(docker images -q)'

# Podman
alias p='podman'
alias pps='podman ps'
alias pim='podman images'

# Python
alias py='python'
alias py3='python3'
alias pip='pip3'
alias venv='python -m venv'
alias activate='source venv/bin/activate'

# Rust
alias c='cargo'
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias cu='cargo update'

# Node/NPM
alias nr='npm run'
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias nt='npm test'
alias nb='npm run build'
alias ns='npm start'

# Yarn
alias y='yarn'
alias yi='yarn install'
alias ya='yarn add'
alias yad='yarn add --dev'
alias yr='yarn run'
alias yt='yarn test'
alias yb='yarn build'

# ============================================================================
# Custom Functions
# ============================================================================

# Create and enter directory
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extract archives
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Quick find
qfind() {
  find . -iname "*$1*"
}

# Process search
psgrep() {
  ps aux | grep -v grep | grep -i -e VSZ -e "$1"
}

# Git clone and enter
gcl() {
  git clone "$1" && cd "$(basename "$1" .git)"
}

# Create Python virtual environment and activate
mkvenv() {
  python -m venv "${1:-.venv}" && source "${1:-.venv}/bin/activate"
}

# Quick HTTP server
serve() {
  python -m http.server "${1:-8000}"
}

# System update function
sysup() {
  echo "Updating system packages..."
  sudo pacman -Syu
  if command -v yay &> /dev/null; then
    echo "Updating AUR packages..."
    yay -Syu
  fi
  if command -v cargo &> /dev/null; then
    echo "Updating Rust toolchain..."
    rustup update
  fi
  echo "Update complete!"
}

# Docker cleanup
dclean() {
  echo "Cleaning Docker containers, images, volumes..."
  docker system prune -af --volumes
}

# Fast directory navigation with fzf (if installed)
if command -v fzf &> /dev/null; then
  fd() {
    local dir
    dir=$(find ${1:-.} -type d 2> /dev/null | fzf +m) && cd "$dir"
  }
fi

# ============================================================================
# Completion Enhancements
# ============================================================================

# Enable bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Git completion
if [ -f /usr/share/git/completion/git-completion.bash ]; then
  source /usr/share/git/completion/git-completion.bash
fi

# ============================================================================
# Additional Tools
# ============================================================================

# Enable zoxide (better cd) if installed
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

# Enable direnv if installed
if command -v direnv &> /dev/null; then
  eval "$(direnv hook bash)"
fi

# Enable fzf if installed
if [ -f /usr/share/fzf/key-bindings.bash ]; then
  source /usr/share/fzf/key-bindings.bash
fi
if [ -f /usr/share/fzf/completion.bash ]; then
  source /usr/share/fzf/completion.bash
fi

# ============================================================================
# Color Output for Common Commands
# ============================================================================

# Colored man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# ============================================================================
# Local Overrides
# ============================================================================
# Load local bash config if it exists (for machine-specific settings)
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
