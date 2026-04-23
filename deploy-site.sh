#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Build the .app bundle and the .dmg.
./build.sh
./make-dmg.sh

# 2. Drop the DMG next to the HTML so the download link resolves.
cp .build/EpochBar.dmg site/EpochBar.dmg

# 3. Ship to Cloudflare Pages. Prefer a local wrangler install; fall back to npx.
if command -v wrangler >/dev/null 2>&1; then
    WRANGLER=(wrangler)
else
    WRANGLER=(npx --yes wrangler)
fi

"${WRANGLER[@]}" pages deploy site --project-name epoch-bar

echo ""
echo "Site deployed."
