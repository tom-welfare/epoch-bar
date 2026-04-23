#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Build release binary via SPM
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
APP_NAME="EpochBar"
APP_BUNDLE=".build/EpochBar.app"

# 2. Clean and assemble .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy binary, Info.plist, and app icon
cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Icon.icns "$APP_BUNDLE/Contents/Resources/Icon.icns"

# 4. Ad-hoc codesign (required for SMAppService to work)
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
