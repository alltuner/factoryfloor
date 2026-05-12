#!/usr/bin/env bash
# ABOUTME: Development convenience script for Dockyard.
# ABOUTME: Usage: ./scripts/dev.sh [build|run|test|clean|release|install]

set -e

PROJECT="Dockyard.xcodeproj"
SCHEME="Dockyard"
TEST_SCHEME="DockyardTests"
APP_NAME="Dockyard Debug"
BUILD_DIR="build/debug/derived"
APP_PATH="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
SPM_CACHE="$HOME/Library/Caches/dockyard/spm"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GHOSTTY_RESOURCES="ghostty/zig-out/share"
MONACO_OUTPUT="Resources/MonacoEditor/index.html"

ensure_ghostty_resources() {
  if [ ! -d "$GHOSTTY_RESOURCES/terminfo" ] || [ ! -d "$GHOSTTY_RESOURCES/ghostty" ]; then
    echo "error: Ghostty resources not found at $GHOSTTY_RESOURCES/"
    echo "       Build the xcframework first: cd ghostty && zig build"
    exit 1
  fi
}

ensure_monaco_editor() {
  if [ ! -f "$MONACO_OUTPUT" ]; then
    echo "info: Monaco editor not built, running scripts/build-editor.sh..."
    bash scripts/build-editor.sh
  fi
}

case "${1:-build}" in
  build)
    ensure_ghostty_resources
    ensure_monaco_editor
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      -skipPackagePluginValidation \
      CURRENT_PROJECT_VERSION="$(git rev-parse --short HEAD)" build
    ;;
  run)
    shift 2>/dev/null || true
    pkill -xf ".*/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 0.5
    if [ -n "${1:-}" ]; then
      DIR=$(cd "$1" && pwd)
      open "$APP_PATH" --args "$DIR"
    else
      open "$APP_PATH"
    fi
    ;;
  br)
    shift 2>/dev/null || true
    ensure_ghostty_resources
    ensure_monaco_editor
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      -skipPackagePluginValidation \
      CURRENT_PROJECT_VERSION="$(git rev-parse --short HEAD)" build
    pkill -xf ".*/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 0.5
    if [ -n "${1:-}" ]; then
      DIR=$(cd "$1" && pwd)
      open "$APP_PATH" --args "$DIR"
    else
      open "$APP_PATH"
    fi
    ;;
  test)
    ensure_ghostty_resources
    ensure_monaco_editor
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$TEST_SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      -skipPackagePluginValidation test
    ;;
  release)
    RELEASE_DIR="build/release-local/derived"
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")
    ensure_ghostty_resources
    ensure_monaco_editor
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
      -derivedDataPath "$RELEASE_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      -skipPackagePluginValidation \
      CURRENT_PROJECT_VERSION="$COMMIT_HASH" \
      MARKETING_VERSION="$COMMIT_HASH" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGN_STYLE=Manual \
      ENABLE_HARDENED_RUNTIME=YES \
      CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
      CODE_SIGN_ENTITLEMENTS=Resources/ff2-local.entitlements \
      OTHER_CODE_SIGN_FLAGS="--options=runtime" \
      build
    APP_BUNDLE="$RELEASE_DIR/Build/Products/Release/Dockyard.app"
    echo "==> Release build at: $APP_BUNDLE"
    if [ "${2:-}" = "--run" ]; then
      pkill -xf ".*/Contents/MacOS/Dockyard" 2>/dev/null || true
      sleep 0.5
      open "$RELEASE_DIR/Build/Products/Release/Dockyard.app"
    fi
    ;;
  install)
    # 1. Build a local release version
    "$0" release
    
    APP_BUNDLE="build/release-local/derived/Build/Products/Release/Dockyard.app"
    TARGET_DIR="/Applications/Dockyard.app"
    
    echo "==> Installing local build to $TARGET_DIR..."
    
    # 2. Kill the app if it's currently running
    pkill -xf ".*/Contents/MacOS/Dockyard" 2>/dev/null || true
    sleep 0.5
    
    # 3. Remove the old app and copy the new one over
    rm -rf "$TARGET_DIR"
    cp -R "$APP_BUNDLE" "/Applications/"
    
    # 4. Force Spotlight reindexing so Cmd+Space finds it instantly
    touch "$TARGET_DIR"
    mdimport "$TARGET_DIR" || true
    
    echo "==> Installed successfully!"
    echo "==> Launching Dockyard..."
    open "$TARGET_DIR"
    ;;
  clean)
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug clean 2>/dev/null || true
    rm -rf build/debug build/release-local "$SPM_CACHE"
    ;;
  *)
    echo "Usage: ./scripts/dev.sh [command] [directory]"
    echo ""
    echo "  build    Build (debug)"
    echo "  run      Kill and relaunch (optionally with a directory)"
    echo "  br       Build and run"
    echo "  test     Run tests"
    echo "  release  Build Release matching CI (hardened runtime)"
    echo "  release --run  Build and run Release"
    echo "  install  Build local release, install to /Applications, and run"
    echo "  clean    Clean build artifacts"
    ;;
esac
