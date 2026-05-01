#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/tools/package_snoot.sh"
"$ROOT/tools/prepare_github_pages.sh"

echo "Prepared GitHub Pages bundle in $ROOT/dist/github-pages"
echo "Push main to publish it through GitHub Actions."
