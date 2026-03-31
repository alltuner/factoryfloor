#!/usr/bin/env bash
# ABOUTME: Workstream setup for Factory Floor development.
# ABOUTME: Symlinks ghostty submodule from the main repo and runs a debug build.
set -euo pipefail

REPO_ROOT=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')

# Ghostty submodule (headers + xcframework)
if [ -d "$REPO_ROOT/ghostty" ] && [ ! -e ghostty/include ]; then
    rm -rf ghostty
    ln -sfn "$REPO_ROOT/ghostty" ghostty
    echo "✓ Symlinked ghostty from main repo"
fi

# Pre-commit hooks
if [ -f .pre-commit-config.yaml ] && command -v uv >/dev/null 2>&1; then
    if git -C . config --get core.hooksPath >/dev/null 2>&1; then
        git config --local --unset-all core.hooksPath 2>/dev/null || true
    fi
    uv tool run prek install 2>/dev/null && echo "✓ prek hooks installed" || true
fi

# Generate Xcode project and build
xcodegen generate && echo "✓ Xcode project generated"
./scripts/dev.sh build && echo "✓ Build succeeded"
