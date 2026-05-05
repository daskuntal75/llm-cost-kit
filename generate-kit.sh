#!/bin/zsh
# =============================================================================
# LLM Cost Kit v3.6 — Kit Generator
# Usage: bash generate-kit.sh [claude|openai|gemini|all]
#         (no arg builds all four)
#
# Builds release zips into dist/ from the current repo state. The Claude and
# all-in-one kits include bootstrap-macos.sh + verify.sh; OpenAI and Gemini
# kits omit them (their setup.sh paths exit early without using them).
#
# Each kit ships the repo's actual setup.sh (not a generated stub), so the
# kit user runs the same code that gets exercised in CI / by maintainers.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
PLATFORM="${1:-all}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "${GREEN}  ✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$1"; }
info() { printf "${BLUE}  →${NC} %s\n" "$1"; }

usage() {
  printf "\n${BOLD}Usage:${NC} bash generate-kit.sh [platform]\n\n"
  printf "  claude   → claude-cost-kit.zip   (incl. bootstrap-macos.sh, verify.sh)\n"
  printf "  openai   → openai-cost-kit.zip\n"
  printf "  gemini   → gemini-cost-kit.zip\n"
  printf "  all      → all four zips, including llm-cost-kit.zip (default)\n\n"
  exit 1
}

case "$PLATFORM" in
  claude|openai|gemini|all) ;;
  -h|--help|help) usage ;;
  *) warn "Unknown platform: $PLATFORM"; usage ;;
esac

# ── Pre-flight ──────────────────────────────────────────────────────────────
command -v zip &>/dev/null || { warn "zip not found — install via brew install zip"; exit 1; }

# ── Stage to a tempdir, zip into dist/, clean up ────────────────────────────
mkdir -p "$DIST_DIR"
BUILD_DIR="$(mktemp -d -t llm-cost-kit-build)"
trap 'rm -rf "$BUILD_DIR"' EXIT

COMMON_FILES=(LICENSE README.md guide.html setup.sh)
CLAUDE_EXTRAS=(bootstrap-macos.sh verify.sh)

# Stage one platform kit at $BUILD_DIR/<name>/, then zip to $DIST_DIR/<name>.zip
build_kit() {
  local name="$1"
  local platform_dir="$2"     # platforms/<x> to copy, or empty for "all"
  local include_extras="$3"   # "yes" to ship bootstrap-macos.sh + verify.sh

  local stage="$BUILD_DIR/$name"
  mkdir -p "$stage/core" "$stage/platforms"

  cp -R "$SCRIPT_DIR/core/." "$stage/core/"

  if [[ -n "$platform_dir" ]]; then
    cp -R "$SCRIPT_DIR/$platform_dir" "$stage/platforms/"
  else
    cp -R "$SCRIPT_DIR/platforms/." "$stage/platforms/"
  fi

  for f in "${COMMON_FILES[@]}"; do
    [[ -f "$SCRIPT_DIR/$f" ]] && cp "$SCRIPT_DIR/$f" "$stage/"
  done

  if [[ "$include_extras" == "yes" ]]; then
    for f in "${CLAUDE_EXTRAS[@]}"; do
      [[ -f "$SCRIPT_DIR/$f" ]] && cp "$SCRIPT_DIR/$f" "$stage/"
    done
  fi

  # all-in-one kit also ships diagrams/ and docs/
  if [[ "$name" == "llm-cost-kit" ]]; then
    [[ -d "$SCRIPT_DIR/diagrams" ]] && cp -R "$SCRIPT_DIR/diagrams" "$stage/"
    [[ -d "$SCRIPT_DIR/docs" ]]     && cp -R "$SCRIPT_DIR/docs" "$stage/"
  fi

  (cd "$stage" && zip -r -q "$DIST_DIR/${name}.zip" .)
  local size; size=$(du -h "$DIST_DIR/${name}.zip" | awk '{print $1}')
  ok "$(printf '%-22s  %s' "${name}.zip" "$size")"
}

printf "\n${BOLD}LLM Cost Kit v3.6 — building kits${NC}\n"
info "dist:  $DIST_DIR"
info "stage: $BUILD_DIR"
echo ""

case "$PLATFORM" in
  claude)
    build_kit claude-cost-kit platforms/claude yes
    ;;
  openai)
    build_kit openai-cost-kit platforms/openai no
    ;;
  gemini)
    build_kit gemini-cost-kit platforms/gemini no
    ;;
  all)
    build_kit claude-cost-kit platforms/claude yes
    build_kit openai-cost-kit platforms/openai no
    build_kit gemini-cost-kit platforms/gemini no
    build_kit llm-cost-kit    ""               yes
    ;;
esac

echo ""
ok "Done. Zips in $DIST_DIR"
echo ""
echo "Publish to a GitHub release:"
echo "  gh release create vX.Y --title \"vX.Y — ...\" --notes-file RELEASE_NOTES.md \\"
echo "    $DIST_DIR/*.zip"
echo ""
