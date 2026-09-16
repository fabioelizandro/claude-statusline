#!/bin/bash
# Claude Code status line — "neon" style
#   model + effort [session] branch ◆ ctx bar ◆ 5h + countdown ◆ week all ◆ week fable ...
# Same data sources as statusline.sh: the JSON Claude Code pipes in, plus Anthropic's usage
# endpoint for the weekly per-model limits (cached, refreshed in the background).
# Uses 256-colour ANSI on a plum pill, so the neon palette reads the same on light and
# dark terminal themes.
input=$(cat)
j() { echo "$input" | jq -r "$1"; }

# Anthropic's usage endpoint, cached and refreshed in the background; sets $CACHE
self=${BASH_SOURCE[0]}; [[ -L "$self" ]] && self=$(readlink "$self")  # installed as a symlink
source "$(dirname "$self")/usage.sh"

# neon palette
c() { printf '\e[38;5;%sm' "$1"; }
BG=$'\e[48;5;53m'           # plum pill behind the whole row
R=$'\e[0m'"$BG"; BOLD=$'\e[1m'   # every reset re-applies the background
END=$'\e[0m'
PINK=$(c 198); CYAN=$(c 51); PURPLE=$(c 141); YELLOW=$(c 227); GREEN=$(c 47); GREY=$(c 252)
sep=" ${PURPLE}◆${R} "

pct_color() {
  if   (( $1 >= 80 )); then echo "$PINK"
  elif (( $1 >= 50 )); then echo "$YELLOW"
  else echo "$GREEN"; fi
}
gauge() {  # $1 = label, $2 = integer percent
  echo "${GREY}$1${R} $(pct_color "$2")${2}%${R}"
}
bar() {    # $1 = integer percent → 8 blocks
  local n=$(( ($1 + 6) / 13 )); (( n > 8 )) && n=8
  local filled; filled=$(printf '%*s' "$n" '' | tr ' ' '▰')
  local empty;  empty=$(printf '%*s' $((8 - n)) '' | tr ' ' '▱')
  echo "$(pct_color "$1")${filled}${GREY}${empty}${R}"
}
countdown() {  # epoch seconds, or an ISO-8601 UTC time → "3h07m"; empty once the window has passed
  local at=$1
  [[ $at =~ ^[0-9]+$ ]] || at=$(jq -rn --arg t "$at" \
    '$t | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch empty')
  [[ -z $at ]] && return
  local left=$(( at - $(date +%s) ))
  (( left > 0 )) && printf '%dh%02dm' $(( left / 3600 )) $(( left % 3600 / 60 ))
}

model=$(j '.model.display_name // "Claude"' | sed 's/ *(.*)//')   # drop "(1M context)" etc.
effort=$(j '.effort.level // empty')
name=$(j '.session_name // empty')
dir=$(j '.workspace.current_dir // .cwd // empty')
ctx=$(j '.context_window.used_percentage // 0' | cut -d. -f1)
# the 5-hour window: the usage endpoint's "session" row, which is there even when Claude Code
# passes no rate limits in, falling back to what it did pass
five=""; five_reset=""
[[ -s "$CACHE" ]] && IFS=$'\t' read -r five five_reset < <(jq -r '
  .limits[]? | select(.group == "session") | [ .percent, .resets_at ] | @tsv' "$CACHE")
[[ -z "$five" ]] && {
  five=$(j '.rate_limits.five_hour.used_percentage // empty')
  five_reset=$(j '.rate_limits.five_hour.resets_at // empty')
}
five=${five%.*}
branch=""; [[ -n "$dir" ]] && branch=$(git -C "$dir" branch --show-current 2>/dev/null)

line="${BG} ${BOLD}${PINK}▞ ${model} ▚${R}"
[[ -n "$effort" ]] && line+=" ${GREY}⚡${R} ${YELLOW}${effort}${R}"
# the brackets act as the delimiter around the session name: no separator before or after it
nsep=$sep
[[ -n "$name" ]]   && { line+=" ${GREY}[${CYAN}${name}${GREY}]${R}"; nsep=" "; }
[[ -n "$branch" ]] && { line+="${nsep}${GREY}⌥${R} ${YELLOW}${branch}${R}"; nsep=$sep; }
line+="${nsep}${GREY}ctx${R} $(bar "$ctx") $(pct_color "$ctx")${ctx}%${R}"

if [[ -n "$five" ]]; then
  line+="${sep}$(gauge 5h "$five")"
  left=""; [[ -n "$five_reset" ]] && left=$(countdown "$five_reset")
  [[ -n "$left" ]] && line+=" ${GREY}⏱${R} ${CYAN}${left}${R}"
fi

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

printf '%s \n' "$line$END"
