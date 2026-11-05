#!/usr/bin/env bash
# Lokálne zostavenie .apk (spúšťaj s Flutterom a Android SDK).
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS=android,macos bash scripts/prepare_platforms.sh
flutter build apk --release
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/KonverzoMail.apk
echo "Hotovo: dist/KonverzoMail.apk"
