#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.8 — Post-Setup Verification
# Usage: bash verify.sh
#
# Run this AFTER bootstrap-macos.sh + setup.sh + first-run auth to confirm
# everything is wired correctly. Prints a green/red dashboard. Non-destructive.
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; WARN_COUNT=0
# NOTE: counters use PASS=$((PASS+1)) instead of ((PASS++)) on purpose.
# ((var++)) returns the *pre-increment* value, so when PASS starts at 0 the
# first call exits non-zero — which makes `cmd && pass "x" || fail "y"` patterns
# fire BOTH branches. POSIX `var=$((var+1))` always exits 0.
pass() { printf "${GREEN}  ✓${NC} %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "${RED}  ✗${NC} %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; WARN_COUNT=$((WARN_COUNT+1)); }
sec()  { printf "\n${BLUE}━━ %s ━━${NC}\n" "$1"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   LLM Cost Kit v3.8 — Verification Dashboard         ║"
echo "╚══════════════════════════════════════════════════════╝"

# ── Prereqs ──────────────────────────────────────────────────────────────────
sec "Prerequisites"
command -v brew     &>/dev/null && pass "brew     — $(brew --version | head -1)"            || fail "brew not found"
command -v node     &>/dev/null && pass "node     — $(node --version)"                       || fail "node not found"
command -v npm      &>/dev/null && pass "npm      — $(npm --version)"                        || fail "npm not found"
command -v jq       &>/dev/null && pass "jq       — $(jq --version)"                         || fail "jq not found"
command -v fswatch  &>/dev/null && pass "fswatch  — $(fswatch --version 2>&1 | head -1)"     || warn "fswatch missing (skills auto-sync won't work)"
command -v git      &>/dev/null && pass "git      — $(git --version)"                        || fail "git not found"
command -v gh       &>/dev/null && pass "gh       — $(gh --version | head -1)"               || warn "gh not found (manual GitHub auth required)"

# ── Claude tooling ──────────────────────────────────────────────────────────
sec "Claude tooling"
[[ -d "/Applications/Claude.app" ]] && pass "Claude Desktop app present" || warn "Claude Desktop app not in /Applications"
command -v claude   &>/dev/null && pass "claude CLI — $(claude --version 2>/dev/null | head -1)" || fail "claude CLI not found"
command -v ccusage  &>/dev/null && pass "ccusage    — installed"                                  || fail "ccusage not found"

# ── Auth state ───────────────────────────────────────────────────────────────
sec "Auth state"
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  pass "gh authenticated as $(gh api user --jq .login 2>/dev/null)"
else
  warn "gh not authenticated — run: gh auth login"
fi

if [[ -d "$HOME/.claude" ]]; then
  pass "~/.claude/ exists (Claude CLI configured)"
else
  fail "~/.claude/ missing — run \`claude\` once to trigger OAuth"
fi

# ── Cost tracking ────────────────────────────────────────────────────────────
sec "Cost tracking"
if [[ -x "$HOME/.local/bin/update-claude-cost" ]]; then
  pass "update-claude-cost installed at ~/.local/bin/"
  # Check both canonical and legacy state-file locations
  STATE=""
  for cand in "$HOME/.claude/cumulative-cost.json" "$HOME/.local/cost/state.json"; do
    if [[ -f "$cand" ]]; then STATE="$cand"; break; fi
  done
  if [[ -n "$STATE" ]]; then
    plan=$(jq -r '.subscription.plan // "?"' "$STATE" 2>/dev/null)
    fee=$(jq -r '.subscription.fee_usd // "?"' "$STATE" 2>/dev/null)
    renews=$(jq -r '.subscription.renews_on // "?"' "$STATE" 2>/dev/null)
    if [[ "$plan" == "?" || "$plan" == "null" ]]; then
      warn "cost state at $STATE has plan unset — run: update-claude-cost --plan PLAN --fee FEE --renews YYYY-MM-DD"
    else
      pass "cost state initialized — plan=$plan  fee=\$$fee  renews=$renews  (file: $(basename "$STATE"))"
    fi
    if find "$STATE" -mtime -1 &>/dev/null; then
      pass "cost state refreshed within last 24h"
    else
      warn "cost state >24h stale — LaunchAgent may not be running. Run: launchctl list | grep cost"
    fi
  else
    warn "cost state missing — run: update-claude-cost --plan PLAN --fee FEE --renews YYYY-MM-DD"
  fi
else
  fail "update-claude-cost not in ~/.local/bin/ — re-run setup.sh and accept the cumulative-tracking prompt"
fi

# ── Hourly LaunchAgent ───────────────────────────────────────────────────────
sec "Hourly cost pipeline"
# Plist may use any of these names depending on kit version / install path
PLIST=""
for cand in \
    "$HOME/Library/LaunchAgents/com.kuntal.cumulative-cost.plist" \
    "$HOME/Library/LaunchAgents/cumulative-cost-launchagent.plist" \
    "$HOME/Library/LaunchAgents/com.daskuntal.cumulative-cost.plist"; do
  [[ -f "$cand" ]] && { PLIST="$cand"; break; }
done
if [[ -n "$PLIST" ]]; then
  pass "LaunchAgent plist found: $(basename "$PLIST")"
  if launchctl list 2>/dev/null | grep -q -i cumulative-cost; then
    pass "LaunchAgent loaded and running"
  else
    warn "LaunchAgent plist present but not loaded — run: launchctl load $PLIST"
  fi
else
  warn "Hourly LaunchAgent not installed (optional)"
fi

# ── MCP configs ──────────────────────────────────────────────────────────────
sec "MCP configs"
if [[ -d "$HOME/.claude/mcp-configs" ]]; then
  count=$(find "$HOME/.claude/mcp-configs" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    pass "~/.claude/mcp-configs/ has $count config file(s)"
  else
    warn "~/.claude/mcp-configs/ exists but empty — re-run setup.sh"
  fi
else
  warn "~/.claude/mcp-configs/ missing"
fi

# ── Instruction layers ──────────────────────────────────────────────────────
sec "Instruction layers (machine-reachable)"
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
  pass "L3-global — ~/.claude/CLAUDE.md present ($(wc -l < ~/.claude/CLAUDE.md | tr -d ' ') lines)"
else
  warn "L3-global missing — copy GLOBAL-CLAUDE.md to ~/.claude/CLAUDE.md"
fi

# ── Skills source (optional) ────────────────────────────────────────────────
sec "Skills source"
SKILLS_DIR="${SKILLS_SOURCE_DIR:-$HOME/dev/skills-source}"
if [[ -d "$SKILLS_DIR" ]]; then
  pass "skills-source at $SKILLS_DIR"
  if [[ -d "$SKILLS_DIR/.build" ]]; then
    skill_count=$(find "$SKILLS_DIR/.build" -maxdepth 1 -name '*.skill' | wc -l | tr -d ' ')
    pass "$skill_count built .skill bundle(s) in $SKILLS_DIR/.build"
  else
    warn "no .build/ — run: bash $SKILLS_DIR/scripts/build-skills.sh"
  fi
else
  warn "skills-source not found at $SKILLS_DIR (optional, but recommended)"
fi

# ── Tool-use hygiene (v3.7+) ────────────────────────────────────────────────
sec "Tool-use hygiene (v3.8)"
[[ -x "$HOME/.claude/hooks/tool-use-counter.sh" ]] && pass "PreToolUse counter hook present" || warn "PreToolUse counter hook missing — re-run setup.sh"
[[ -x "$HOME/.claude/hooks/tool-use-reset.sh" ]]   && pass "Stop reset hook present"          || warn "Stop reset hook missing — re-run setup.sh"
if [[ -f "$HOME/.claude/settings.json" ]] && command -v jq &>/dev/null; then
  if jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | map(strings) | map(test("tool-use-counter\\.sh$")) | any' "$HOME/.claude/settings.json" &>/dev/null; then
    pass "PreToolUse hook registered in settings.json"
  else
    warn "PreToolUse hook not registered — re-run setup.sh"
  fi
  if jq -e '[.hooks.Stop[]?.hooks[]?.command] | map(strings) | map(test("tool-use-reset\\.sh$")) | any' "$HOME/.claude/settings.json" &>/dev/null; then
    pass "Stop hook registered in settings.json"
  else
    warn "Stop hook not registered — re-run setup.sh"
  fi
fi
[[ -x "$HOME/.local/bin/tool-use-stats" ]] && pass "tool-use-stats CLI installed" || warn "tool-use-stats CLI missing"
if [[ -x "$HOME/.local/bin/tool-use-stats" ]]; then
  if "$HOME/.local/bin/tool-use-stats" --lint &>/dev/null; then
    pass "tool-use-stats --lint mode available (v3.8)"
  else
    warn "tool-use-stats does not support --lint — re-run setup.sh to update"
  fi
fi
if [[ "${TOOL_USE_HARD_BLOCK:-0}" == "1" ]]; then
  pass "TOOL_USE_HARD_BLOCK=1 (opt-in enforcement active)"
fi
if [[ -d "$HOME/.local/cost/tool-counts" ]]; then
  hist="$HOME/.local/cost/tool-counts/history.jsonl"
  if [[ -f "$hist" ]]; then
    turns=$(wc -l < "$hist" | tr -d ' ')
    pass "tool-use history present ($turns turns logged)"
  else
    warn "tool-counts dir exists but no history.jsonl yet (will populate on next turn)"
  fi
fi

# ── Manual web-UI checklist ──────────────────────────────────────────────────
sec "Manual steps (cannot auto-verify)"
echo "  ☐ L4 — Settings → Profile → Preferences → paste core/OUTPUT_RULES.md"
echo "  ☐ L2 — Cowork → Settings → Global Instructions → paste cowork-global-instructions.md"
echo "  ☐ L1 — Per Cowork project → tailored cowork-project-instructions.md"
echo "  ☐ L7 — Per Chat project → tailored chat-project-instructions.md"
echo "  ☐ L6 — Cowork → Customize → Skills → install 3 .skill zips"
echo "  ☐ MCP connectors — https://claude.ai/settings/connectors"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
printf "║   %sPASS: %2d${NC}   %sWARN: %2d${NC}   %sFAIL: %2d${NC}                  ║\n" "$GREEN" "$PASS" "$YELLOW" "$WARN_COUNT" "$RED" "$FAIL"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Fix the ✗ items first. Most issues resolve by re-running setup.sh."
  exit 1
fi
exit 0
