#!/usr/bin/env bash
# ABOUTME: Builds, signs, notarizes, and packages Factory Floor as a DMG.
# ABOUTME: Usage: ./scripts/release.sh [version]

set -euo pipefail

SIGNING_IDENTITY="Developer ID Application: ALL TUNER LABS S.L. (J5TAY75Q3F)"
NOTARIZE_PROFILE="factoryfloor"
APP_NAME="Factory Floor"
SCHEME="FactoryFloor"
PROJECT="FactoryFloor.xcodeproj"
VERSION="${1:-$(python3 -c "import json; print(json.load(open('.release-please-manifest.json'))['.'])")}"
DMG_NAME="${SCHEME}.dmg"
BUILD_DIR="build/release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

echo "==> Building ${APP_NAME} v${VERSION}..."
xcodegen generate
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR/derived" \
  DEVELOPMENT_TEAM=J5TAY75Q3F \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  build

# Copy the app out of DerivedData
APP_BUILT=$(find "$BUILD_DIR/derived" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_BUILT" ]; then
  echo "Error: Built app not found"
  exit 1
fi
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"
cp -R "$APP_BUILT" "$APP_PATH"

echo "==> Uploading debug symbols to Sentry..."
if command -v sentry-cli &>/dev/null; then
  sentry-cli --url https://de.sentry.io debug-files upload \
    --org all-tuner-labs \
    --project factory-floor \
    "$BUILD_DIR/derived/Build/Products/Release/"
else
  echo "Warning: sentry-cli not found, skipping dSYM upload"
  echo "Install with: brew install getsentry/tools/sentry-cli"
fi

echo "==> Verifying signature..."
codesign --verify --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH" 2>&1

echo "==> Creating DMG..."
rm -f "$BUILD_DIR/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"

# create-dmg exits non-zero when skipping deprecated internet-enable
create-dmg \
  --volname "$APP_NAME" \
  --background "Resources/dmg-background@2x.png" \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 170 180 \
  --app-drop-link 490 180 \
  --no-internet-enable \
  "$BUILD_DIR/$DMG_NAME" \
  "$DMG_STAGING" || true

if [ ! -f "$BUILD_DIR/$DMG_NAME" ]; then
  echo "Error: DMG was not created"
  exit 1
fi

codesign --sign "$SIGNING_IDENTITY" "$BUILD_DIR/$DMG_NAME"

echo "==> Notarizing..."
xcrun notarytool submit "$BUILD_DIR/$DMG_NAME" \
  --keychain-profile "$NOTARIZE_PROFILE" \
  --wait

echo "==> Stapling..."
xcrun stapler staple "$BUILD_DIR/$DMG_NAME"

echo ""
echo "Done! DMG ready at: $BUILD_DIR/$DMG_NAME"
echo "Upload to GitHub release: gh release upload v${VERSION} $BUILD_DIR/$DMG_NAME"
