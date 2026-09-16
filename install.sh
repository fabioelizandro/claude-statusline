#!/bin/bash
# Link the status line into ~/.claude and register it in Claude Code's settings.
set -e
D="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude
ln -sfn "$D/statusline.sh" ~/.claude/statusline.sh
chmod +x "$D/statusline.sh"
S=~/.claude/settings.json
[[ -s "$S" ]] || echo '{}' > "$S"
jq '.statusLine = {type: "command", command: "~/.claude/statusline.sh"}' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
echo "Installed. Start a new Claude Code session to see the status line."
