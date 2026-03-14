#!/usr/bin/env bash
# ABOUTME: Dev script for building and running ff2.
# ABOUTME: Usage: ./dev.sh [command] [args]

set -e

# Resolve a path to absolute
resolve_dir() {
  if [ -n "$1" ]; then
    cd "$1" 2>/dev/null && pwd
  fi
}

case "${1:-run}" in
  build)
    xcodegen generate
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Debug build
    ;;
  build-release)
    xcodegen generate
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Release build
    ;;
  test)
    xcodegen generate
    xcodebuild -project ff2.xcodeproj -scheme ff2Tests -configuration Debug test
    ;;
  run)
    shift 2>/dev/null || true
    DIR=$(resolve_dir "${1:-.}")
    open "ff2://$DIR"
    ;;
  br)
    shift 2>/dev/null || true
    DIR=$(resolve_dir "${1:-.}")
    xcodegen generate
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Debug build
    pkill -f "ff2.app/Contents/MacOS/ff2" 2>/dev/null || true
    sleep 0.5
    open "ff2://$DIR"
    ;;
  br-release)
    shift 2>/dev/null || true
    DIR=$(resolve_dir "${1:-.}")
    xcodegen generate
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Release build
    pkill -f "ff2.app/Contents/MacOS/ff2" 2>/dev/null || true
    sleep 0.5
    APP=$(find ~/Library/Developer/Xcode/DerivedData -path '*/ff2-*/Build/Products/Release/ff2.app' -type d 2>/dev/null | head -1)
    open -a "$APP" --args "$DIR"
    ;;
  clean)
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Debug clean 2>/dev/null || true
    xcodebuild -project ff2.xcodeproj -scheme ff2 -configuration Release clean 2>/dev/null || true
    rm -rf ~/Library/Developer/Xcode/DerivedData/ff2-*
    ;;
  *)
    echo "Usage: ./dev.sh [command] [directory]"
    echo ""
    echo "  build          Build (debug)"
    echo "  build-release  Build (release, optimized)"
    echo "  test           Run tests"
    echo "  run            Run the app, optionally with a directory"
    echo "  br             Build (debug) and run"
    echo "  br-release     Build (release) and run"
    echo "  clean          Clean build artifacts"
    ;;
esac
