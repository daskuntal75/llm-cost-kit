#!/bin/zsh
# =============================================================================
# llm-cost-kit — Unified Setup Wizard
# Version: 1.0 · github.com/[your-username]/llm-cost-kit
#
# Usage: bash setup.sh
#
# Reads config.yaml to determine which platforms are enabled and runs only
# the relevant setup steps. IDEMPOTENT — safe to re-run.
# =============================================================================

VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.yaml"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()    { printf "${GREEN}  ✓${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}  ⚠${NC}  %s\n" "$1"; }
err()   { printf "${RED}  ✗${NC}  %s\n" "$1"; }
info()  { printf "${BLUE}  →${NC}  %s\n" "$1"; }
title() { printf "\n${BOLD}▶ %s${NC}\n" "$1"; }
ask()   { printf "${BOLD}%s${NC} [y/N]: " "$1"; read -r ANS; [[ "$ANS" =~ ^[Yy]$ ]]; }

banner() {
  printf "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}\n"
  printf "${BOLD}║  llm-cost-kit — Unified Setup Wizard v%s                    ║${NC}\n" "$VERSION"
  printf "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
  printf "Reads config.yaml → runs only enabled platform adapters.\n\n"
}

# ── Read config.yaml (requires python3 or yq) ─────────────────────────────────
read_config() {
  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — falling back to interactive platform selection"
    PLATFORMS_ENABLED=()
    printf "Which platforms are you setting up? (space-separated: claude openai gemini)\n> "
    read -r -A PLATFORMS_ENABLED
    return
  fi

  PLATFORMS_ENABLED=($(python3 -c "
import re, sys
try:
    with open('$CONFIG') as f:
        content = f.read()
    # Parse enabled platforms from yaml (simple regex — no yaml lib needed)
    in_enabled = False
    for line in content.split('\n'):
        if 'enabled:' in line and 'platforms' not in line:
            in_enabled = True
            continue
        if in_enabled:
            m = re.match(r'\s+-\s+(\w+)', line)
            if m and not line.strip().startswith('#'):
                print(m.group(1))
            elif line.strip() and not line.strip().startswith('-') and ':' in line:
                break
except Exception as e:
    sys.stderr.write(str(e))
" 2>/dev/null))

  if [[ ${#PLATFORMS_ENABLED[@]} -eq 0 ]]; then
    warn "No platforms found in config.yaml or all are commented out."
    warn "Defaulting to: claude"
    PLATFORMS_ENABLED=(claude)
  fi
}

# ── Dependency checks ─────────────────────────────────────────────────────────
check_deps() {
  title "Dependencies"
  command -v node &>/dev/null && ok "node $(node --version)" || warn "node not found — required for Claude Code and MCP servers (nodejs.org)"
  command -v npm &>/dev/null  && ok "npm $(npm --version)" || warn "npm not found"
  command -v python3 &>/dev/null && ok "python3 $(python3 --version 2>&1 | cut -d' ' -f2)" || warn "python3 not found — config parsing uses fallback"
}

# ── Claude platform setup ─────────────────────────────────────────────────────
setup_claude() {
  title "Claude Platform Setup"

  # Install Claude Code
  if command -v claude &>/dev/null; then
    ok "Claude Code already installed: $(claude --version | head -1)"
  else
    info "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code && ok "Claude Code installed"
  fi

  # Install ccusage
  if command -v ccusage &>/dev/null; then
    ok "ccusage already installed"
  else
    npm install -g ccusage && ok "ccusage installed"
  fi

  # MCP configs
  mkdir -p ~/.claude/mcp-configs
  for cfg in mcp-saas mcp-work mcp-infra mcp-default; do
    SRC="$SCRIPT_DIR/platforms/claude/mcp-configs/${cfg}.json"
    DST=~/.claude/mcp-configs/${cfg}.json
    if [[ -f "$DST" ]]; then
      ok "$cfg.json already exists"
    elif [[ -f "$SRC" ]]; then
      cp "$SRC" "$DST" && ok "Copied $cfg.json"
    else
      warn "$cfg.json not found in platforms/claude/mcp-configs/"
    fi
  done

  # Shell aliases
  if grep -q "claude-saas" ~/.zshrc 2>/dev/null; then
    ok "Claude aliases already in ~/.zshrc"
  else
    cat >> ~/.zshrc << 'CLAUDE_ALIASES'

# ── llm-cost-kit: Claude aliases ─────────────────────────────────────────────
alias claude-saas="claude --mcp-config ~/.claude/mcp-configs/mcp-saas.json"
alias claude-work="claude --mcp-config ~/.claude/mcp-configs/mcp-work.json"
alias claude-infra="claude --mcp-config ~/.claude/mcp-configs/mcp-infra.json"
alias claude-x="claude --mcp-config ~/.claude/mcp-configs/mcp-default.json"
alias cu="ccusage"
alias cu-today="ccusage --since today"
alias agent-brief='echo "{
  \"task\": \"\",
  \"constraints\": [],
  \"inputs\": {},
  \"output_format\": \"\",
  \"context\": \"\"
}" | pbcopy && echo "Sub-agent brief copied"'
# ─────────────────────────────────────────────────────────────────────────────
CLAUDE_ALIASES
    ok "Claude aliases added to ~/.zshrc"
  fi

  # Deploy CLAUDE.md
  printf "\n  Where is your primary project directory? (e.g. ~/my-project, Enter to skip): "
  read -r PROJECT_PATH
  if [[ -n "$PROJECT_PATH" ]]; then
    PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
    [[ -d "$PROJECT_PATH" ]] && cp "$SCRIPT_DIR/platforms/claude/CLAUDE.md" "$PROJECT_PATH/" && ok "CLAUDE.md → $PROJECT_PATH/"
    warn "Edit CLAUDE.md — replace all [CUSTOMIZE] placeholders with your actual context"
  fi

  # Billing reminder (macOS only)
  if [[ "$(uname)" == "Darwin" ]]; then
    printf "\n  Name for billing reminder (used in LaunchAgent label, e.g. 'alex'): "
    read -r LABEL; LABEL="${LABEL:-user}"
    PLIST=~/Library/LaunchAgents/com.${LABEL}.claude-billing-reminder.plist
    if [[ ! -f "$PLIST" ]]; then
      cat > "$PLIST" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.${LABEL}.claude-billing-reminder</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/osascript</string><string>-e</string>
    <string>display notification "Check claude.ai/settings/usage — review model breakdown and extra credit spend." with title "Monthly Claude Cost Review" sound name "Glass"</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Day</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
PLISTEOF
      launchctl load "$PLIST" 2>/dev/null && ok "Billing reminder created (fires 1st of month, 9 AM)" || ok "Billing reminder plist created — load manually if needed"
    else
      ok "Billing reminder already exists"
    fi
  fi

  printf "\n${BOLD}Claude manual steps (cannot be scripted):${NC}\n"
  printf "  □  Settings → Memory → confirm ON\n"
  printf "  □  Settings → User Preferences → paste from core/OUTPUT_RULES.md\n"
  printf "  □  Create 4 Claude Projects with context-specific instructions\n"
  printf "  □  Cowork → Skills → install platforms/claude/SKILL.md\n"
  printf "  □  Cowork → Projects → create per-context projects + local folders\n"
  printf "  □  Settings → Billing → auto-reload OFF, spend limit set\n"
}

# ── OpenAI platform setup ─────────────────────────────────────────────────────
setup_openai() {
  title "OpenAI Platform Setup"

  # API key
  if grep -q "OPENAI_API_KEY" ~/.zshrc 2>/dev/null; then
    ok "OPENAI_API_KEY already in ~/.zshrc"
  else
    printf "\n  Enter OPENAI_API_KEY (input hidden, Enter to skip):\n"
    printf "  → platform.openai.com → API keys → Create new secret key\n> "
    read -r -s OAPI_KEY; printf "\n"
    if [[ -n "$OAPI_KEY" ]]; then
      echo "export OPENAI_API_KEY=\"$OAPI_KEY\"" >> ~/.zshrc
      ok "OPENAI_API_KEY added to ~/.zshrc"
    else
      warn "OPENAI_API_KEY skipped — add manually"
    fi
  fi

  # Python client
  if python3 -c "import openai" 2>/dev/null; then
    ok "openai Python package already installed"
  elif ask "  Install openai Python package?"; then
    pip3 install openai --quiet && ok "openai package installed" || warn "pip3 install failed — install manually"
  fi

  printf "\n${BOLD}OpenAI manual steps (cannot be scripted):${NC}\n"
  printf "  □  Copy platforms/openai/SYSTEM_PROMPT.md → paste into ChatGPT Project instructions\n"
  printf "  □  Settings → Personalization → Custom Instructions → paste from core/OUTPUT_RULES.md\n"
  printf "  □  Create one ChatGPT Project per context area\n"
  printf "  □  platform.openai.com → Settings → Limits → set monthly spend cap\n"
  printf "  □  Disable unused capabilities (browsing, code interpreter) per session\n"
  printf "  □  Monthly: platform.openai.com/usage → review model breakdown\n"
}

# ── Gemini platform setup ─────────────────────────────────────────────────────
setup_gemini() {
  title "Gemini Platform Setup"

  # API key
  if grep -q "GOOGLE_API_KEY\|GEMINI_API_KEY" ~/.zshrc 2>/dev/null; then
    ok "Gemini API key already in ~/.zshrc"
  else
    printf "\n  Enter GOOGLE_API_KEY (input hidden, Enter to skip):\n"
    printf "  → aistudio.google.com → API keys → Create API key\n> "
    read -r -s GAPI_KEY; printf "\n"
    if [[ -n "$GAPI_KEY" ]]; then
      echo "export GOOGLE_API_KEY=\"$GAPI_KEY\"" >> ~/.zshrc
      ok "GOOGLE_API_KEY added to ~/.zshrc"
    else
      warn "GOOGLE_API_KEY skipped — add manually"
    fi
  fi

  # Python client
  if python3 -c "import google.generativeai" 2>/dev/null; then
    ok "google-generativeai Python package already installed"
  elif ask "  Install google-generativeai Python package?"; then
    pip3 install google-generativeai --quiet && ok "google-generativeai installed" || warn "pip3 install failed"
  fi

  printf "\n${BOLD}Gemini manual steps (cannot be scripted):${NC}\n"
  printf "  □  Copy platforms/gemini/GEM_INSTRUCTIONS.md → create one Gem per context\n"
  printf "      gemini.google.com → Gems → New Gem → paste instructions\n"
  printf "  □  Enable only the Google Workspace extensions each Gem needs\n"
  printf "  □  For API: use AI Studio at aistudio.google.com for model testing\n"
  printf "  □  console.cloud.google.com → Billing → Budgets → set monthly alert\n"
  printf "  □  Monthly: console.cloud.google.com → APIs → Gemini API usage\n"
}

# ── Verification ──────────────────────────────────────────────────────────────
verify() {
  title "Verification"
  source ~/.zshrc 2>/dev/null

  for p in "${PLATFORMS_ENABLED[@]}"; do
    case $p in
      claude)
        command -v claude &>/dev/null && ok "claude: $(claude --version | head -1)" || err "claude: not found"
        command -v ccusage &>/dev/null && ok "ccusage: installed" || warn "ccusage: not found"
        [[ -d ~/.claude/mcp-configs ]] && ok "mcp-configs/ directory ready" || warn "mcp-configs/ missing"
        ;;
      openai)
        python3 -c "import openai" 2>/dev/null && ok "openai package: installed" || warn "openai package: not installed"
        grep -q "OPENAI_API_KEY" ~/.zshrc 2>/dev/null && ok "OPENAI_API_KEY: set" || warn "OPENAI_API_KEY: not set"
        ;;
      gemini)
        python3 -c "import google.generativeai" 2>/dev/null && ok "google-generativeai: installed" || warn "google-generativeai: not installed"
        grep -q "GOOGLE_API_KEY" ~/.zshrc 2>/dev/null && ok "GOOGLE_API_KEY: set" || warn "GOOGLE_API_KEY: not set"
        ;;
    esac
  done
}

# ── Universal steps ───────────────────────────────────────────────────────────
universal_steps() {
  title "Universal Setup (all platforms)"
  printf "\n${BOLD}Manual steps that apply to every platform:${NC}\n"
  printf "  □  Open core/OUTPUT_RULES.md → copy the User Preferences block\n"
  printf "      Paste into each platform's 'how you want responses' setting\n"
  printf "  □  Read core/PRINCIPLES.md — the 8 universal principles take ~10 min\n"
  printf "  □  Read core/SESSION_HYGIENE.md — thread management works everywhere\n"
  printf "  □  Set config.yaml → the single source of truth for all your preferences\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  banner
  check_deps
  read_config

  printf "\n${BOLD}Platforms enabled in config.yaml:${NC} ${PLATFORMS_ENABLED[*]}\n"
  printf "Edit config.yaml to enable/disable platforms or adjust preferences.\n\n"

  for platform in "${PLATFORMS_ENABLED[@]}"; do
    case $platform in
      claude) setup_claude ;;
      openai) setup_openai ;;
      gemini) setup_gemini ;;
      *) warn "Unknown platform '$platform' in config.yaml — skipping" ;;
    esac
  done

  universal_steps
  verify

  printf "\n${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}\n"
  printf "${BOLD}║  Setup Complete                                              ║${NC}\n"
  printf "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
  printf "Run: ${BOLD}source ~/.zshrc${NC}\n"
  printf "Then open ${BOLD}guide.html${NC} in your browser for the full interactive walkthrough.\n\n"
}

main
