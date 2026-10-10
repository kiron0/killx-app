#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="KillX"
BUNDLE_DIR="$ROOT_DIR/.build/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
ALT_DEST_APP="$HOME/Applications/$APP_NAME.app"

cd "$ROOT_DIR"

echo "🧪 [1/5] Testing..."
swift test --build-system native 2>&1 | LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'

echo "📦 [2/5] Bundling..."
"$SCRIPT_DIR/build.sh"

echo "🛑 [3/5] Killing running instances..."
pkill -x "$APP_NAME" 2>/dev/null || true
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
open -g "$TARGET_DEST"

echo "✨ KillX successfully tested, bundled, installed, and launched!"
