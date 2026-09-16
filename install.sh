#!/bin/bash
# Link a status line style into ~/.claude and register it in Claude Code's settings.
# Usage: ./install.sh [style]   (style = default | neon; see README "Styles")
set -e
D="$(cd "$(dirname "$0")" && pwd)"
case "${1:-default}" in
  default) SRC="$D/statusline.sh" ;;
  neon)    SRC="$D/neon.sh" ;;
  *) echo "unknown style: $1 (expected: default, neon)" >&2; exit 1 ;;
esac
mkdir -p ~/.claude
ln -sfn "$SRC" ~/.claude/statusline.sh
chmod +x "$SRC"
S=~/.claude/settings.json
[[ -s "$S" ]] || echo '{}' > "$S"
jq '.statusLine = {type: "command", command: "~/.claude/statusline.sh"}' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
echo "Installed '${1:-default}' style. Start a new Claude Code session to see the status line."
