#!/usr/bin/env bash
# Claude Code status line — the Starship prompt (modules/home/shell.nix) as
# powerline blocks: user, directory, git branch + status, then Claude's model,
# effort level and context usage in the block where Starship shows language
# versions, then the time. Claude Code pipes session JSON on stdin and shows
# what this prints.
#
# A palette-subst.nix template, rendered by home/max/claude.nix: colours are
# @name-hex@ placeholders, never literal hex.
set -euo pipefail

input=$(cat)
field() { jq -r "$1 // empty" <<<"$input"; }

cwd=$(field '.workspace.current_dir // .cwd')
model=$(field .model.display_name)
effort=$(field .effort.level) # absent for models without effort levels
used=$(field .context_window.used_percentage)

bg1='@bg1-hex@' bg2='@bg2-hex@' bg3='@bg3-hex@' bg4='@bg4-hex@'
text='@fg-hex@' red='@red-hex@' yellow='@yellow-hex@' green='@green-hex@'
aqua='@aqua-hex@' blue='@blue-hex@' purple='@purple-hex@'

# seg FG BG TEXT — TEXT in 24-bit palette colours; an empty BG keeps the
# terminal's own background
seg() {
  printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"
  [[ -z $2 ]] || printf '\033[48;2;%d;%d;%dm' "0x${2:0:2}" "0x${2:2:2}" "0x${2:4:2}"
  printf '%s\033[0m' "$3"
}

# ~ for $HOME, and only the last three components behind …/ (Starship's
# truncation_length / truncation_symbol)
dir=${cwd/#"$HOME"/\~}
IFS=/ read -ra parts <<<"$dir"
if ((${#parts[@]} > 3)); then
  dir="…/${parts[-3]}/${parts[-2]}/${parts[-1]}"
fi

# Git in one call: porcelain v2 --branch carries the branch, the upstream's
# ahead/behind counts and the file states. --no-optional-locks: this runs on
# every refresh, alongside the session's own git.
branch='' gitstate=''
if [[ -n $cwd ]] && status=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null); then
  oid='' ab='' conflicted='' deleted='' renamed='' modified='' staged='' untracked=''
  while read -r kind xy rest; do
    case $kind in
      '#')
        case $xy in
          branch.oid) oid=$rest ;;
          branch.head) branch=$rest ;;
          branch.ab) ab=$rest ;;
        esac
        ;;
      1 | 2) # XY: index then worktree state, '.' for unchanged
        [[ $kind == 2 ]] && renamed=1
        [[ $xy == *D* ]] && deleted=1
        [[ ${xy:1:1} == M ]] && modified=1
        [[ ${xy:0:1} == . ]] || staged=1
        ;;
      u) conflicted=1 ;;
      '?') untracked=1 ;;
    esac
  done <<<"$status"
  [[ $branch == '(detached)' ]] && branch=${oid:0:7}

  # Starship's git_status symbols, in its $all_status$ahead_behind order
  gitstate="${conflicted:+⚡}${deleted:+✘}${renamed:+»}${modified:+!}${staged:++}${untracked:+?}"
  if [[ $ab =~ ^\+([0-9]+)\ -([0-9]+)$ ]]; then
    ahead=${BASH_REMATCH[1]} behind=${BASH_REMATCH[2]}
    if ((ahead && behind)); then
      gitstate+="⇕⇡$ahead⇣$behind"
    elif ((ahead)); then
      gitstate+="⇡$ahead"
    elif ((behind)); then
      gitstate+="⇣$behind"
    else
      gitstate+='✓'
    fi
  fi
fi

user_colour=$text
((EUID == 0)) && user_colour=$red

seg "$purple" '' $' ' # Starship's os segment: the NixOS logo
seg "$user_colour" '' "$(id -un) "
seg "$bg1" '' $''
seg "$blue" "$bg1" " $dir "
seg "$bg1" "$bg2" $''
if [[ -n $branch ]]; then
  seg "$green" "$bg2" $'  '"$branch "
  [[ -z $gitstate ]] || seg "$red" "$bg2" "$gitstate "
fi
seg "$bg2" "$bg3" $''

seg "$text" "$bg3" ' '
[[ -z $model ]] || seg "$purple" "$bg3" "$model "
[[ -z $effort ]] || seg "$aqua" "$bg3" "$effort "
if [[ -n $used ]]; then
  pct=$(printf '%.0f' "$used")
  colour=$green
  ((pct >= 60)) && colour=$yellow
  ((pct >= 85)) && colour=$red
  seg "$colour" "$bg3" "ctx $pct% "
fi
seg "$bg3" '' $''

seg "$bg4" '' $' \U000f0954 '"$(date +%H:%M) "
