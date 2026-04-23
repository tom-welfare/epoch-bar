#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ICONSET="Icon.iconset"
ICNS="Icon.icns"
MASTER="$ICONSET/icon_master_1024.png"

# 1. Render the 1024x1024 master PNG.
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
swift tools/render-icon.swift "$MASTER"

# 2. Generate the 10-image iconset via sips.
for SPEC in "16:icon_16x16.png"       "32:icon_16x16@2x.png" \
            "32:icon_32x32.png"       "64:icon_32x32@2x.png" \
            "128:icon_128x128.png"    "256:icon_128x128@2x.png" \
            "256:icon_256x256.png"    "512:icon_256x256@2x.png" \
            "512:icon_512x512.png"    "1024:icon_512x512@2x.png"; do
    SIZE="${SPEC%%:*}"
    NAME="${SPEC##*:}"
    sips -z "$SIZE" "$SIZE" "$MASTER" --out "$ICONSET/$NAME" >/dev/null
done

# 3. Remove the master so iconutil doesn't complain about unknown files.
rm "$MASTER"

# 4. Build the .icns.
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Wrote $ICNS"
