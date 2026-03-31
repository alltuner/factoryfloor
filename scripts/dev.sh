#!/usr/bin/env bash
# ABOUTME: Development convenience script for Factory Floor.
# ABOUTME: Usage: ./scripts/dev.sh [build|run|test|clean]

set -e

PROJECT="FactoryFloor.xcodeproj"
SCHEME="FactoryFloor"
TEST_SCHEME="FactoryFloorTests"
APP_NAME="Factory Floor Debug"
BUILD_DIR="build/debug/derived"
APP_PATH="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
SPM_CACHE="$HOME/Library/Caches/factoryfloor/spm"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

case "${1:-build}" in
  build)
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      CURRENT_PROJECT_VERSION="$BRANCH" build
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
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      CURRENT_PROJECT_VERSION="$BRANCH" build
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
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$TEST_SCHEME" -configuration Debug \
      -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" test
    ;;
  release)
    RELEASE_DIR="build/release-local/derived"
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
      -derivedDataPath "$RELEASE_DIR" -clonedSourcePackagesDirPath "$SPM_CACHE" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGN_STYLE=Manual \
      ENABLE_HARDENED_RUNTIME=YES \
      CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
      CODE_SIGN_ENTITLEMENTS=Resources/ff2-local.entitlements \
      OTHER_CODE_SIGN_FLAGS="--options=runtime" \
      build
    APP_BUNDLE="$RELEASE_DIR/Build/Products/Release/Factory Floor.app"
    echo "==> Release build at: $APP_BUNDLE"
    if [ "${2:-}" = "--run" ]; then
      pkill -xf ".*/Contents/MacOS/Factory Floor" 2>/dev/null || true
      sleep 0.5
      open "$RELEASE_DIR/Build/Products/Release/Factory Floor.app"
    fi
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
    echo "  clean    Clean build artifacts"
    ;;
esac
