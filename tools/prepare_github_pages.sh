#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/github-pages"

mkdir -p "$OUT"
cp "$ROOT/landing/index.html" "$OUT/index.html"
cp "$ROOT/landing/snoot-mark.png" "$OUT/snoot-mark.png"
cp "$ROOT/landing/snoot-walk-0.png" "$OUT/snoot-walk-0.png"
cp "$ROOT/landing/snoot-walk-1.png" "$OUT/snoot-walk-1.png"
cp "$ROOT/landing/snoot-walk-2.png" "$OUT/snoot-walk-2.png"
cp "$ROOT/landing/snoot-walk-3.png" "$OUT/snoot-walk-3.png"
cp "$ROOT/dist/Snoot.zip" "$OUT/Snoot.zip"
touch "$OUT/.nojekyll"

sed -i '' 's#href="../dist/Snoot\.zip"#href="Snoot.zip"#g' "$OUT/index.html"

echo "Prepared $OUT"
