#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

plutil -lint "Snoot.app/Contents/Info.plist" >/dev/null
test -x "Snoot.app/Contents/MacOS/Snoot"
test -s "Snoot.app/Contents/Resources/Snoot.icns"
test -s "Snoot.app/Contents/Resources/SnootStatusIcon.png"
test -s "landing/snoot-mark.png"
test -s "landing/snoot-walk-0.png"
test -s "landing/snoot-walk-1.png"
test -s "landing/snoot-walk-2.png"
test -s "landing/snoot-walk-3.png"
test -s "github-pages/index.html"
test -s "github-pages/Snoot.zip"
test -s "github-pages/snoot-mark.png"
test -s "assets/snoot-icon-template.png"

rg -q 'URLByAppendingPathComponent:@"Snoot"' PocketDragonNative.m
rg -q 'image.template = YES' PocketDragonNative.m
rg -q 'showOnboardingIfNeeded' PocketDragonNative.m
rg -q 'exportShareSnapshot' PocketDragonNative.m
rg -q 'exportShareImage' PocketDragonNative.m
rg -q 'copyShareImage' PocketDragonNative.m
rg -q 'exportLandingSpritesToDirectory' PocketDragonNative.m
rg -q 'stylePanelButton' PocketDragonNative.m
rg -q 'recentApps' PocketDragonNative.m
rg -q 'NSMaxY\(self.screenFrame\) \+ 12\.0' PocketDragonNative.m
rg -q 'Snoot' landing/index.html
rg -q '../dist/Snoot.zip' landing/index.html
rg -q 'snoot-walker' landing/index.html
rg -q 'href="Snoot.zip"' github-pages/index.html
if rg -q '../dist/Snoot.zip' github-pages/index.html; then
  echo "github-pages/index.html should use local Snoot.zip link" >&2
  exit 1
fi

echo "Snoot smoke tests passed"
