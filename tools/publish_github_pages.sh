#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-snoot}"
VISIBILITY="${2:-public}"

if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" && "$VISIBILITY" != "internal" ]]; then
  echo "Usage: tools/publish_github_pages.sh [repo-name] [public|private|internal]" >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login -h github.com" >&2
  exit 1
fi

"$ROOT/tools/prepare_github_pages.sh"

OWNER="$(gh api user --jq .login)"
cd "$ROOT/github-pages"

if [[ ! -d .git ]]; then
  git init
  git checkout -b main
fi

git add .
if ! git diff --cached --quiet; then
  git commit -m "Publish Snoot landing page"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
    git remote add origin "https://github.com/$OWNER/$REPO.git"
  else
    gh repo create "$OWNER/$REPO" "--$VISIBILITY"
    git remote add origin "https://github.com/$OWNER/$REPO.git"
  fi
fi

git push -u origin main

if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/$OWNER/$REPO/pages" -F "source[branch]=main" -F "source[path]=/"
else
  gh api -X POST "repos/$OWNER/$REPO/pages" -F "source[branch]=main" -F "source[path]=/"
fi

echo "Published: https://$OWNER.github.io/$REPO/"
