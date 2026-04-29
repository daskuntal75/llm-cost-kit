#!/bin/zsh
# =============================================================================
# build-skills.sh — Rebuild all .skill zips from skills/ source folders
# Writes to .build/ — clobbers any existing zips there.
# =============================================================================

set -e
SOURCE_ROOT=~/dev/skills-source       # ← change if your skills-source lives elsewhere
BUILD=$SOURCE_ROOT/.build

GREEN='\033[0;32m'; NC='\033[0m'; BLUE='\033[0;34m'
ok() { printf "${GREEN}  ✓${NC}  %s\n" "$1"; }
info() { printf "${BLUE}  →${NC}  %s\n" "$1"; }

mkdir -p "$BUILD"
rm -f "$BUILD"/*.skill

printf "\nBuilding .skill zips from $SOURCE_ROOT/skills/\n\n"

for SKILL_DIR in "$SOURCE_ROOT"/skills/*/; do
  [[ -d "$SKILL_DIR" ]] || continue
  SKILL_NAME=$(basename "$SKILL_DIR")
  OUTPUT="$BUILD/$SKILL_NAME.skill"

  info "Packing $SKILL_NAME..."
  (cd "$SKILL_DIR" && zip -rq "$OUTPUT" . -x "*.DS_Store" -x ".git/*")
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  ok "$SKILL_NAME.skill ($SIZE)"
done

printf "\n"
ok "Build complete: $(ls -1 "$BUILD"/*.skill | wc -l | tr -d ' ') skills built"
printf "Output: $BUILD/\n"
