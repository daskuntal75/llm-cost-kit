#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.8 — PreToolUse Tool-Use Counter (with pattern detection)
#
# Wired into Claude Code via .claude/settings.json:
#   { "hooks": { "PreToolUse": [{ "matcher": "*", "hooks":
#       [{"type":"command","command":"~/.claude/hooks/tool-use-counter.sh"}]}] } }
#
# Runs BEFORE every tool call. Receives JSON on stdin. Tracks:
#   - per-turn count
#   - per-tool tally
#   - rolling window of last 5 tool names (pattern detection)
#
# Emits one-shot stderr warnings (per-turn, deduped):
#   - 70% / 85% of soft target (count thresholds)
#   - 3+ consecutive Bash calls   → suggest chaining with &&
#   - 5+ consecutive same tool    → suggest batching parallel
#   - count >= 15                 → suggest delegating to a subagent
#
# Opt-in HARD enforcement: set TOOL_USE_HARD_BLOCK=1 to make the hook return
#   {"hookSpecificOutput":{"permissionDecision":"deny", "permissionDecisionReason":"..."}}
# at 85% of soft target — Claude Code blocks the call and shows the reason
# back to the model, forcing a checkpoint or delegation.
#
# Soft target (default 35) is configurable via TOOL_USE_SOFT_TARGET.
# Hard cap (~50) is enforced by Claude Code; this hook helps stay under it.
#
# Performance budget: <10ms per call. Pure zsh + jq only.
# =============================================================================

set +e  # never crash PreToolUse — a failed hook is non-blocking but spams stderr.

SOFT="${TOOL_USE_SOFT_TARGET:-35}"
WARN_70=$(( SOFT * 70 / 100 ))
WARN_85=$(( SOFT * 85 / 100 ))
DELEGATE_AT="${TOOL_USE_DELEGATE_AT:-15}"
HARD_BLOCK="${TOOL_USE_HARD_BLOCK:-0}"

DIR="$HOME/.local/cost/tool-counts"
mkdir -p "$DIR"

# Strip non-whitespace control bytes (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F) from
# the hook payload before jq sees it. Tool invocations with heredocs / binary
# content / strings-output leak raw control bytes into stdin, and jq's strict
# JSON parser rejects them. Keep tab/LF/CR (valid JSON whitespace between tokens).
INPUT=$(LC_ALL=C tr -d '\000-\010\013\014\016-\037')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]] && SESSION_ID="unknown"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // "?"' 2>/dev/null)
[[ -z "$TOOL_NAME" || "$TOOL_NAME" == "null" ]] && TOOL_NAME="?"
STATE="$DIR/${SESSION_ID}.json"

[[ -f "$STATE" ]] || echo '{"count":0,"warned":[],"tools":{},"recent":[]}' > "$STATE"

NEW=$(jq -c --arg t "$TOOL_NAME" '
  .count += 1
  | .tools[$t] = ((.tools[$t] // 0) + 1)
  | .recent = ((.recent // []) + [$t] | .[-5:])
' "$STATE")
echo "$NEW" > "$STATE"

COUNT=$(echo "$NEW" | jq -r '.count')
WARNED=$(echo "$NEW" | jq -r '.warned | join(",")')
RECENT=$(echo "$NEW" | jq -r '.recent | join(",")')

emit_once() {
  local tag="$1" msg="$2"
  if [[ "$WARNED" != *"$tag"* ]]; then
    echo "$msg" >&2
    jq -c --arg p "$tag" '.warned += [$p]' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    WARNED="$WARNED,$tag"
  fi
}

# ── Count-based thresholds ──────────────────────────────────────────────────
if (( COUNT >= WARN_85 )); then
  emit_once 85 "⚠️  Tool-use $COUNT/$SOFT (85%). Hard cap ~50/turn approaching. Checkpoint, batch in parallel, or delegate to subagent."
elif (( COUNT >= WARN_70 )); then
  emit_once 70 "⚠️  Tool-use $COUNT/$SOFT (70%). Consider batching remaining calls or delegating."
fi

# ── Pattern-aware nudges (rule 1, 2, 3 from TOOL_USE_HYGIENE.md) ─────────────
# Rule 2: 3+ consecutive Bash calls → chain with &&
if [[ "$RECENT" == "Bash,Bash,Bash"* || "$RECENT" == *",Bash,Bash,Bash" ]]; then
  emit_once "chain" "💡 3+ sequential Bash calls detected (recent: $RECENT). Chain with '&&' to use 1 slot instead of 3 — see core/TOOL_USE_HYGIENE.md rule 2."
fi

# Rule 1: 5+ consecutive same-tool calls → batch parallel
LAST5=$(echo "$NEW" | jq -r '.recent | length as $n | if $n == 5 and (unique | length) == 1 then .[0] else "" end')
if [[ -n "$LAST5" ]]; then
  emit_once "batch-$LAST5" "💡 5 sequential $LAST5 calls in a row. Batch them in ONE message (parallel tool calls) to save 4 turn-overheads — see TOOL_USE_HYGIENE.md rule 1."
fi

# Rule 3: count >= 15 → consider delegating
if (( COUNT >= DELEGATE_AT )); then
  emit_once "delegate" "💡 Turn at $COUNT calls. If the remaining work is a self-contained subtask (search, audit, refactor), delegate to a subagent — fresh quota, costs 1 main-session slot. See TOOL_USE_HYGIENE.md rule 3."
fi

# ── Opt-in hard enforcement ─────────────────────────────────────────────────
if [[ "$HARD_BLOCK" == "1" && $COUNT -ge $WARN_85 ]]; then
  jq -nc --arg reason "Tool-use at $COUNT/$SOFT (85%). TOOL_USE_HARD_BLOCK is active. Stop, summarize what's complete, and either (a) ask the user before continuing, or (b) delegate remaining work to a subagent (subagents have a fresh tool quota)." \
    '{hookSpecificOutput: {permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
