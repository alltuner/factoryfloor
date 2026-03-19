#!/usr/bin/env bash
# Symlink build artifacts that aren't tracked in git but are needed for compilation.
set -euo pipefail

: "${WORKTREE_DIR:?WORKTREE_DIR must be set}"
: "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"

# Ghostty xcframework (built with zig, not in git)
XCFW_SRC="$CLAUDE_PROJECT_DIR/ghostty/macos/GhosttyKit.xcframework"
XCFW_DST="$WORKTREE_DIR/ghostty/macos/GhosttyKit.xcframework"

if [ -d "$XCFW_SRC" ] && [ ! -e "$XCFW_DST" ]; then
    ln -sfn "$XCFW_SRC" "$XCFW_DST"
fi
