#!/usr/bin/env bash
# ABOUTME: Builds the Monaco editor Vite project into Resources/MonacoEditor/.
# ABOUTME: Smart rebuild — skips if output is newer than all source files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EDITOR_DIR="$PROJECT_DIR/editor"
OUTPUT_DIR="$PROJECT_DIR/Resources/MonacoEditor"
OUTPUT_MARKER="$OUTPUT_DIR/index.html"

# Source files that trigger a rebuild
SOURCE_FILES=(
  "$EDITOR_DIR/package.json"
  "$EDITOR_DIR/bun.lock"
  "$EDITOR_DIR/vite.config.js"
  "$EDITOR_DIR/index.html"
)

needs_rebuild() {
  # Rebuild if output doesn't exist
  [ ! -f "$OUTPUT_MARKER" ] && return 0

  # Rebuild if any source file is newer than output
  for src in "${SOURCE_FILES[@]}"; do
    [ "$src" -nt "$OUTPUT_MARKER" ] && return 0
  done

  # Rebuild if any file in editor/src/ is newer than output
  while IFS= read -r -d '' f; do
    [ "$f" -nt "$OUTPUT_MARKER" ] && return 0
  done < <(find "$EDITOR_DIR/src" -type f -print0 2>/dev/null)

  return 1
}

if needs_rebuild; then
  echo "Building Monaco editor bundle..."
  cd "$EDITOR_DIR"
  bun install --frozen-lockfile 2>&1
  NODE_OPTIONS="--max-old-space-size=4096" bunx vite build 2>&1
  echo "Monaco editor built to Resources/MonacoEditor/"
else
  echo "Monaco editor bundle is up to date, skipping build."
fi
