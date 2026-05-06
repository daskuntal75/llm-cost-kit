#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.7 — Stop Hook (per-turn flush + reset)
#
# Wired into Claude Code via .claude/settings.json:
#   { "hooks": { "Stop": [{ "hooks":
#       [{"type":"command","command":"~/.claude/hooks/tool-use-reset.sh"}]}] } }
#
# Fires when the assistant turn ends. Flushes the per-turn counter to history.jsonl
# and resets the per-session state file so the next turn starts at 0.
#
# History format (one JSON object per line):
#   {"ts":"2026-05-06T12:34:56Z","session_id":"...","count":17,"tools":{"Bash":12,"Read":5}}
# =============================================================================

set -e

DIR="$HOME/.local/cost/tool-counts"
HIST="$DIR/history.jsonl"
mkdir -p "$DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
STATE="$DIR/${SESSION_ID}.json"

[[ -f "$STATE" ]] || exit 0

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
COUNT=$(jq -r '.count' "$STATE")

# Skip empty turns (no tool calls)
if (( COUNT > 0 )); then
  jq -c --arg ts "$TS" --arg sid "$SESSION_ID" \
    '{ts:$ts, session_id:$sid, count:.count, tools:.tools}' "$STATE" >> "$HIST"
fi

# Reset for next turn
echo '{"count":0,"warned":[],"tools":{}}' > "$STATE"
exit 0
