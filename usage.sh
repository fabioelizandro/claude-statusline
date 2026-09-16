#!/bin/bash
# Usage cache shared by the status line styles.
#
# Reads the Claude Code OAuth token from the macOS keychain, fetches Anthropic's usage endpoint
# and keeps the answer in $CACHE for $TTL seconds, refreshing in the background once stale, so a
# style always renders instantly. Sourced by statusline.sh and neon.sh, which read $CACHE.
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
