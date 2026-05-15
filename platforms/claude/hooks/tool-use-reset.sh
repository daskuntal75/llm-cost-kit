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

set +e  # never crash the Stop pipeline on jq parse failures

DIR="$HOME/.local/cost/tool-counts"
HIST="$DIR/history.jsonl"
mkdir -p "$DIR"

# Strip non-whitespace control bytes (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F) from
# the hook payload before jq sees it. Some tool results (e.g. `strings` on
# binaries) leak raw control bytes into the harness's stdin payload, and jq's
# JSON parser rejects them ("Invalid string: control characters from U+0000
# through U+001F must be escaped"). Keep tab/LF/CR — those are valid JSON
# whitespace between tokens.
INPUT=$(LC_ALL=C tr -d '\000-\010\013\014\016-\037')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]] && SESSION_ID="unknown"
STATE="$DIR/${SESSION_ID}.json"

[[ -f "$STATE" ]] || exit 0

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
COUNT=$(jq -r '.count // 0' "$STATE" 2>/dev/null)
[[ -z "$COUNT" || "$COUNT" == "null" ]] && COUNT=0

# Skip empty turns (no tool calls)
if (( COUNT > 0 )); then
  jq -c --arg ts "$TS" --arg sid "$SESSION_ID" \
    '{ts:$ts, session_id:$sid, count:.count, tools:.tools}' "$STATE" >> "$HIST" 2>/dev/null
fi

# Reset for next turn
echo '{"count":0,"warned":[],"tools":{}}' > "$STATE"
exit 0
