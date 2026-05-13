#!/bin/zsh
# =============================================================================
# Handoff Watcher — Stop hook (v3.9)
#
# Wired into Claude Code via ~/.claude/settings.json:
#   { "hooks": { "Stop": [{ "hooks":
#       [{"type":"command","command":"~/.claude/hooks/handoff-watcher.sh"}]}] } }
#
# Fires when the assistant turn ends. Reads session_id + transcript_path from
# stdin. Computes cumulative pressure signals (turn count, tool-call count,
# idle minutes since last user message) and writes ~/.claude/handoff-state.json.
# When pressure crosses thresholds, emits a stderr nudge so the model surfaces
# a handoff brief on the next turn.
#
# Thresholds (tunable via env vars):
#   HANDOFF_TURNS_YELLOW (default 30) / RED (default 60)
#   HANDOFF_TOOLS_YELLOW (default 100) / RED (default 200)
#   HANDOFF_IDLE_YELLOW_MIN (default 5)   — > this → recommend /clear over /compact
# =============================================================================

set -e

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

STATE_FILE="$HOME/.claude/handoff-state.json"
HIST="$HOME/.local/cost/tool-counts/history.jsonl"

TURNS_YELLOW="${HANDOFF_TURNS_YELLOW:-30}"
TURNS_RED="${HANDOFF_TURNS_RED:-60}"
TOOLS_YELLOW="${HANDOFF_TOOLS_YELLOW:-100}"
TOOLS_RED="${HANDOFF_TOOLS_RED:-200}"
IDLE_YELLOW_MIN="${HANDOFF_IDLE_YELLOW_MIN:-5}"

# ── Cumulative tool count across all turns of this session ──────────────────
TOOLS=0
if [[ -f "$HIST" ]]; then
  TOOLS=$(jq -s --arg sid "$SESSION_ID" '[.[] | select(.session_id == $sid) | .count] | add // 0' "$HIST" 2>/dev/null || echo 0)
fi

# ── Turn count + last user timestamp from transcript ────────────────────────
TURNS=0
LAST_USER_TS=""
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  TURNS=$(jq -s '[.[] | select(.role == "user" or .type == "user")] | length' "$TRANSCRIPT" 2>/dev/null || echo 0)
  LAST_USER_TS=$(jq -s -r '[.[] | select(.role == "user" or .type == "user")] | last | (.timestamp // .ts // empty)' "$TRANSCRIPT" 2>/dev/null || echo "")
fi

# ── Idle minutes since last user message ────────────────────────────────────
NOW=$(date -u +%s)
LAST_USER_S=$NOW
if [[ -n "$LAST_USER_TS" ]]; then
  LAST_USER_S=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "${LAST_USER_TS%%.*}Z" "+%s" 2>/dev/null || echo $NOW)
fi
IDLE_MIN=$(( (NOW - LAST_USER_S) / 60 ))
(( IDLE_MIN < 0 )) && IDLE_MIN=0

# ── Determine pressure level + recommendation ───────────────────────────────
LEVEL="🟢"
NUDGE=""
RECOMMEND=""

if (( IDLE_MIN > IDLE_YELLOW_MIN )); then
  RECOMMEND="/clear"
else
  RECOMMEND="/compact"
fi

if (( TURNS >= TURNS_RED || TOOLS >= TOOLS_RED )); then
  LEVEL="🔴"
  NUDGE="🔴 Compact pressure HIGH (${TURNS} turns, ${TOOLS} tool-calls, idle ${IDLE_MIN}m). Recommend ${RECOMMEND}. WRITE/REFRESH ~/.claude/last-handoff.md THIS RESPONSE before doing anything else."
elif (( TURNS >= TURNS_YELLOW || TOOLS >= TOOLS_YELLOW || IDLE_MIN > IDLE_YELLOW_MIN )); then
  LEVEL="🟡"
  NUDGE="🟡 Compact pressure MEDIUM (${TURNS} turns, ${TOOLS} tool-calls, idle ${IDLE_MIN}m). Consider ${RECOMMEND}. Keep ~/.claude/last-handoff.md current."
fi

# ── Write state file (consumed by statusline) ───────────────────────────────
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
  --arg sid "$SESSION_ID" \
  --argjson turns "$TURNS" \
  --argjson tools "$TOOLS" \
  --argjson idle "$IDLE_MIN" \
  --arg level "$LEVEL" \
  --arg recommend "$RECOMMEND" \
  --arg ts "$TS" \
  '{updated:$ts, session_id:$sid, turns:$turns, tools:$tools, idle_min:$idle, level:$level, recommend:$recommend}' \
  > "$STATE_FILE"

# ── Emit nudge to stderr ────────────────────────────────────────────────────
# Claude Code surfaces hook stderr to the model on the next turn as a
# system-reminder, so the model sees the pressure level before responding.
if [[ -n "$NUDGE" ]]; then
  echo "$NUDGE" >&2
fi

exit 0
