#!/usr/bin/env bash
# Lokálne zostavenie .dmg (spúšťaj na Macu s Flutterom a Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS=android,macos bash scripts/prepare_platforms.sh
flutter build macos --release

APP=$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -n 1)
[ -n "$APP" ] || { echo "Aplikácia .app sa nenašla"; exit 1; }

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
hdiutil create -volname "Konverzo Mail" -srcfolder "$STAGE" -ov -format UDZO dist/KonverzoMail.dmg
echo "Hotovo: dist/KonverzoMail.dmg"
