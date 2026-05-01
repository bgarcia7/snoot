# Snoot

A tiny native macOS desktop pet. Snoot floats above your normal windows with a transparent background, wanders around, chirps, accepts pets and snacks, and curls up in a burrow.

## Run

Double-click `Snoot.app` for the cleanest launch.

Double-click `run_dragon.command` as a fallback launcher.

## Controls

- Left click: pet Snoot
- Drag: move Snoot
- Double-click: feed it a meteor berry
- Click the little top-screen burrow, right-click `Send home`, or press `h`: send it home
- Click the burrow: open the burrow window and send Snoot inside or back out
- Right-click or Control-click: open the menu
- `p`: pet, `f`: feed, `h`: home, `q` or `Esc`: quit

Snoot only uses short sound-effect chirps, no synthesized voice. It can walk on the bottom of the screen, briefly fly when it has wings, perch on visible window tops when macOS reports them, and fall if the support underneath disappears.

This version is a native AppKit app, so the transparent background is handled by macOS rather than Tk.

## Growth System

The app saves creature state in `~/Library/Application Support/Snoot/creature.json`. It will migrate an older local Pocket Dragon save the first time Snoot runs.

Design data lives in:

- `data/species/dragon.json`
- `data/foods.json`
- `data/growth_rules.json`
- `data/creator.json`

Open the burrow from Snoot's menu to live-test and save attributes: name, age/stage, stats, growth exposures, colors, body parts, favorite food/color, last app, and cave pieces.

Snoot can export a mobile-friendly PNG share card from `Share Snoot...`, suitable for Messages or email. Use `Copy Share Image` to put the generated image directly on the clipboard.

## Build And Test

```sh
tools/generate_snoot_assets.py
clang -fobjc-arc -fno-modules -framework Cocoa PocketDragonNative.m -o "Snoot.app/Contents/MacOS/Snoot"
tests/run_tests.sh
```

Build a fresh local zip:

```sh
tools/package_snoot.sh
```

For public distribution without the macOS malware-verification warning, package with a Developer ID Application certificate and a saved notarytool keychain profile:

```sh
SNOOT_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
SNOOT_NOTARY_PROFILE="snoot-notary" \
tools/package_snoot.sh
```

To replace the menu/app icon with a generated chroma-key silhouette:

```sh
tools/import_snoot_icon.py /path/to/generated-silhouette.png
```

The simple landing page lives at `landing/index.html` and links to `dist/Snoot.zip`.
Its walking sprite frames are exported from the same native renderer as the app:

```sh
"Snoot.app/Contents/MacOS/Snoot" --export-landing-sprites landing
```

## GitHub Pages

Prepare a static GitHub Pages bundle:

```sh
tools/prepare_github_pages.sh
```

Publish it to a GitHub repo after authenticating `gh`:

```sh
gh auth login -h github.com
tools/publish_github_pages.sh snoot public
```

That publishes `github-pages/index.html` plus the app zip to `https://YOUR_GITHUB_USER.github.io/snoot/`.

Run a growth simulation:

```sh
tools/simulate_growth.py --profile engineer --days 180 --seed 7
```

The simulator writes JSON plus an HTML visual preview under `simulations/out`.
