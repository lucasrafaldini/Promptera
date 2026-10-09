#!/bin/bash
# Renders the README/release screenshots (demo data only) into docs/screenshots.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"
swift build -c release --product PrompteraApp
OUT="$(mktemp -d)"
PROMPTERA_SCREENSHOTS="$OUT" .build/release/PrompteraApp
mkdir -p docs/screenshots
for f in "$OUT"/*.png; do
    case "$f" in *-raw.png) ;; *) cp "$f" docs/screenshots/ ;; esac
done
rm -rf "$OUT"
echo "✅ Screenshots em docs/screenshots"
