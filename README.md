# claude-statusline

A status line for [Claude Code](https://docs.claude.com/en/docs/claude-code) that shows the
weekly usage limits, including the per-model ones (Fable, Opus, ...) that Claude Code itself
does not always pass to status line scripts.

<img width="882" height="141" alt="Screenshot 2026-09-16 at 1 41 56 pm" src="https://github.com/user-attachments/assets/118096ef-0ca3-4dd8-bb4f-f9cb17fcfc9d" />

Every percentage is coloured: green below 50%, yellow from 50%, red from 80%.
Uses ANSI colours, so it follows your terminal palette (pairs well with Claude's `light-ansi` /
`dark-ansi` themes).

## How it works

- Model, session name and context usage come from the JSON Claude Code pipes to the script.
- Weekly limits come from Anthropic's usage endpoint (`/api/oauth/usage`), the same source the
  `/usage` command and tools like claudometer use. The script reads the Claude Code OAuth token
  from the macOS keychain, caches the answer for 60 seconds and refreshes it in a background
  process, so rendering takes a few milliseconds and never waits on the network.
- Every `weekly` row the server returns is printed with the server's own label, so new
  per-model buckets show up without changes.
- If the fetch fails it keeps the last cached figures, or falls back to the overall weekly
  figure Claude Code provides.

## Install

Requires macOS, `jq` and `curl`. Claude Code must be logged in with a claude.ai account
(the token lives in the keychain under "Claude Code-credentials").

```
git clone git@github.com:fabioelizandro/claude-statusline.git ~/claude-statusline
~/claude-statusline/install.sh
```

Or set it up by hand: copy `statusline.sh` somewhere, make it executable, and add to
`~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "/path/to/statusline.sh" } }
```

## Customise

Thresholds and colours are the `pct_color` function at the top of the script. Segments are
built into `$line` near the bottom; remove or reorder them there.
