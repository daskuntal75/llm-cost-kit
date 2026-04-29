#!/bin/zsh
# =============================================================================
# init-git.sh — First-time setup for skills-source repo
# Creates the structure, initializes git, sets up .gitignore.
# Idempotent — safe to re-run.
# =============================================================================

SOURCE_ROOT=~/dev/skills-source       # ← change if your skills-source lives elsewhere

mkdir -p "$SOURCE_ROOT"/{skills,cowork-instructions,chat-instructions,claude-md,mcp-configs,scripts,.build}

cd "$SOURCE_ROOT"

if [[ ! -d .git ]]; then
  git init
  git branch -m main
  echo "✓ Initialized git repo"
fi

# .gitignore
cat > .gitignore << 'GIEOF'
.DS_Store
.build/sync-debug.log
.build/watcher-debug.log
.build/watcher.log
.build/watcher.err
*.swp
*~
GIEOF
echo "✓ .gitignore created"

# README placeholder
if [[ ! -f README.md ]]; then
  cat > README.md << 'RMEOF'
# skills-source

Single source of truth for Claude skills, Cowork/Chat instructions, Claude Code CLAUDE.md templates, MCP configs, and user preferences.

Auto-syncs to GitHub via fswatch + LaunchAgent. See scripts/start-watcher.sh.
RMEOF
  echo "✓ README.md placeholder created"
fi

echo ""
echo "Next:"
echo "1. Add your private GitHub remote: git remote add origin git@github.com:USER/skills-source.git"
echo "2. Populate skills/, cowork-instructions/, chat-instructions/, claude-md/, mcp-configs/"
echo "3. Run: bash scripts/build-skills.sh"
echo "4. Install watcher LaunchAgent: bash scripts/watcher-launchagent.sh"
