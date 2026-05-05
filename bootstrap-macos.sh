#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.6 — macOS Pre-flight Bootstrap
# Usage: bash bootstrap-macos.sh
#
# Run this FIRST on a fresh Mac (or Mac Mini) before setup.sh.
# Installs the prerequisites that setup.sh assumes already exist:
#   - Xcode Command Line Tools
#   - Homebrew
#   - node + npm  (for `claude`, `ccusage`)
#   - jq          (for cost-state JSON ops)
#   - fswatch     (skills-source watcher)
#   - git, gh     (repo + GitHub auth)
#   - Claude Desktop app (via Homebrew cask, with fallback URL)
#
# Then guides you through one-time auth flows you cannot skip.
# Idempotent — safe to re-run.
# =============================================================================

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "${GREEN}  ✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; }
info() { printf "${BLUE}  →${NC} %s\n" "$1"; }
err()  { printf "${RED}  ✗${NC} %s\n" "$1"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   LLM Cost Kit v3.6 — macOS Pre-flight Bootstrap     ║"
echo "║   Run this BEFORE setup.sh on a fresh Mac.           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── macOS sanity check ──────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This script targets macOS. For Linux, install node/jq/fswatch via your package manager and skip to setup.sh."
  exit 1
fi

ARCH="$(uname -m)"
info "macOS detected — arch: $ARCH"

# ── Xcode Command Line Tools ────────────────────────────────────────────────
if xcode-select -p &>/dev/null; then
  ok "Xcode Command Line Tools installed"
else
  info "Installing Xcode Command Line Tools (a system dialog will appear)..."
  xcode-select --install || true
  echo ""
  warn "Click 'Install' in the dialog, wait for it to finish, then re-run this script."
  exit 0
fi

# ── Homebrew ────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  ok "Homebrew installed: $(brew --version | head -1)"
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon: brew installs to /opt/homebrew, needs PATH wiring
  if [[ "$ARCH" == "arm64" && -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    if ! grep -q 'brew shellenv' ~/.zprofile 2>/dev/null; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      ok "Added brew to ~/.zprofile (Apple Silicon PATH)"
    fi
  fi
  ok "Homebrew installed"
fi

# ── Core CLI tools via brew ─────────────────────────────────────────────────
brew_install_if_missing() {
  local pkg="$1"
  if brew list "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    info "brew install $pkg"
    brew install "$pkg"
    ok "$pkg installed"
  fi
}

brew_install_if_missing node
brew_install_if_missing jq
brew_install_if_missing fswatch
brew_install_if_missing git
brew_install_if_missing gh

# ── Claude Desktop app ──────────────────────────────────────────────────────
if [[ -d "/Applications/Claude.app" ]]; then
  ok "Claude Desktop app already installed"
else
  info "Attempting Homebrew cask install: claude"
  if brew install --cask claude 2>/dev/null; then
    ok "Claude Desktop installed via cask"
  else
    warn "Homebrew cask 'claude' not available."
    warn "Manual download: https://claude.ai/download"
    open "https://claude.ai/download" 2>/dev/null || true
    echo ""
    read -k 1 "REPLY?Press any key once Claude Desktop is installed and launched (or 's' to skip)... "
    echo ""
  fi
fi

# ── Claude Code CLI (npm global) ────────────────────────────────────────────
if command -v claude &>/dev/null; then
  ok "Claude Code CLI installed: $(claude --version 2>/dev/null | head -1)"
else
  info "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code CLI installed"
fi

# ── ccusage (npm global) ────────────────────────────────────────────────────
if command -v ccusage &>/dev/null; then
  ok "ccusage installed"
else
  info "Installing ccusage..."
  npm install -g ccusage
  ok "ccusage installed"
fi

# ── GitHub auth ─────────────────────────────────────────────────────────────
if gh auth status &>/dev/null; then
  ok "GitHub authenticated as $(gh api user --jq .login 2>/dev/null)"
else
  info "Launching gh auth login (browser will open)..."
  gh auth login -h github.com -p https -w
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Pre-flight Complete                                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Interactive auth still pending — do these once before setup.sh:"
echo ""
echo "  1. Run:   claude"
echo "       └─ first run opens a browser for Anthropic OAuth (one-time)."
echo ""
echo "  2. Open Claude Desktop app and sign in."
echo ""
echo "  3. (Optional) Re-auth your MCP connectors at:"
echo "       https://claude.ai/settings/connectors"
echo "       Common: Gmail, Drive, Calendar, Granola, Gamma, Stripe, Supabase."
echo ""
echo "Then continue with:  bash setup.sh"
echo ""
