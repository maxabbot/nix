#!/usr/bin/env bash
# Claude Code status line — Starship's segments (user, directory, git branch +
# status, time) plus the model, effort level and context-window usage. Claude
# Code pipes session JSON on stdin and shows what this prints.
#
# Plain ANSI colours, not palette.nix: with the dark-ansi theme (claude.nix)
# kitty renders them in Gruvbox, so there is nothing to template.
set -euo pipefail

input=$(cat)
field() { jq -r "$1 // empty" <<<"$input"; }
seg() { printf '\033[%sm%s\033[0m' "$1" "$2"; }

cwd=$(field '.workspace.current_dir // .cwd')
model=$(field .model.display_name)
effort=$(field .effort.level) # absent for models without effort levels
used=$(field .context_window.used_percentage)

# ~ for $HOME, and only the last three components behind …/ (Starship's
# truncation_length / truncation_symbol)
dir=${cwd/#"$HOME"/\~}
IFS=/ read -ra parts <<<"$dir"
if ((${#parts[@]} > 3)); then
  dir="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
fi

out="$(seg 37 "$(id -un)") $(seg 34 "$dir")"

# --no-optional-locks: this runs on every refresh, alongside the session's own git
if [[ -n $cwd ]] && branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null); then
  porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null || true)
  state=
  grep -q '^[MARC]' <<<"$porcelain" && state+='+'
  grep -q '^.[MD]' <<<"$porcelain" && state+='!'
  grep -q '^??' <<<"$porcelain" && state+='?'
  out+=" $(seg 32 $''" $branch") $(seg 31 "${state:-✓}")"
fi

[[ -n $model ]] && out+=" $(seg 35 "$model")"
[[ -n $effort ]] && out+=" $(seg 36 "$effort")"

if [[ -n $used ]]; then
  pct=$(printf '%.0f' "$used")
  colour=32
  ((pct >= 60)) && colour=33
  ((pct >= 85)) && colour=31
  out+=" $(seg "$colour" "ctx $pct%")"
fi

printf '%s %s' "$out" "$(seg 90 $'\U000f0954'" $(date +%H:%M)")"
