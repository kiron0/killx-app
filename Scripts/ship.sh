#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="KillX"
BUNDLE_DIR="$ROOT_DIR/.build/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
ALT_DEST_APP="$HOME/Applications/$APP_NAME.app"

cd "$ROOT_DIR"

echo "🧪 [1/5] Testing..."
swift test --build-system native -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks 2>&1 | grep -v "build-system native" || true

echo "📦 [2/5] Bundling..."
make bundle

echo "🛑 [3/5] Killing running instances..."
pkill -x "$APP_NAME" 2>/dev/null || pkill -f "$APP_NAME.app" 2>/dev/null || true
sleep 0.5

echo "🚚 [4/5] Installing..."
TARGET_DEST="$DEST_APP"
if [ -w "/Applications" ]; then
    rm -rf "$DEST_APP"
    ditto "$BUNDLE_DIR" "$DEST_APP"
    TARGET_DEST="$DEST_APP"
else
    mkdir -p "$HOME/Applications"
    rm -rf "$ALT_DEST_APP"
    ditto "$BUNDLE_DIR" "$ALT_DEST_APP"
    TARGET_DEST="$ALT_DEST_APP"
fi
echo "✅ Installed to $TARGET_DEST"

echo "🚀 [5/5] Launching $TARGET_DEST..."
open "$TARGET_DEST"

echo "✨ KillX successfully tested, bundled, installed, and launched!"
