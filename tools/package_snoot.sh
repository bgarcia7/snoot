#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="Snoot.app"
EXECUTABLE="$APP/Contents/MacOS/Snoot"
INFO_PLIST="$APP/Contents/Info.plist"
ZIP="dist/Snoot.zip"
IDENTITY="${SNOOT_SIGN_IDENTITY:-}"
PROFILE="${SNOOT_NOTARY_PROFILE:-}"

mkdir -p dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat >"$INFO_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Snoot</string>
  <key>CFBundleExecutable</key>
  <string>Snoot</string>
  <key>CFBundleIconFile</key>
  <string>Snoot</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.snoot</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Snoot</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.9</string>
  <key>CFBundleVersion</key>
  <string>9</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

tools/generate_snoot_assets.py

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

"$ROOT/tools/prepare_github_pages.sh"
tests/run_tests.sh
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Packaged $ZIP"
