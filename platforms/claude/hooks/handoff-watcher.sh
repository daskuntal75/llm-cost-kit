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

set +e  # never crash the Stop pipeline on jq parse failures — leaking stderr
        # to the harness shows up as "Stop hook error" and historically risks
        # session-archival side-effects in the desktop app.

# Strip non-whitespace control bytes (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F) from
# the hook payload before jq sees it. Some tool results (e.g. `strings` on
# binaries) leak raw control bytes into the harness's stdin payload, and jq's
# JSON parser rejects them ("Invalid string: control characters from U+0000
# through U+001F must be escaped"). Keep tab/LF/CR — valid JSON whitespace.
INPUT=$(LC_ALL=C tr -d '\000-\010\013\014\016-\037')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]] && SESSION_ID="unknown"
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$HOOK_CWD" ]] && HOOK_CWD="$PWD"

# Project-scoped handoff path. Encoding matches Claude Code's own
# ~/.claude/projects/<encoded-cwd>/ convention: every non-alphanumeric
# character (slash, underscore, dot, @, space, etc.) becomes `-`, with
# consecutive dashes collapsed. Project-scoping de-conflicts DIFFERENT cwds
# (bug fixed 2026-05-22). But two concurrent sessions in the SAME repo still
# shared one last-handoff.md and clobbered each other (incident 2026-05-30),
# so the filename is ALSO session-scoped: suffix the first segment of the
# session UUID. Every session/thread now owns its own handoff file.
PROJECT_HASH=$(printf '%s' "$HOOK_CWD" | LC_ALL=C tr -c 'a-zA-Z0-9-' '-' | tr -s '-')
PROJECT_DIR="$HOME/.claude/projects/${PROJECT_HASH}"
SESSION_SHORT="${SESSION_ID%%-*}"
[[ -z "$SESSION_SHORT" || "$SESSION_SHORT" == "null" ]] && SESSION_SHORT="unknown"
HANDOFF_FILE="${PROJECT_DIR}/last-handoff-${SESSION_SHORT}.md"
mkdir -p "$PROJECT_DIR" 2>/dev/null

STATE_FILE="$HOME/.claude/handoff-state.json"
# Also write a session-scoped copy so the statusline reads THIS session's
# pressure, not a sibling session's (which may have written the shared file
# last). Residual fix 2026-05-30.
STATE_FILE_SESSION="$HOME/.claude/handoff-state-${SESSION_SHORT}.json"
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
  NUDGE="🔴 Compact pressure HIGH (${TURNS} turns, ${TOOLS} tool-calls, idle ${IDLE_MIN}m). Recommend ${RECOMMEND}. WRITE/REFRESH ${HANDOFF_FILE} THIS RESPONSE before doing anything else."
elif (( TURNS >= TURNS_YELLOW || TOOLS >= TOOLS_YELLOW || IDLE_MIN > IDLE_YELLOW_MIN )); then
  LEVEL="🟡"
  NUDGE="🟡 Compact pressure MEDIUM (${TURNS} turns, ${TOOLS} tool-calls, idle ${IDLE_MIN}m). Consider ${RECOMMEND}. Keep ${HANDOFF_FILE} current."
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
  --arg cwd "$HOOK_CWD" \
  --arg handoff_file "$HANDOFF_FILE" \
  '{updated:$ts, session_id:$sid, turns:$turns, tools:$tools, idle_min:$idle, level:$level, recommend:$recommend, cwd:$cwd, handoff_file:$handoff_file}' \
  | tee "$STATE_FILE" > "$STATE_FILE_SESSION"

# ── Emit nudge to stderr ────────────────────────────────────────────────────
# Claude Code surfaces hook stderr to the model on the next turn as a
# system-reminder, so the model sees the pressure level before responding.
if [[ -n "$NUDGE" ]]; then
  echo "$NUDGE" >&2
fi

exit 0
