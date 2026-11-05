# shellcheck shell=bash
# claude-account — keep several Claude Code logins and swap between them.
#
# Claude Code holds one login: the OAuth tokens in ~/.claude/.credentials.json
# and the account profile in the oauthAccount block of ~/.claude.json. Each
# saved account is a copy of both under ~/.claude/accounts/<name>/; swapping
# copies one back. Everything else (settings, memory, history, plugins) stays
# shared. The DMS claudeUsage widget reads the same credentials file, so it
# follows the swap; its popout drives this script (config/dms/ClaudeAccounts.qml).
#
#   claude-account                 list saved accounts (* = active)
#   claude-account list --json     same, for the widget
#   claude-account save <name>     save the current login as <name>
#   claude-account use <name>      switch to <name>
#   claude-account forget <name>   delete a saved account
#
# Tokens rotate as Claude Code refreshes them, so `use` first saves the live
# tokens back into the active account's slot; a stale copy would stop working.
# Running sessions keep the old account until restarted.

conf="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
creds="$conf/.credentials.json"
if [[ -n ${CLAUDE_CONFIG_DIR:-} ]]; then
  state="$CLAUDE_CONFIG_DIR/.claude.json"
else
  state="$HOME/.claude.json"
fi
store="$conf/accounts"
usage_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json"

die() {
  echo "claude-account: $*" >&2
  exit 1
}

# Which login an oauthAccount block is: user and organisation, so one email in
# two organisations counts as two accounts
identity() {
  jq -r '.accountUuid + "/" + .organizationUuid' "$1" 2>/dev/null
}

live_identity() {
  jq -r '.oauthAccount // empty | .accountUuid + "/" + .organizationUuid' "$state" 2>/dev/null
}

# The saved account matching the live login, if any
active() {
  local live slot
  live=$(live_identity)
  [[ -n $live ]] || return 0
  for slot in "$store"/*/; do
    [[ -f $slot/oauthAccount.json ]] || continue
    if [[ $(identity "$slot/oauthAccount.json") == "$live" ]]; then
      basename "$slot"
      return 0
    fi
  done
}

valid_name() {
  [[ $1 =~ ^[A-Za-z0-9_-]+$ ]] || die "account names are letters, digits, - and _"
}

# Copy $1 to $2 through a temp file in $2's directory, so a reader never sees
# half a file, and with $2 private
install_private() {
  local tmp
  tmp=$(mktemp "$2.XXXXXX")
  chmod 600 "$tmp"
  cat "$1" >"$tmp"
  mv "$tmp" "$2"
}

# Snapshot the live login into slot $1
save_live() {
  local slot="$store/$1"
  [[ -s $creds ]] || die "not logged in (no $creds) — run claude, then /login"
  [[ -n $(live_identity) ]] || die "no account profile in $state — run claude, then /login"
  mkdir -p "$slot"
  chmod 700 "$store" "$slot"
  install_private "$creds" "$slot/credentials.json"
  local tmp
  tmp=$(mktemp)
  jq '.oauthAccount' "$state" >"$tmp"
  install_private "$tmp" "$slot/oauthAccount.json"
  rm -f "$tmp"
}

cmd_list() {
  local current slot name
  current=$(active)
  if [[ ${1:-} == --json ]]; then
    for slot in "$store"/*/; do
      [[ -f $slot/oauthAccount.json ]] || continue
      name=$(basename "$slot")
      jq -c --arg name "$name" --argjson active "$([[ $name == "$current" ]] && echo true || echo false)" \
        '{name: $name, email: .emailAddress, org: .organizationName, active: $active}' \
        "$slot/oauthAccount.json"
    done | jq -sc '.'
    return
  fi
  local any=
  for slot in "$store"/*/; do
    [[ -f $slot/oauthAccount.json ]] || continue
    any=1
    name=$(basename "$slot")
    printf '%s %-12s %s\n' "$([[ $name == "$current" ]] && echo '*' || echo ' ')" "$name" \
      "$(jq -r '.emailAddress + " (" + (.organizationName // "personal") + ")"' "$slot/oauthAccount.json")"
  done
  if [[ -z $any ]]; then
    echo "No saved accounts. Save the current login with: claude-account save <name>"
  elif [[ -z $current && -n $(live_identity) ]]; then
    echo "The current login ($(jq -r '.oauthAccount.emailAddress' "$state")) isn't saved."
  fi
}

cmd_save() {
  [[ $# -eq 1 ]] || die "usage: claude-account save <name>"
  valid_name "$1"
  local current
  current=$(active)
  if [[ -n $current && $current != "$1" ]]; then
    die "this login is already saved as '$current'"
  fi
  save_live "$1"
  echo "Saved $(jq -r '.oauthAccount.emailAddress' "$state") as '$1'."
}

cmd_use() {
  [[ $# -eq 1 ]] || die "usage: claude-account use <name>"
  valid_name "$1"
  local slot="$store/$1" current
  [[ -f $slot/credentials.json && -f $slot/oauthAccount.json ]] || die "no saved account '$1'"
  current=$(active)
  if [[ $current == "$1" ]]; then
    echo "Already on '$1'."
    return
  fi
  if [[ -n $current ]]; then
    save_live "$current"
  elif [[ -n $(live_identity) && -s $creds ]]; then
    die "the current login ($(jq -r '.oauthAccount.emailAddress' "$state")) isn't saved, and switching would lose it — claude-account save <name> first"
  fi

  install_private "$slot/credentials.json" "$creds"
  local tmp
  tmp=$(mktemp "$state.XXXXXX")
  chmod 600 "$tmp"
  if [[ -f $state ]]; then
    jq --slurpfile a "$slot/oauthAccount.json" '.oauthAccount = $a[0]' "$state" >"$tmp"
  else
    jq -n --slurpfile a "$slot/oauthAccount.json" '{oauthAccount: $a[0]}' >"$tmp"
  fi
  mv "$tmp" "$state"

  # The widget reuses a cache under 150 s old; drop it so the next fetch is
  # this account's
  rm -f "$usage_cache"

  echo "Switched to '$1' ($(jq -r '.emailAddress' "$slot/oauthAccount.json"))."
  local running
  running=$(pgrep -u "$(id -u)" -c '^(claude|\.claude-unwrapp)$' || true)
  if [[ ${running:-0} -gt 0 ]]; then
    echo "$running Claude Code session(s) still running on the old account; restart them." >&2
  fi
}

cmd_forget() {
  [[ $# -eq 1 ]] || die "usage: claude-account forget <name>"
  valid_name "$1"
  [[ -d $store/$1 ]] || die "no saved account '$1'"
  rm -rf "${store:?}/$1"
  echo "Forgot '$1'."
}

case "${1:-list}" in
list) cmd_list "${@:2}" ;;
save) cmd_save "${@:2}" ;;
use) cmd_use "${@:2}" ;;
forget) cmd_forget "${@:2}" ;;
-h | --help | help)
  cat <<'EOF'
claude-account                 list saved accounts (* = active)
claude-account list --json     same, as JSON
claude-account save <name>     save the current login as <name>
claude-account use <name>      switch to <name>
claude-account forget <name>   delete a saved account
EOF
  ;;
*) die "unknown command '$1' (list, save, use, forget)" ;;
esac
