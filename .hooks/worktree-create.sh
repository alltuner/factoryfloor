#!/usr/bin/env bash
# ABOUTME: Claude Code worktree-create hook for Factory Floor.
# ABOUTME: Symlinks build artifacts and runs a build so SourceKit resolves symbols.
set -euo pipefail

: "${WORKTREE_DIR:?WORKTREE_DIR must be set}"
: "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"

# Ghostty submodule (headers + xcframework, built with zig, not in git)
GHOSTTY_SRC="$CLAUDE_PROJECT_DIR/ghostty"
GHOSTTY_DST="$WORKTREE_DIR/ghostty"

if [ -d "$GHOSTTY_SRC" ] && [ ! -e "$GHOSTTY_DST/include" ]; then
    rm -rf "$GHOSTTY_DST"
    ln -sfn "$GHOSTTY_SRC" "$GHOSTTY_DST"
fi

# Build so SourceKit can resolve symbols across files in the worktree.
# dev.sh runs xcodegen + xcodebuild with the shared SPM cache.
# Runs in background to avoid blocking worktree creation.
cd "$WORKTREE_DIR"
nohup ./scripts/dev.sh build >/dev/null 2>&1 &
