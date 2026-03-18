#!/usr/bin/env bash
# ABOUTME: Development convenience script for Factory Floor.
# ABOUTME: Usage: ./scripts/dev.sh [build|run|test|clean]

set -e

PROJECT="FactoryFloor.xcodeproj"
SCHEME="FactoryFloor"
TEST_SCHEME="FactoryFloorTests"
APP_NAME="Factory Floor Debug"
URL_SCHEME="factoryfloor-debug"

case "${1:-build}" in
  build)
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug build
    ;;
  run)
    shift 2>/dev/null || true
    DIR=$(cd "${1:-.}" 2>/dev/null && pwd)
    pkill -f "$APP_NAME.app/Contents/MacOS" 2>/dev/null || true
    sleep 0.5
    open "$URL_SCHEME://$DIR"
    ;;
  br)
    shift 2>/dev/null || true
    DIR=$(cd "${1:-.}" 2>/dev/null && pwd)
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug build
    pkill -f "$APP_NAME.app/Contents/MacOS" 2>/dev/null || true
    sleep 0.5
    open "$URL_SCHEME://$DIR"
    ;;
  test)
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$TEST_SCHEME" -configuration Debug test
    ;;
  release)
    # Build a Release binary matching CI conditions (hardened runtime, no debug entitlements)
    BUILD_DIR="build/release-local/derived"
    xcodegen generate
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
      -derivedDataPath "$BUILD_DIR" \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGN_STYLE=Manual \
      ENABLE_HARDENED_RUNTIME=YES \
      CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
      OTHER_CODE_SIGN_FLAGS="--options=runtime" \
      build
    echo "==> Release build at: $BUILD_DIR/Build/Products/Release/Factory Floor.app"
    if [ "${2:-}" = "--run" ]; then
      pkill -f "Factory Floor.app/Contents/MacOS/Factory Floor" 2>/dev/null || true
      sleep 0.5
      open "$BUILD_DIR/Build/Products/Release/Factory Floor.app"
    fi
    ;;
  clean)
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug clean 2>/dev/null || true
    rm -rf ~/Library/Developer/Xcode/DerivedData/FactoryFloor-*
    rm -rf build/release-local
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
