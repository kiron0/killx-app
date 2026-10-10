#!/usr/bin/env bash
# Build and package KillX .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="KillX"
VERSION=$(awk -F'"' '/"version"/ { print $4; exit }' "$ROOT_DIR/package.json")
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT_DIR"

echo "▶ Building $APP_NAME (release)..."
swift build -c release --build-system native 2>&1 | sed '/warning:.*build-system native.*deprecated/d'

echo "▶ Packaging $APP_NAME.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [ -f "$ROOT_DIR/.build/release/$APP_NAME" ]; then
    cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
elif [ -f "$ROOT_DIR/.build/arm64-apple-macosx/release/$APP_NAME" ]; then
    cp "$ROOT_DIR/.build/arm64-apple-macosx/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
fi
chmod +x "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT_DIR"/Support/Icons/*.png "$ROOT_DIR"/Support/Icons/*.icns "$RESOURCES_DIR"/ 2>/dev/null || true
cp "$ROOT_DIR"/Support/Sounds/*.aiff "$RESOURCES_DIR"/ 2>/dev/null || true
cp "$ROOT_DIR/Support/Assets.car" "$RESOURCES_DIR"/ 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
echo "✅ $APP_NAME.app ready: $APP_DIR"

if [[ "${1:-}" == "--run" ]]; then
    echo "▶ Launching $APP_NAME..."
    open "$APP_DIR"
fi
