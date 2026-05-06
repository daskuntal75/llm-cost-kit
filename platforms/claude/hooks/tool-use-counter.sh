#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.7 — PreToolUse Tool-Use Counter
#
# Wired into Claude Code via .claude/settings.json:
#   { "hooks": { "PreToolUse": [{ "matcher": "*", "hooks":
#       [{"type":"command","command":"~/.claude/hooks/tool-use-counter.sh"}]}] } }
#
# Runs BEFORE every tool call. Receives JSON on stdin. Increments a per-session
# per-turn counter. Emits one-shot stderr warnings at 70% and 85% of soft target.
#
# Soft target (default 35) is configurable via $TOOL_USE_SOFT_TARGET.
# Hard cap (~50) is enforced by Claude Code itself; this hook just helps the
# user/agent stay under it.
#
# Performance budget: <10ms per call. Pure zsh + jq only.
# =============================================================================

set -e

SOFT="${TOOL_USE_SOFT_TARGET:-35}"
WARN_70=$(( SOFT * 70 / 100 ))
WARN_85=$(( SOFT * 85 / 100 ))

DIR="$HOME/.local/cost/tool-counts"
mkdir -p "$DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "?"')
STATE="$DIR/${SESSION_ID}.json"

[[ -f "$STATE" ]] || echo '{"count":0,"warned":[],"tools":{}}' > "$STATE"

NEW=$(jq -c --arg t "$TOOL_NAME" \
  '.count += 1 | .tools[$t] = ((.tools[$t] // 0) + 1)' "$STATE")
echo "$NEW" > "$STATE"

COUNT=$(echo "$NEW" | jq -r '.count')
WARNED=$(echo "$NEW" | jq -r '.warned | join(",")')

emit_once() {
  local thresh="$1" pct="$2" msg="$3"
  if (( COUNT >= thresh )) && [[ "$WARNED" != *"$pct"* ]]; then
    echo "$msg" >&2
    jq -c --arg p "$pct" '.warned += [$p]' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  fi
}

emit_once "$WARN_85" 85 "⚠️  Tool-use $COUNT/$SOFT (85%). Hard cap ~50/turn approaching. Checkpoint, batch in parallel, or delegate to subagent."
emit_once "$WARN_70" 70 "⚠️  Tool-use $COUNT/$SOFT (70%). Consider batching remaining calls or delegating."

exit 0
