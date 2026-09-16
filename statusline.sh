#!/bin/bash
# Claude Code status line: model · session · context · weekly limits (all + per-model, e.g. Fable)
# Colours: green < 50%, yellow 50–79%, red >= 80%
#
# Weekly limits come from Anthropic's usage endpoint (same source claudometer used), using the
# Claude Code OAuth token in the macOS keychain. Cached for 60s and refreshed in the background,
# so the line always renders instantly. Falls back to the figures Claude Code passes in if the
# fetch fails.
input=$(cat)
j() { echo "$input" | jq -r "$1"; }

CACHE=~/.claude/usage-cache.json
TTL=60

fetch_usage() {
  local tok
  tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty') || return 1
  [[ -z "$tok" ]] && return 1
  local out
  out=$(curl -s -m 10 https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20") || return 1
  echo "$out" | jq -e '.limits' >/dev/null 2>&1 || return 1
  echo "$out" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

# Refresh cache: synchronously if missing, in the background if stale
if [[ ! -s "$CACHE" ]]; then
  fetch_usage
elif (( $(date +%s) - $(stat -f %m "$CACHE") > TTL )); then
  ( fetch_usage ) >/dev/null 2>&1 &
  disown
fi

R=$'\e[0m'; DIM=$'\e[2m'; BOLD=$'\e[1m'
BLUE=$'\e[34m'; MAG=$'\e[35m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'
sep="${DIM} │ ${R}"

pct_color() {
  if   (( $1 >= 80 )); then echo "$RED"
  elif (( $1 >= 50 )); then echo "$YELLOW"
  else echo "$GREEN"; fi
}
gauge() {  # $1 = label, $2 = integer percent
  local c; c=$(pct_color "$2")
  echo "${DIM}$1 ${R}${c}${2}%${R}"
}

model=$(j '.model.display_name // "Claude"')
name=$(j '.session_name // "unnamed"')
ctx=$(j '.context_window.used_percentage // 0' | cut -d. -f1)

line="${BOLD}${BLUE}${model}${R}${sep}${MAG}${name}${R}${sep}$(gauge ctx "$ctx")"

if [[ -s "$CACHE" ]]; then
  # weekly_all first, then each weekly_scoped row (Fable, ...), in the server's order
  while IFS=$'\t' read -r label pct; do
    [[ -z "$pct" ]] && continue
    line+="${sep}$(gauge "week $label" "${pct%.*}")"
  done < <(jq -r '
    .limits[]? | select(.group == "weekly") |
    [ (if .kind == "weekly_all" then "all" else ((.scope.model.display_name // "scoped") | ascii_downcase) end),
      .percent ] | @tsv' "$CACHE")
else
  week=$(j '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
  [[ -n "$week" ]] && line+="${sep}$(gauge "week all" "$week")"
fi

printf '%s\n' "$line"
