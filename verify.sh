#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.6 — Post-Setup Verification
# Usage: bash verify.sh
#
# Run this AFTER bootstrap-macos.sh + setup.sh + first-run auth to confirm
# everything is wired correctly. Prints a green/red dashboard. Non-destructive.
# =============================================================================

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; WARN_COUNT=0
pass() { printf "${GREEN}  ✓${NC} %s\n" "$1"; ((PASS++)); }
fail() { printf "${RED}  ✗${NC} %s\n" "$1"; ((FAIL++)); }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; ((WARN_COUNT++)); }
sec()  { printf "\n${BLUE}━━ %s ━━${NC}\n" "$1"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   LLM Cost Kit v3.6 — Verification Dashboard         ║"
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
  if [[ -f "$HOME/.local/cost/state.json" ]]; then
    plan=$(jq -r '.subscription.plan // "?"' "$HOME/.local/cost/state.json" 2>/dev/null)
    fee=$(jq -r '.subscription.fee_usd // "?"' "$HOME/.local/cost/state.json" 2>/dev/null)
    renews=$(jq -r '.subscription.renews_on // "?"' "$HOME/.local/cost/state.json" 2>/dev/null)
    if [[ "$plan" == "?" || "$plan" == "null" ]]; then
      warn "cost state.json exists but plan is unset — run: update-claude-cost --plan PLAN --fee FEE --renews YYYY-MM-DD"
    else
      pass "cost state initialized — plan=$plan  fee=\$$fee  renews=$renews"
    fi
  else
    warn "~/.local/cost/state.json missing — run update-claude-cost to initialize"
  fi
else
  fail "update-claude-cost not in ~/.local/bin/ — re-run setup.sh and accept the cumulative-tracking prompt"
fi

# ── Hourly LaunchAgent ───────────────────────────────────────────────────────
sec "Hourly cost pipeline"
PLIST="$HOME/Library/LaunchAgents/cumulative-cost-launchagent.plist"
if [[ -f "$PLIST" ]]; then
  if launchctl list 2>/dev/null | grep -q cumulative-cost; then
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
