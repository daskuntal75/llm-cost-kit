#!/bin/zsh
# =============================================================================
# llm-cost-kit — Kit Generator
# Usage: bash generate-kit.sh [platform]
#
# Platforms:
#   claude     → claude-cost-kit.zip      (Claude only)
#   openai     → openai-cost-kit.zip      (OpenAI/ChatGPT only)
#   gemini     → gemini-cost-kit.zip      (Gemini only)
#   all        → llm-cost-kit.zip         (All platforms — full generic kit)
#
# Output: ./dist/<name>.zip — ready to attach, upload, or share
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
PLATFORM="${1:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "${GREEN}  ✓${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC}  %s\n" "$1"; }
info() { printf "  →  %s\n" "$1"; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  printf "\n${BOLD}Usage:${NC} bash generate-kit.sh [platform]\n\n"
  printf "  claude   → claude-cost-kit.zip      (Claude Chat · Code · Cowork)\n"
  printf "  openai   → openai-cost-kit.zip      (ChatGPT · Custom GPTs · API)\n"
  printf "  gemini   → gemini-cost-kit.zip      (Gemini · Gems · AI Studio)\n"
  printf "  all      → llm-cost-kit.zip         (All platforms — full kit)\n\n"
  exit 1
}

[[ -z "$PLATFORM" ]] && usage
[[ "$PLATFORM" != "claude" && "$PLATFORM" != "openai" && "$PLATFORM" != "gemini" && "$PLATFORM" != "all" ]] && usage

# ── Map platform → output filename and display name ───────────────────────────
case $PLATFORM in
  claude) ZIP_NAME="claude-cost-kit";  DISPLAY="Claude" ;;
  openai) ZIP_NAME="openai-cost-kit";  DISPLAY="OpenAI / ChatGPT" ;;
  gemini) ZIP_NAME="gemini-cost-kit";  DISPLAY="Gemini" ;;
  all)    ZIP_NAME="llm-cost-kit";     DISPLAY="All Platforms (Generic)" ;;
esac

printf "\n${BOLD}Generating: $DISPLAY kit → $ZIP_NAME.zip${NC}\n\n"

# ── Staging directory ─────────────────────────────────────────────────────────
STAGE="$SCRIPT_DIR/.stage/$ZIP_NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE/core"
mkdir -p "$DIST_DIR"

# ── Always include: core universal files ─────────────────────────────────────
cp "$SCRIPT_DIR/core/PRINCIPLES.md"    "$STAGE/core/"
cp "$SCRIPT_DIR/core/OUTPUT_RULES.md"  "$STAGE/core/"
cp "$SCRIPT_DIR/core/SESSION_HYGIENE.md" "$STAGE/core/"
ok "core/ — universal principles, output rules, session hygiene"

# ── Always include: guide and setup ──────────────────────────────────────────
cp "$SCRIPT_DIR/guide.html" "$STAGE/"
ok "guide.html"

# ── Platform-specific: copy platform directory ───────────────────────────────
if [[ "$PLATFORM" == "all" ]]; then
  cp -r "$SCRIPT_DIR/platforms" "$STAGE/"
  cp "$SCRIPT_DIR/setup.sh" "$STAGE/"
  ok "platforms/ — claude, openai, gemini"
  ok "setup.sh — unified wizard"
else
  mkdir -p "$STAGE/platforms/$PLATFORM"
  cp -r "$SCRIPT_DIR/platforms/$PLATFORM/." "$STAGE/platforms/$PLATFORM/"
  ok "platforms/$PLATFORM/"

  # Platform-specific setup script (extract relevant function from setup.sh)
  generate_platform_setup "$PLATFORM" "$STAGE"
fi

# ── Generate config.yaml (pre-configured for target platform) ─────────────────
generate_config "$PLATFORM" "$STAGE"

# ── Generate README ───────────────────────────────────────────────────────────
generate_readme "$PLATFORM" "$STAGE" "$ZIP_NAME"

# ── Zip it ────────────────────────────────────────────────────────────────────
cd "$SCRIPT_DIR/.stage"
zip -r "$DIST_DIR/$ZIP_NAME.zip" "$ZIP_NAME/" -x "*.DS_Store" > /dev/null
ok "$ZIP_NAME.zip → dist/$ZIP_NAME.zip"

# Cleanup staging
rm -rf "$SCRIPT_DIR/.stage"

printf "\n${BOLD}Done.${NC} Share this file:\n"
printf "  ${GREEN}dist/$ZIP_NAME.zip${NC}\n"
printf "  Size: $(du -sh "$DIST_DIR/$ZIP_NAME.zip" | cut -f1)\n\n"
printf "Sharing options:\n"
printf "  Email / DM:    attach dist/$ZIP_NAME.zip directly\n"
printf "  GitHub:        gh release upload v1.0 dist/$ZIP_NAME.zip\n"
printf "  Google Drive:  upload and share the link\n\n"

# ── Helper: generate platform setup script ───────────────────────────────────
generate_platform_setup() {
  local platform=$1
  local stage=$2

  cat > "$stage/setup.sh" << SETUPEOF
#!/bin/zsh
# =============================================================================
# ${DISPLAY} Cost Kit — Setup Script
# Usage: bash setup.sh
# =============================================================================
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "\${GREEN}  ✓\${NC}  %s\n" "\$1"; }
warn() { printf "\${YELLOW}  ⚠\${NC}  %s\n" "\$1"; }

printf "\n\${BOLD}${DISPLAY} Cost Kit — Setup\${NC}\n\n"

SETUPEOF

  case $platform in
    claude)
      cat >> "$stage/setup.sh" << 'CLAUDE_SETUP'
# Claude Code
if command -v claude &>/dev/null; then ok "Claude Code: $(claude --version | head -1)"
else npm install -g @anthropic-ai/claude-code && ok "Claude Code installed"; fi

# ccusage
command -v ccusage &>/dev/null && ok "ccusage installed" || npm install -g ccusage

# MCP configs
mkdir -p ~/.claude/mcp-configs
for cfg in mcp-saas mcp-work mcp-infra mcp-default; do
  [[ ! -f ~/.claude/mcp-configs/${cfg}.json ]] && \
    cp "$SCRIPT_DIR/platforms/claude/mcp-configs/${cfg}.json" ~/.claude/mcp-configs/ && \
    ok "$cfg.json installed"
done

# Aliases
if ! grep -q "claude-saas" ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc << 'ALIASES'

# ── claude-cost-kit aliases ───────────────────────────────────────────────────
alias claude-saas="claude --mcp-config ~/.claude/mcp-configs/mcp-saas.json"
alias claude-work="claude --mcp-config ~/.claude/mcp-configs/mcp-work.json"
alias claude-infra="claude --mcp-config ~/.claude/mcp-configs/mcp-infra.json"
alias claude-x="claude --mcp-config ~/.claude/mcp-configs/mcp-default.json"
alias cu="ccusage"
alias cu-today="ccusage --since today"
alias agent-brief='echo "{\"task\":\"\",\"constraints\":[],\"inputs\":{},\"output_format\":\"\",\"context\":\"\"}" | pbcopy && echo "Copied"'
# ─────────────────────────────────────────────────────────────────────────────
ALIASES
  ok "Shell aliases added"
fi

printf "\n  Where is your primary project directory? (Enter to skip): "
read -r PROJECT_PATH
if [[ -n "$PROJECT_PATH" ]]; then
  PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
  [[ -d "$PROJECT_PATH" ]] && cp "$SCRIPT_DIR/platforms/claude/CLAUDE.md" "$PROJECT_PATH/" && ok "CLAUDE.md deployed"
  warn "Edit CLAUDE.md — replace [CUSTOMIZE] placeholders with your context"
fi

printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Settings → Memory → confirm ON\n"
printf "  □  Settings → User Preferences → paste from core/OUTPUT_RULES.md\n"
printf "  □  Create Claude Projects (one per context area)\n"
printf "  □  Cowork → Skills → install platforms/claude/SKILL.md\n"
printf "  □  Settings → Billing → auto-reload OFF, spend limit set\n"

printf "\nsource ~/.zshrc\n"
CLAUDE_SETUP
      ;;

    openai)
      cat >> "$stage/setup.sh" << 'OPENAI_SETUP'
# OpenAI API key
if grep -q "OPENAI_API_KEY" ~/.zshrc 2>/dev/null; then ok "OPENAI_API_KEY already set"
else
  printf "  Enter OPENAI_API_KEY (hidden, Enter to skip):\n"
  printf "  → platform.openai.com → API keys\n> "
  read -r -s K; printf "\n"
  [[ -n "$K" ]] && echo "export OPENAI_API_KEY=\"$K\"" >> ~/.zshrc && ok "OPENAI_API_KEY added"
fi

python3 -c "import openai" 2>/dev/null && ok "openai package installed" || \
  pip3 install openai --quiet && ok "openai installed"

printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Copy platforms/openai/SYSTEM_PROMPT.md → paste into ChatGPT Project instructions\n"
printf "  □  Settings → Personalization → Custom Instructions → paste from core/OUTPUT_RULES.md\n"
printf "  □  Create one ChatGPT Project per context area\n"
printf "  □  platform.openai.com → Settings → Limits → set monthly spend cap\n"
OPENAI_SETUP
      ;;

    gemini)
      cat >> "$stage/setup.sh" << 'GEMINI_SETUP'
# Gemini API key
if grep -q "GOOGLE_API_KEY" ~/.zshrc 2>/dev/null; then ok "GOOGLE_API_KEY already set"
else
  printf "  Enter GOOGLE_API_KEY (hidden, Enter to skip):\n"
  printf "  → aistudio.google.com → API keys\n> "
  read -r -s K; printf "\n"
  [[ -n "$K" ]] && echo "export GOOGLE_API_KEY=\"$K\"" >> ~/.zshrc && ok "GOOGLE_API_KEY added"
fi

python3 -c "import google.generativeai" 2>/dev/null && ok "google-generativeai installed" || \
  pip3 install google-generativeai --quiet && ok "google-generativeai installed"

printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Copy platforms/gemini/GEM_INSTRUCTIONS.md → create one Gem per context\n"
printf "      gemini.google.com → Gems → New Gem → paste instructions\n"
printf "  □  Enable only the Workspace extensions each Gem needs\n"
printf "  □  console.cloud.google.com → Billing → Budgets → set monthly alert\n"
GEMINI_SETUP
      ;;
  esac

  chmod +x "$stage/setup.sh"
  ok "setup.sh (platform-specific)"
}

# ── Helper: generate pre-configured config.yaml ──────────────────────────────
generate_config() {
  local platform=$1
  local stage=$2

  # For 'all', copy the full config.yaml as-is
  if [[ "$platform" == "all" ]]; then
    cp "$SCRIPT_DIR/config.yaml" "$stage/"
    ok "config.yaml (all platforms)"
    return
  fi

  # For a single platform, write a pre-configured version
  python3 - "$platform" "$stage/config.yaml" << 'PYEOF'
import sys

platform = sys.argv[1]
outpath  = sys.argv[2]

routing = {
  "claude": {
    "default": "claude-sonnet-4-6",
    "sub_tasks": "claude-haiku-4-5-20251001",
    "escalate": "claude-opus-4-6",
    "escalate_policy": '"only after 2 failures on same task"'
  },
  "openai": {
    "default": "gpt-4o",
    "sub_tasks": "gpt-4o-mini",
    "escalate": "o3",
    "escalate_policy": '"2 gpt-4o failures OR explicitly reasoning-heavy task"'
  },
  "gemini": {
    "default": "gemini-2.0-flash",
    "sub_tasks": "gemini-1.5-flash-8b",
    "escalate": "gemini-2.5-pro",
    "escalate_policy": '"2 flash failures OR task requires >500K context window"'
  }
}

tool_map = {
  "claude": {"saas": "[supabase, stripe, github]", "work": "[google-calendar, gmail]", "infra": "[github]", "default": "[]"},
  "openai": {"saas": "[code_interpreter, function_calling]", "work": "[]", "infra": "[function_calling, code_interpreter]", "default": "[]"},
  "gemini": {"saas": "[google_drive, github]", "work": "[google_calendar, gmail]", "infra": "[github]", "default": "[]"}
}

r = routing[platform]
t = tool_map[platform]

config = f"""# {platform.title()} Cost Kit — Configuration
# ─────────────────────────────────────────────────────────────────────────────
# Pre-configured for {platform.title()}. Edit [CUSTOMIZE] sections with your context.
# ─────────────────────────────────────────────────────────────────────────────

platforms:
  enabled:
    - {platform}

response_style:
  lead_with_answer: true
  no_openers: true
  no_closers: true
  tables_over_prose: true
  one_recommendation: true
  answer_yes_no_first: true

token_budgets:
  quick: 300
  deep_work: 800
  build: 1200
  research: 600
  escalate: 1000

model_routing:
  {platform}:
    default: {r['default']}
    sub_tasks: {r['sub_tasks']}
    escalate: {r['escalate']}
    escalate_policy: {r['escalate_policy']}

session_hygiene:
  turn_warning: 12
  turn_reset: 15
  summary_max_words: 150
  idle_threshold_minutes: 5

billing:
  auto_reload: false
  monthly_review_day: 1
  alert_balance_below: 50

# ── Your project contexts  [CUSTOMIZE] ───────────────────────────────────────
contexts:
  - name: "SaaS Project"
    alias: saas
    description: "[Your SaaS or app project]"
    tools: {t['saas']}

  - name: "Work Tasks"
    alias: work
    description: "[Work productivity context]"
    tools: {t['work']}

  - name: "AI Infrastructure"
    alias: infra
    description: "[AI agent projects and infrastructure]"
    tools: {t['infra']}

  - name: "Default"
    alias: default
    description: "General purpose — no tools loaded"
    tools: {t['default']}
"""

with open(outpath, 'w') as f:
    f.write(config)
print("ok")
PYEOF

  ok "config.yaml (pre-configured for $PLATFORM)"
}

# ── Helper: generate platform-specific README ─────────────────────────────────
generate_readme() {
  local platform=$1
  local stage=$2
  local zip_name=$3

  case $platform in
    claude)
      cat > "$stage/README.md" << 'READMEOF'
# claude-cost-kit

**Cut Claude costs 40–70% without losing quality.**
Works with Claude Chat · Claude Code · Cowork.

## Quick Start

```bash
bash setup.sh
source ~/.zshrc
```

## What's Included

| File | Purpose |
|---|---|
| `config.yaml` | Your preferences — edit once |
| `setup.sh` | Installs Claude Code, ccusage, MCP configs, shell aliases |
| `platforms/claude/CLAUDE.md` | Drop into project root — governs Claude Code sessions |
| `platforms/claude/SKILL.md` | Install in Cowork → Skills — auto-detectors + nudges |
| `platforms/claude/mcp-configs/` | 4 context-scoped MCP configs |
| `core/PRINCIPLES.md` | 8 universal token efficiency principles |
| `core/OUTPUT_RULES.md` | Paste-anywhere response discipline rules |
| `core/SESSION_HYGIENE.md` | Thread management protocol |
| `guide.html` | Full interactive guide — open in browser |

## Shell Aliases (added by setup.sh)

| Alias | Loads | Use for |
|---|---|---|
| `claude-saas` | Supabase + Stripe + GitHub | SaaS / app dev |
| `claude-work` | Calendar + Gmail | Work tasks |
| `claude-infra` | GitHub only | AI infra / agents |
| `claude-x` | Nothing | Lean default |
| `cu` | — | Token usage report |
| `agent-brief` | — | Sub-agent JSON template → clipboard |

## Manual Steps (Claude.ai UI)

- [ ] Settings → Memory → confirm ON
- [ ] Settings → User Preferences → paste from `core/OUTPUT_RULES.md`
- [ ] Create Claude Projects, one per context area
- [ ] Cowork → Skills → install `platforms/claude/SKILL.md`
- [ ] Settings → Billing → auto-reload OFF, spend limit set

Open `guide.html` in your browser for the full walkthrough.

---
MIT License
READMEOF
      ;;

    openai)
      cat > "$stage/README.md" << 'READMEOF'
# openai-cost-kit

**Cut ChatGPT/OpenAI costs 40–70% without losing quality.**
Works with ChatGPT, Custom GPTs, and the OpenAI API.

## Quick Start

```bash
bash setup.sh
```

## What's Included

| File | Purpose |
|---|---|
| `config.yaml` | Your preferences — edit once |
| `setup.sh` | Installs OpenAI Python package, sets API key |
| `platforms/openai/SYSTEM_PROMPT.md` | Paste into ChatGPT Projects or Custom GPT builder |
| `core/PRINCIPLES.md` | 8 universal token efficiency principles |
| `core/OUTPUT_RULES.md` | Paste into ChatGPT Custom Instructions |
| `core/SESSION_HYGIENE.md` | Thread management protocol |
| `guide.html` | Full interactive guide — open in browser |

## Key Optimizations

| Action | Saving |
|---|---|
| gpt-4o-mini for simple tasks | ~10–30× cheaper than gpt-4o |
| Disable unused capabilities (browsing, code interpreter) | ~18K tokens/msg each |
| 150-word summary at turn 15 | ~95% context reduction |
| No openers/closers in Custom Instructions | 20–60 tokens per response |
| o3 only after 2 gpt-4o failures | o3 ≈ 50× gpt-4o cost |

## Manual Steps (ChatGPT UI)

- [ ] Paste `platforms/openai/SYSTEM_PROMPT.md` into ChatGPT Project instructions
- [ ] Settings → Personalization → Custom Instructions → paste from `core/OUTPUT_RULES.md`
- [ ] Create one ChatGPT Project per context area
- [ ] platform.openai.com → Settings → Limits → set monthly spend cap

Open `guide.html` in your browser for the full walkthrough.

---
MIT License
READMEOF
      ;;

    gemini)
      cat > "$stage/README.md" << 'READMEOF'
# gemini-cost-kit

**Cut Gemini costs 40–70% without losing quality.**
Works with Gemini Advanced, Gems, and the Google Gemini API.

## Quick Start

```bash
bash setup.sh
```

## What's Included

| File | Purpose |
|---|---|
| `config.yaml` | Your preferences — edit once |
| `setup.sh` | Installs google-generativeai package, sets API key |
| `platforms/gemini/GEM_INSTRUCTIONS.md` | Paste into Gem builder or Google AI Studio |
| `core/PRINCIPLES.md` | 8 universal token efficiency principles |
| `core/OUTPUT_RULES.md` | Paste into Gem instructions |
| `core/SESSION_HYGIENE.md` | Thread management protocol |
| `guide.html` | Full interactive guide — open in browser |

## Key Optimizations

| Action | Saving |
|---|---|
| gemini-1.5-flash-8b for simple tasks (API) | Very cheap vs Flash/Pro |
| Disable unused Workspace extensions | ~18K tokens/msg each |
| 150-word summary at turn 15 | ~95% context reduction |
| gemini-2.5-pro only after 2 Flash failures | Pro significantly more expensive |
| One Gem per context (native scoping) | Prevents cross-context overhead |

## Manual Steps (Gemini UI)

- [ ] Paste `platforms/gemini/GEM_INSTRUCTIONS.md` into Gem builder (one Gem per context)
- [ ] Enable only the Workspace extensions each Gem needs
- [ ] console.cloud.google.com → Billing → Budgets → set monthly alert (API users)

Open `guide.html` in your browser for the full walkthrough.

---
MIT License
READMEOF
      ;;

    all)
      cp "$SCRIPT_DIR/README.md" "$stage/"
      ok "README.md (full kit)"
      ;;
  esac

  [[ "$platform" != "all" ]] && ok "README.md (platform-specific)"
}
