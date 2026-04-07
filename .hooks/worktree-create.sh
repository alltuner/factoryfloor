#!/usr/bin/env bash
# ABOUTME: Claude Code worktree-create hook for Factory Floor.
# ABOUTME: Initializes ghostty submodule, symlinks build artifacts, and runs a build so SourceKit resolves symbols.
set -euo pipefail

: "${WORKTREE_DIR:?WORKTREE_DIR must be set}"
: "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"

# Ghostty submodule + build artifacts (built with zig, not in git)
if [ -d "$CLAUDE_PROJECT_DIR/ghostty" ]; then
    # Ensure submodule is checked out (may already be done by the global hook)
    if [ ! -e "$WORKTREE_DIR/ghostty/include" ]; then
        git -C "$WORKTREE_DIR" -c protocol.file.allow=always submodule update --init --reference "$CLAUDE_PROJECT_DIR/ghostty" ghostty
    fi
    # Symlink build artifacts (zig-out, xcframework) that aren't in git
    ln -sfn "$CLAUDE_PROJECT_DIR/ghostty/macos/GhosttyKit.xcframework" "$WORKTREE_DIR/ghostty/macos/GhosttyKit.xcframework"
    ln -sfn "$CLAUDE_PROJECT_DIR/ghostty/zig-out" "$WORKTREE_DIR/ghostty/zig-out"
fi

# Build so SourceKit can resolve symbols across files in the worktree.
# dev.sh runs xcodegen + xcodebuild with the shared SPM cache.
# Runs in background to avoid blocking worktree creation.
cd "$WORKTREE_DIR"
nohup ./scripts/dev.sh build >/dev/null 2>&1 &
