#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Make sure the .app is built and ad-hoc signed.
./build.sh

APP_BUNDLE=".build/EpochBar.app"
DMG_PATH=".build/EpochBar.dmg"
STAGING=".build/dmg-staging"

# 2. Build a clean staging folder with the .app and an Applications symlink.
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/EpochBar.app"
ln -s /Applications "$STAGING/Applications"

# 3. Create a compressed DMG.
hdiutil create \
    -volname EpochBar \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

echo ""
echo "Built: $DMG_PATH"
