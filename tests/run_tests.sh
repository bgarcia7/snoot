#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v rg >/dev/null 2>&1; then
  SEARCH=(rg -q)
else
  SEARCH=(grep -Eq)
fi

plutil -lint "Snoot.app/Contents/Info.plist" >/dev/null
test -x "Snoot.app/Contents/MacOS/Snoot"
test -s "Snoot.app/Contents/Resources/Snoot.icns"
test -s "Snoot.app/Contents/Resources/SnootStatusIcon.png"
test -s "landing/snoot-mark.png"
test -s "landing/snootwalk0.png"
test -s "landing/snootwalk1.png"
test -s "landing/snootwalk2.png"
test -s "landing/snootwalk3.png"
test -s "dist/github-pages/index.html"
test -s "dist/github-pages/Snoot.zip"
test -s "dist/github-pages/snoot-mark.png"
test -s "assets/snoot-icon-template.png"
test -s "data/favorite-build.json"

"${SEARCH[@]}" 'URLByAppendingPathComponent:@"Snoot"' PocketDragonNative.m
"${SEARCH[@]}" 'image.template = YES' PocketDragonNative.m
"${SEARCH[@]}" 'showOnboardingIfNeeded' PocketDragonNative.m
"${SEARCH[@]}" 'exportShareSnapshot' PocketDragonNative.m
"${SEARCH[@]}" 'exportShareImage' PocketDragonNative.m
"${SEARCH[@]}" 'copyShareImage' PocketDragonNative.m
"${SEARCH[@]}" 'exportLandingSpritesToDirectory' PocketDragonNative.m
"${SEARCH[@]}" 'bundledFavoriteBuildDictionary' PocketDragonNative.m
"${SEARCH[@]}" 'stylePanelButton' PocketDragonNative.m
"${SEARCH[@]}" 'recentApps' PocketDragonNative.m
"${SEARCH[@]}" 'NSMaxY\(self.screenFrame\) \+ 12\.0' PocketDragonNative.m
"${SEARCH[@]}" 'Snoot' landing/index.html
"${SEARCH[@]}" '../dist/Snoot.zip' landing/index.html
"${SEARCH[@]}" 'snoot-walker' landing/index.html
"${SEARCH[@]}" 'FavoriteBuild.json' tools/package_snoot.sh
"${SEARCH[@]}" 'data/favorite-build.json' README.md
"${SEARCH[@]}" 'href="Snoot.zip"' dist/github-pages/index.html
if "${SEARCH[@]}" '../dist/Snoot.zip' dist/github-pages/index.html; then
  echo "dist/github-pages/index.html should use local Snoot.zip link" >&2
  exit 1
fi

echo "Snoot smoke tests passed"
