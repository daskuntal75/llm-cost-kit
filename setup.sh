#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.2 — Setup
# Usage: bash setup.sh
# Idempotent — safe to re-run.
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok() { printf "${GREEN}  ✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; }
info() { printf "${BLUE}  →${NC} %s\n" "$1"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   LLM Cost Kit v3.6 — Setup                          ║"
echo "║   (Claude Chat + Cowork + Code)                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Pre-flight check ────────────────────────────────────────────────────────
# v3.6: bootstrap-macos.sh handles brew/node/jq/fswatch/Claude Desktop on a
# fresh Mac. This script assumes those exist. Quick sanity check.
MISSING=()
for tool in node npm jq; do
  command -v "$tool" &>/dev/null || MISSING+=("$tool")
done
if (( ${#MISSING[@]} > 0 )); then
  warn "Missing prerequisites: ${MISSING[*]}"
  warn "On a fresh Mac, run first:  bash bootstrap-macos.sh"
  echo ""
fi

# ── Detect kit type ──────────────────────────────────────────────────────────
KIT_TYPE="unknown"
if [[ -d "$SCRIPT_DIR/platforms/claude" && -d "$SCRIPT_DIR/platforms/openai" ]]; then
  KIT_TYPE="all"
elif [[ -d "$SCRIPT_DIR/platforms/claude" ]]; then
  KIT_TYPE="claude"
elif [[ -d "$SCRIPT_DIR/platforms/openai" ]]; then
  KIT_TYPE="openai"
elif [[ -d "$SCRIPT_DIR/platforms/gemini" ]]; then
  KIT_TYPE="gemini"
fi

info "Kit type detected: $KIT_TYPE"

# ── Skip Claude-specific setup if not Claude kit ─────────────────────────────
if [[ "$KIT_TYPE" == "openai" ]]; then
  echo ""
  echo "OpenAI kit setup is purely manual:"
  echo "1. Go to ChatGPT → Settings → Personalization → Custom Instructions"
  echo "2. Paste contents of core/OUTPUT_RULES.md"
  echo "3. (Optional) Build Custom GPTs using platforms/openai/SYSTEM_PROMPT.md"
  echo ""
  echo "See platforms/openai/HIERARCHY.md for full layer details."
  exit 0
fi

if [[ "$KIT_TYPE" == "gemini" ]]; then
  echo ""
  echo "Gemini kit setup is purely manual:"
  echo "1. Go to Gemini app → Settings → Personal Context"
  echo "2. Paste contents of core/OUTPUT_RULES.md"
  echo "3. (Optional) Build Gems using platforms/gemini/GEM_INSTRUCTIONS.md"
  echo ""
  echo "See platforms/gemini/HIERARCHY.md for full layer details."
  exit 0
fi

# ── Claude / All kit: install Claude Code, ccusage, MCP configs ──────────────

# Claude Code
if command -v claude &>/dev/null; then
  ok "Claude Code installed: $(claude --version 2>/dev/null | head -1)"
else
  info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code installed"
fi

# ccusage
if command -v ccusage &>/dev/null; then
  ok "ccusage installed"
else
  info "Installing ccusage..."
  npm install -g ccusage
  ok "ccusage installed"
fi

# fswatch (for skills-source auto-sync)
if command -v fswatch &>/dev/null; then
  ok "fswatch installed"
else
  warn "fswatch not installed. Install with: brew install fswatch"
fi

# MCP configs
mkdir -p ~/.claude/mcp-configs
if [[ -d "$SCRIPT_DIR/platforms/claude/mcp-configs" ]]; then
  cp "$SCRIPT_DIR/platforms/claude/mcp-configs/"*.json ~/.claude/mcp-configs/ 2>/dev/null || true
  ok "MCP configs deployed to ~/.claude/mcp-configs/"
fi

# Shell aliases
if grep -q "# LLM Cost Kit aliases" ~/.zshrc 2>/dev/null; then
  ok "Aliases already in ~/.zshrc"
else
  cat >> ~/.zshrc << 'ALIASES'

# LLM Cost Kit aliases
alias claude-lean="claude --mcp-config ~/.claude/mcp-configs/mcp-default.json"
alias claude-gh="claude --mcp-config ~/.claude/mcp-configs/mcp-minimal.json"
alias cu="ccusage"
alias cu-today="ccusage --since today"

# Sub-agent brief template
alias agent-brief='echo "{
  \"task\": \"\",
  \"constraints\": [],
  \"inputs\": {},
  \"output_format\": \"\",
  \"context\": \"2-3 sentences max\",
  \"task_budget\": 50000,
  \"effort\": \"medium\"
}" | pbcopy && echo "Sub-agent brief copied to clipboard"'

ALIASES
  ok "Aliases added to ~/.zshrc"
fi

# ── Optional: bootstrap skills-source repo ───────────────────────────────────
echo ""
read -k 1 "REPLY?Set up skills-source single source-of-truth repo at ~/dev/skills-source? [y/N] "
echo ""
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  bash "$SCRIPT_DIR/platforms/claude/scripts/init-git.sh"

  # Copy the skill templates
  mkdir -p ~/dev/skills-source/skills/cost-optimizer
  mkdir -p ~/dev/skills-source/skills/memory-first
  mkdir -p ~/dev/skills-source/skills/status-rollup
  cp "$SCRIPT_DIR/platforms/claude/skills/cost-optimizer/SKILL.md" ~/dev/skills-source/skills/cost-optimizer/SKILL.md
  cp "$SCRIPT_DIR/platforms/claude/skills/memory-first/SKILL.md" ~/dev/skills-source/skills/memory-first/SKILL.md
  cp "$SCRIPT_DIR/platforms/claude/skills/status-rollup/SKILL.md" ~/dev/skills-source/skills/status-rollup/SKILL.md
  ok "Skills templates copied"

  # Copy scripts
  cp "$SCRIPT_DIR/platforms/claude/scripts/"*.sh ~/dev/skills-source/scripts/
  chmod +x ~/dev/skills-source/scripts/*.sh
  ok "Scripts copied to ~/dev/skills-source/scripts/"

  # Copy MCP configs to skills-source as well
  mkdir -p ~/dev/skills-source/mcp-configs
  cp "$SCRIPT_DIR/platforms/claude/mcp-configs/"*.json ~/dev/skills-source/mcp-configs/ 2>/dev/null || true
  ok "MCP configs copied to skills-source"

  # Build the skills
  bash ~/dev/skills-source/scripts/build-skills.sh
  ok "Skills built (.skill zips in ~/dev/skills-source/.build/)"

  echo ""
  echo "Next:"
  echo "1. Add a private GitHub remote: cd ~/dev/skills-source && git remote add origin git@github.com:USER/skills-source.git"
  echo "2. Install the watcher: bash ~/dev/skills-source/scripts/watcher-launchagent.sh"
  echo "3. Symlink skills into Claude consumer locations:"
  echo "     mkdir -p ~/.claude/skills ~/.agents/skills"
  echo "     for f in ~/dev/skills-source/.build/*.skill; do"
  echo "       ln -sfn \$f ~/.claude/skills/\$(basename \$f)"
  echo "       ln -sfn \$f ~/.agents/skills/\$(basename \$f)"
  echo "     done"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Automated Setup Complete                           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Manual steps remaining (see core/HIERARCHY.md):"
echo ""
echo "  L4 (universal) — Claude Settings → Profile → Preferences"
echo "    → Paste core/OUTPUT_RULES.md content"
echo ""
echo "  L2 (Cowork global) — Claude Cowork → Settings → Global Instructions"
echo "    → Paste platforms/claude/cowork-global-instructions.md content"
echo ""
echo "  L1 (Cowork project) — For each Cowork project:"
echo "    → Paste tailored content from platforms/claude/cowork-project-instructions.md"
echo ""
echo "  L7 (Chat project) — For each Chat project:"
echo "    → Paste tailored content from platforms/claude/chat-project-instructions.md"
echo ""
echo "  L3 (Code) — For each Claude Code project:"
echo "    → Symlink: ln -sfn ~/dev/skills-source/claude-md/<project>.md <project>/CLAUDE.md"
echo "    → Add 'CLAUDE.md*' to <project>/.gitignore"
echo ""
echo "  L6 (Skills) — Claude Cowork → Customize → Skills:"
echo "    → Install from file: ~/dev/skills-source/.build/cost-optimizer.skill"
echo "    → Install from file: ~/dev/skills-source/.build/memory-first.skill"
echo "    → Install from file: ~/dev/skills-source/.build/status-rollup.skill"
echo ""
echo "  MCP Connectors — https://claude.ai/settings/connectors"
echo "    → Re-auth on each new machine: Gmail, Drive, Calendar,"
echo "      Granola, Gamma, Stripe, Supabase (any you previously had)."
echo ""
echo "Verify everything end-to-end:  bash verify.sh"

# ── Cumulative cost tracking (v3.3) ─────────────────────────────────────────
echo ""
read -k 1 "REPLY?Install cumulative cost tracking (update-claude-cost CLI + daily LaunchAgent)? [y/N] "
echo ""
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  mkdir -p ~/.local/bin
  cp "$SCRIPT_DIR/platforms/claude/cumulative/update-claude-cost.sh" ~/.local/bin/update-claude-cost
  chmod +x ~/.local/bin/update-claude-cost

  # Make sure jq is available
  if ! command -v jq &>/dev/null; then
    echo "Installing jq (required for cost tracking)..."
    brew install jq
  fi

  # Initialize the cost file
  ~/.local/bin/update-claude-cost > /dev/null 2>&1
  ok "update-claude-cost CLI installed at ~/.local/bin/"

  # Install LaunchAgent for daily auto-refresh
  bash "$SCRIPT_DIR/platforms/claude/cumulative/cumulative-cost-launchagent.sh"
  ok "Daily LaunchAgent installed (refreshes Code spend from ccusage at 8:30 AM)"

  echo ""
  echo "Cumulative tracking ready. Run anytime: update-claude-cost"
  echo "First-time setup:"
  echo "  1. Visit Settings → Usage on claude.ai"
  echo "  2. Run: update-claude-cost --chat <your month-to-date amount>"
fi
