#!/usr/bin/env bash
# ABOUTME: Claude Code worktree-create hook for Factory Floor.
# ABOUTME: Symlinks build artifacts and runs a build so SourceKit resolves symbols.
set -euo pipefail

: "${WORKTREE_DIR:?WORKTREE_DIR must be set}"
: "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"

# Ghostty xcframework (built with zig, not in git)
XCFW_SRC="$CLAUDE_PROJECT_DIR/ghostty/macos/GhosttyKit.xcframework"
XCFW_DST="$WORKTREE_DIR/ghostty/macos/GhosttyKit.xcframework"

if [ -d "$XCFW_SRC" ] && [ ! -e "$XCFW_DST" ]; then
    ln -sfn "$XCFW_SRC" "$XCFW_DST"
fi

# Build so SourceKit can resolve symbols across files in the worktree.
# dev.sh runs xcodegen + xcodebuild with the shared SPM cache.
# Runs in background to avoid blocking worktree creation.
cd "$WORKTREE_DIR"
nohup ./scripts/dev.sh build >/dev/null 2>&1 &
