#!/bin/zsh
# =============================================================================
# sync.sh v2.0 — Branched sync called by fswatch when source files change
#
# Branches on changed-path:
#   - skills/* → rebuild .skill zips → git add → commit → push
#   - cowork-instructions/* → git add → commit → push
#   - chat-instructions/* → git add → commit → push
#   - claude-md/* → git add → commit → push
#   - mcp-configs/* → git add → commit → push
#   - user-preferences.md → git add → commit → push
# =============================================================================

# CRITICAL: LaunchAgents run with bare PATH. Either use absolute paths to all
# system binaries OR export PATH at top. We do both for safety.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH

SOURCE_ROOT=~/dev/skills-source       # ← change if your skills-source lives elsewhere
DEBUG_LOG="$SOURCE_ROOT/.build/sync-debug.log"

mkdir -p "$SOURCE_ROOT/.build"
exec >> "$DEBUG_LOG" 2>&1

echo ""
echo "════════════════════════════════════════════════════════════"
echo "SYNC START: $(/bin/date '+%Y-%m-%d %H:%M:%S')"
echo "Changed: $1"
echo "────────────────────────────────────────────────────────────"

cd "$SOURCE_ROOT" || { echo "FAIL: cannot cd to $SOURCE_ROOT"; exit 1; }

CHANGED_PATH="$1"
IS_SKILL=false
if [[ "$CHANGED_PATH" == *"/skills/"* ]]; then
  IS_SKILL=true
fi

# Step 1: Build (only if a skill changed)
if [[ "$IS_SKILL" == "true" ]]; then
  echo "[1/3] Building skills..."
  /bin/bash "$SOURCE_ROOT/scripts/build-skills.sh" > /dev/null 2>&1
  echo "    build exit code: $?"
else
  echo "[1/3] Build skipped (non-skill change)"
fi

# Step 2: Git commit
echo "[2/3] Git commit..."
if [[ -d "$SOURCE_ROOT/.git" ]]; then
  TIMESTAMP=$(/bin/date '+%Y-%m-%d %H:%M:%S')
  /usr/bin/git -C "$SOURCE_ROOT" add -A
  if /usr/bin/git -C "$SOURCE_ROOT" diff --cached --quiet; then
    echo "    nothing to commit"
    echo "[3/3] Push skipped (no commit)"
    echo "SYNC COMPLETE: $(/bin/date '+%Y-%m-%d %H:%M:%S')"
    exit 0
  else
    if [[ "$IS_SKILL" == "true" ]]; then
      MSG="sync: skills update at $TIMESTAMP"
    else
      MSG="sync: instructions/config update at $TIMESTAMP"
    fi
    /usr/bin/git -C "$SOURCE_ROOT" commit -m "$MSG" --quiet
    echo "    git commit exit code: $?"
  fi
else
  echo "    no .git directory — skipping commit + push"
  echo "SYNC COMPLETE: $(/bin/date '+%Y-%m-%d %H:%M:%S')"
  exit 0
fi

# Step 3: Git push
echo "[3/3] Git push..."
/usr/bin/git -C "$SOURCE_ROOT" push --quiet 2>&1
PUSH_RC=$?
echo "    git push exit code: $PUSH_RC"

if [[ $PUSH_RC -ne 0 ]]; then
  echo "    ⚠ push failed — commit is local only. Run 'git push' manually."
fi

echo "SYNC COMPLETE: $(/bin/date '+%Y-%m-%d %H:%M:%S')"
