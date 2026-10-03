#!/usr/bin/env bash
# Build and run KillX (SPM-based, no Xcode needed)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

echo "▶ Building KillX..."
cd "$ROOT"
swift build -c release --build-system native 2>&1

BINARY=".build/release/KillX"

echo "▶ Running KillX..."
exec "$BINARY"
