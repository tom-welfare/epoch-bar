#!/usr/bin/env bash
#
# Download the Google Fonts used by the landing page into site/fonts/ and
# generate a local fonts.css that replaces the external stylesheet. Run this
# only when the font list changes; the downloaded files are committed so the
# site has no external font dependency at runtime.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$ROOT/site/fonts"
CSS_OUT="$ROOT/site/fonts.css"

# Request Google's modern CSS (unicode-range split + woff2) by using a recent Chrome UA.
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
FONTS_URL="https://fonts.googleapis.com/css2?family=Bodoni+Moda:ital,opsz,wght@0,6..96,400;0,6..96,600;1,6..96,400&family=JetBrains+Mono:wght@400;500&family=Sora:wght@300;400;500;600&display=swap"

mkdir -p "$OUT_DIR"
echo "Fetching CSS from Google..."
curl -fsSL -A "$UA" "$FONTS_URL" > "$OUT_DIR/.remote.css"

echo "Localising referenced font files..."
python3 "$SCRIPT_DIR/localise-fonts.py" "$OUT_DIR/.remote.css" "$OUT_DIR" "$CSS_OUT"
rm "$OUT_DIR/.remote.css"

echo "Done."
