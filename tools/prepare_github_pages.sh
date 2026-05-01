#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist/github-pages"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$ROOT/landing/index.html" "$OUT/index.html"
cp "$ROOT/landing/snoot-mark.png" "$OUT/snoot-mark.png"
cp "$ROOT/landing/snootwalk0.png" "$OUT/snootwalk0.png"
cp "$ROOT/landing/snootwalk1.png" "$OUT/snootwalk1.png"
cp "$ROOT/landing/snootwalk2.png" "$OUT/snootwalk2.png"
cp "$ROOT/landing/snootwalk3.png" "$OUT/snootwalk3.png"
cp "$ROOT/dist/Snoot.zip" "$OUT/Snoot.zip"
touch "$OUT/.nojekyll"

sed -i '' 's#href="\.\./dist/Snoot\.zip"#href="Snoot.zip"#g' "$OUT/index.html"

echo "Prepared $OUT"
