#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="Snoot.app"
EXECUTABLE="$APP/Contents/MacOS/Snoot"
ZIP="dist/Snoot.zip"
IDENTITY="${SNOOT_SIGN_IDENTITY:-}"
PROFILE="${SNOOT_NOTARY_PROFILE:-}"

mkdir -p dist

clang -fobjc-arc -fno-modules -framework Cocoa PocketDragonNative.m -o "$EXECUTABLE"
"$EXECUTABLE" --export-landing-sprites landing

if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  codesign --force --deep --sign - "$APP"
fi

xattr -cr "$APP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
xattr -c "$ZIP"

if [[ -n "$IDENTITY" && -n "$PROFILE" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  xattr -c "$ZIP"
fi

tests/run_tests.sh
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Packaged $ZIP"
