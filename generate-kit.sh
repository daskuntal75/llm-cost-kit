#!/bin/zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
PLATFORM="${1:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "${GREEN}  ✓${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC}  %s\n" "$1"; }

usage() {
  printf "\n${BOLD}Usage:${NC} bash generate-kit.sh [platform]\n\n"
  printf "  claude   → claude-cost-kit.zip\n"
  printf "  openai   → openai-cost-kit.zip\n"
  printf "  gemini   → gemini-cost-kit.zip\n"
  printf "  all      → llm-cost-kit.zip\n\n"
  exit 1
}

generate_platform_setup() {
  local platform=$1
  local stage=$2
  local display=$3

  cat > "$stage/setup.sh" << SETUPEOF
#!/bin/zsh
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "\${GREEN}  ✓\${NC}  %s\n" "\$1"; }
warn() { printf "\${YELLOW}  ⚠\${NC}  %s\n" "\$1"; }
printf "\n\${BOLD}${display} Cost Kit — Setup\${NC}\n\n"
SETUPEOF

  case $platform in
    claude)
      cat >> "$stage/setup.sh" << 'CLAUDE_SETUP'
command -v claude &>/dev/null && ok "Claude Code: $(claude --version | head -1)" || \
  { npm install -g @anthropic-ai/claude-code && ok "Claude Code installed"; }

command -v ccusage &>/dev/null && ok "ccusage installed" || \
  { npm install -g ccusage && ok "ccusage installed"; }

mkdir -p ~/.claude/mcp-configs
for cfg in mcp-saas mcp-work mcp-infra mcp-default; do
  DST=~/.claude/mcp-configs/${cfg}.json
  SRC="$SCRIPT_DIR/platforms/claude/mcp-configs/${cfg}.json"
  [[ ! -f "$DST" && -f "$SRC" ]] && cp "$SRC" "$DST" && ok "$cfg.json installed"
done

if ! grep -q "claude-saas" ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc << 'ALIASES'

# ── claude-cost-kit ───────────────────────────────────────────────────────────
alias claude-saas="claude --mcp-config ~/.claude/mcp-configs/mcp-saas.json"
alias claude-work="claude --mcp-config ~/.claude/mcp-configs/mcp-work.json"
alias claude-infra="claude --mcp-config ~/.claude/mcp-configs/mcp-infra.json"
alias claude-x="claude --mcp-config ~/.claude/mcp-configs/mcp-default.json"
alias cu="ccusage"
alias cu-today="ccusage --since today"
alias agent-brief='echo "{\"task\":\"\",\"constraints\":[],\"inputs\":{},\"output_format\":\"\",\"context\":\"\"}" | pbcopy && echo "Copied"'
# ─────────────────────────────────────────────────────────────────────────────
ALIASES
  ok "Shell aliases added — run: source ~/.zshrc"
fi

printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Settings → Memory → confirm ON\n"
printf "  □  Settings → User Preferences → paste from core/OUTPUT_RULES.md\n"
printf "  □  Create Claude Projects (one per context area)\n"
printf "  □  Cowork → Skills → install platforms/claude/SKILL.md\n"
printf "  □  Settings → Billing → auto-reload OFF, spend limit set\n"
printf "\nOpen guide.html in your browser for the full walkthrough.\n"
CLAUDE_SETUP
      ;;

    openai)
      cat >> "$stage/setup.sh" << 'OPENAI_SETUP'
if grep -q "OPENAI_API_KEY" ~/.zshrc 2>/dev/null; then ok "OPENAI_API_KEY already set"
else
  printf "  Enter OPENAI_API_KEY (hidden, Enter to skip):\n  → platform.openai.com → API keys\n> "
  read -r -s K; printf "\n"
  [[ -n "$K" ]] && echo "export OPENAI_API_KEY=\"$K\"" >> ~/.zshrc && ok "OPENAI_API_KEY added"
fi
python3 -c "import openai" 2>/dev/null && ok "openai package installed" || \
  pip3 install openai --quiet && ok "openai installed"
printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Paste platforms/openai/SYSTEM_PROMPT.md into ChatGPT Project instructions\n"
printf "  □  Settings → Personalization → Custom Instructions → paste from core/OUTPUT_RULES.md\n"
printf "  □  platform.openai.com → Settings → Limits → set monthly spend cap\n"
OPENAI_SETUP
      ;;

    gemini)
      cat >> "$stage/setup.sh" << 'GEMINI_SETUP'
if grep -q "GOOGLE_API_KEY" ~/.zshrc 2>/dev/null; then ok "GOOGLE_API_KEY already set"
else
  printf "  Enter GOOGLE_API_KEY (hidden, Enter to skip):\n  → aistudio.google.com → API keys\n> "
  read -r -s K; printf "\n"
  [[ -n "$K" ]] && echo "export GOOGLE_API_KEY=\"$K\"" >> ~/.zshrc && ok "GOOGLE_API_KEY added"
fi
python3 -c "import google.generativeai" 2>/dev/null && ok "google-generativeai installed" || \
  pip3 install google-generativeai --quiet && ok "installed"
printf "\n${BOLD}Manual steps:${NC}\n"
printf "  □  Paste platforms/gemini/GEM_INSTRUCTIONS.md into Gem builder\n"
printf "  □  console.cloud.google.com → Billing → Budgets → set monthly alert\n"
GEMINI_SETUP
      ;;
  esac

  chmod +x "$stage/setup.sh"
  ok "setup.sh"
}

generate_config() {
  local platform=$1
  local stage=$2

  if [[ "$platform" == "all" ]]; then
    cp "$SCRIPT_DIR/config.yaml" "$stage/"
    ok "config.yaml (all platforms)"
    return
  fi

  python3 - "$platform" "$stage/config.yaml" << 'PYEOF'
import sys
platform = sys.argv[1]
outpath  = sys.argv[2]
routing = {
  "claude": ("claude-sonnet-4-6", "claude-haiku-4-5-20251001", "claude-opus-4-6"),
  "openai": ("gpt-4o", "gpt-4o-mini", "o3"),
  "gemini": ("gemini-2.0-flash", "gemini-1.5-flash-8b", "gemini-2.5-pro"),
}
tools = {
  "claude": ("[supabase, stripe, github]", "[google-calendar, gmail]", "[github]", "[]"),
  "openai": ("[code_interpreter, function_calling]", "[]", "[function_calling]", "[]"),
  "gemini": ("[google_drive, github]", "[google_calendar, gmail]", "[github]", "[]"),
}
d, s, e = routing[platform]
ts, tw, ti, td = tools[platform]
config = f"""# {platform.title()} Cost Kit — Configuration
platforms:
  enabled:
    - {platform}

response_style:
  lead_with_answer: true
  no_openers: true
  no_closers: true
  tables_over_prose: true
  one_recommendation: true

token_budgets:
  quick: 300
  deep_work: 800
  build: 1200
  research: 600

model_routing:
  {platform}:
    default: {d}
    sub_tasks: {s}
    escalate: {e}

session_hygiene:
  turn_warning: 12
  turn_reset: 15
  summary_max_words: 150
  idle_threshold_minutes: 5

billing:
  auto_reload: false
  monthly_review_day: 1
  alert_balance_below: 50

# ── Your project contexts [CUSTOMIZE] ────────────────────────────────────────
contexts:
  - name: "SaaS Project"
    alias: saas
    description: "[Your SaaS or app project]"
    tools: {ts}
  - name: "Work Tasks"
    alias: work
    description: "[Work productivity context]"
    tools: {tw}
  - name: "AI Infrastructure"
    alias: infra
    description: "[AI agent projects]"
    tools: {ti}
  - name: "Default"
    alias: default
    description: "General purpose — no tools loaded"
    tools: {td}
"""
with open(outpath, 'w') as f:
    f.write(config)
PYEOF
  ok "config.yaml (pre-configured for $platform)"
}

generate_readme() {
  local platform=$1
  local stage=$2

  case $platform in
    claude)
      cat > "$stage/README.md" << 'EOF'
# claude-cost-kit

Cut Claude costs 40–70% without losing quality.
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
| `setup.sh` | Installs Claude Code, ccusage, MCP configs, aliases |
| `platforms/claude/CLAUDE.md` | Drop into project root |
| `platforms/claude/SKILL.md` | Install in Cowork → Skills |
| `platforms/claude/mcp-configs/` | 4 context-scoped MCP configs |
| `core/` | Universal principles, output rules, session hygiene |
| `guide.html` | Full interactive guide — open in browser |

## Manual Steps
- [ ] Settings → Memory → confirm ON
- [ ] Settings → User Preferences → paste from `core/OUTPUT_RULES.md`
- [ ] Create Claude Projects, one per context area
- [ ] Cowork → Skills → install `platforms/claude/SKILL.md`
- [ ] Settings → Billing → auto-reload OFF, spend limit set

MIT License
EOF
      ;;
    openai)
      cat > "$stage/README.md" << 'EOF'
# openai-cost-kit

Cut ChatGPT/OpenAI costs 40–70% without losing quality.

## Quick Start
```bash
bash setup.sh
```

## Manual Steps
- [ ] Paste `platforms/openai/SYSTEM_PROMPT.md` into ChatGPT Project instructions
- [ ] Settings → Personalization → Custom Instructions → paste from `core/OUTPUT_RULES.md`
- [ ] platform.openai.com → Settings → Limits → set monthly spend cap

MIT License
EOF
      ;;
    gemini)
      cat > "$stage/README.md" << 'EOF'
# gemini-cost-kit

Cut Gemini costs 40–70% without losing quality.

## Quick Start
```bash
bash setup.sh
```

## Manual Steps
- [ ] Paste `platforms/gemini/GEM_INSTRUCTIONS.md` into Gem builder
- [ ] console.cloud.google.com → Billing → Budgets → set monthly alert

MIT License
EOF
      ;;
    all)
      cp "$SCRIPT_DIR/README.md" "$stage/"
      ok "README.md"
      ;;
  esac
  [[ "$platform" != "all" ]] && ok "README.md"
}

# ── Main ──────────────────────────────────────────────────────────────────────
[[ -z "$PLATFORM" ]] && usage
[[ "$PLATFORM" != "claude" && "$PLATFORM" != "openai" && "$PLATFORM" != "gemini" && "$PLATFORM" != "all" ]] && usage

case $PLATFORM in
  claude) ZIP_NAME="claude-cost-kit"; DISPLAY="Claude" ;;
  openai) ZIP_NAME="openai-cost-kit"; DISPLAY="OpenAI / ChatGPT" ;;
  gemini) ZIP_NAME="gemini-cost-kit"; DISPLAY="Gemini" ;;
  all)    ZIP_NAME="llm-cost-kit";    DISPLAY="All Platforms" ;;
esac

printf "\n${BOLD}Generating: $DISPLAY → $ZIP_NAME.zip${NC}\n\n"

STAGE="$SCRIPT_DIR/.stage/$ZIP_NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE/core"
mkdir -p "$DIST_DIR"

cp "$SCRIPT_DIR/core/PRINCIPLES.md"     "$STAGE/core/"
cp "$SCRIPT_DIR/core/OUTPUT_RULES.md"   "$STAGE/core/"
cp "$SCRIPT_DIR/core/SESSION_HYGIENE.md" "$STAGE/core/"
ok "core/"

cp "$SCRIPT_DIR/guide.html" "$STAGE/"
ok "guide.html"

if [[ "$PLATFORM" == "all" ]]; then
  cp -r "$SCRIPT_DIR/platforms" "$STAGE/"
  cp "$SCRIPT_DIR/setup.sh" "$STAGE/"
  ok "platforms/ (all)"
  ok "setup.sh (unified)"
else
  mkdir -p "$STAGE/platforms/$PLATFORM"
  cp -r "$SCRIPT_DIR/platforms/$PLATFORM/." "$STAGE/platforms/$PLATFORM/"
  ok "platforms/$PLATFORM/"
  generate_platform_setup "$PLATFORM" "$STAGE" "$DISPLAY"
fi

generate_config "$PLATFORM" "$STAGE"
generate_readme "$PLATFORM" "$STAGE"

cd "$SCRIPT_DIR/.stage"
zip -r "$DIST_DIR/$ZIP_NAME.zip" "$ZIP_NAME/" -x "*.DS_Store" > /dev/null
rm -rf "$SCRIPT_DIR/.stage"

ok "$ZIP_NAME.zip → dist/$ZIP_NAME.zip"
printf "\n${BOLD}Done.${NC}\n"
printf "  File: dist/$ZIP_NAME.zip\n"
printf "  Size: $(du -sh "$DIST_DIR/$ZIP_NAME.zip" | cut -f1)\n\n"
