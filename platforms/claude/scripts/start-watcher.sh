#!/bin/zsh
# =============================================================================
# start-watcher.sh v2.1 — fswatch entry point for skills-source auto-sync
#
# Watches 6 paths in your skills-source repo and triggers sync.sh on change.
# Debounced 2s — multiple saves batched into single sync.
# =============================================================================

SOURCE_ROOT=~/dev/skills-source       # ← change if your skills-source lives elsewhere
WATCHER_DEBUG=$SOURCE_ROOT/.build/watcher-debug.log

if ! command -v /opt/homebrew/bin/fswatch &>/dev/null; then
  echo "fswatch not installed. Run: brew install fswatch"
  exit 1
fi

# All paths to watch (skip if doesn't exist)
WATCHED=()
for path in skills cowork-instructions chat-instructions claude-md mcp-configs user-preferences.md; do
  if [[ -e "$SOURCE_ROOT/$path" ]]; then
    WATCHED+=("$SOURCE_ROOT/$path")
  fi
done

if [[ ${#WATCHED[@]} -eq 0 ]]; then
  echo "No watch paths found in $SOURCE_ROOT"
  exit 1
fi

printf "\n▶ Watching:\n"
for p in "${WATCHED[@]}"; do
  printf "    $p\n"
done
printf "  Debounce: 2s\n"
printf "  On change: branched sync (skills→build+commit+push, others→commit+push)\n"
printf "  Press Ctrl+C to stop\n\n"

mkdir -p "$SOURCE_ROOT/.build"
echo "WATCHER STARTED: $(/bin/date)" >> "$WATCHER_DEBUG"

/opt/homebrew/bin/fswatch --latency=2 --recursive "${WATCHED[@]}" | while read CHANGED; do
  printf "\n─── change detected: $CHANGED ───\n"
  echo "$(/bin/date): change=$CHANGED → calling sync.sh" >> "$WATCHER_DEBUG"
  /bin/bash "$SOURCE_ROOT/scripts/sync.sh" "$CHANGED"
  echo "$(/bin/date): sync.sh returned $?" >> "$WATCHER_DEBUG"
done
