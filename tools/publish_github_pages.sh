#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-snoot}"
VISIBILITY="${2:-public}"
PAGES_BRANCH="gh-pages"

if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" && "$VISIBILITY" != "internal" ]]; then
  echo "Usage: tools/publish_github_pages.sh [repo-name] [public|private|internal]" >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login -h github.com" >&2
  exit 1
fi

"$ROOT/tools/package_snoot.sh"

OWNER="$(gh api user --jq .login)"
cd "$ROOT/github-pages"

if [[ ! -d .git ]]; then
  git init
fi

CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

if git show-ref --verify --quiet "refs/heads/$PAGES_BRANCH"; then
  if [[ "$CURRENT_BRANCH" != "$PAGES_BRANCH" ]]; then
    git checkout "$PAGES_BRANCH"
  fi
elif git ls-remote --exit-code --heads origin "$PAGES_BRANCH" >/dev/null 2>&1; then
  git fetch origin "$PAGES_BRANCH"
  git checkout -B "$PAGES_BRANCH" "origin/$PAGES_BRANCH"
else
  git checkout -B "$PAGES_BRANCH"
fi

"$ROOT/tools/prepare_github_pages.sh"

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

git push -u origin "$PAGES_BRANCH"

if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/$OWNER/$REPO/pages" -F "source[branch]=$PAGES_BRANCH" -F "source[path]=/"
else
  gh api -X POST "repos/$OWNER/$REPO/pages" -F "source[branch]=$PAGES_BRANCH" -F "source[path]=/"
fi

echo "Published: https://$OWNER.github.io/$REPO/"
