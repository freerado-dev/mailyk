#!/usr/bin/env bash
# Vygeneruje platformové priečinky (android/, macos/) a upraví ich pre email klienta.
# Spúšťa sa z koreňa projektu. Bezpečné spustiť opakovane.
set -euo pipefail

PLATFORMS="${PLATFORMS:-android,macos}"
flutter create --platforms="$PLATFORMS" --project-name konverzo_mail --org sk.konverzo .

# Schéma presmerovania pre OAuth2 (odvodená z Google client ID v lib/oauth_config.dart)
SCHEME="sk.konverzo.konverzo_mail"
GID=$(grep -oE "googleClientId *= *'[^']*'" lib/oauth_config.dart | sed -E "s/.*'([^']*)'/\1/" || true)
case "$GID" in
  *.apps.googleusercontent.com) SCHEME="com.googleusercontent.apps.${GID%.apps.googleusercontent.com}" ;;
esac
echo "OAuth redirect scheme: $SCHEME"

# --- Android ---
if [ -d android ]; then
python3 - "$SCHEME" <<'PY'
import pathlib, re, sys

scheme = sys.argv[1]

# Gradle: minSdk 23 (flutter_secure_storage) a schéma pre flutter_appauth
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    p = pathlib.Path(name)
    if not p.exists():
        continue
    s = p.read_text()
    s = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23", s)
    s = re.sub(r'manifestPlaceholders[^\n]*appAuthRedirectScheme[^\n]*\n', '', s)
    if name.endswith(".kts"):
        ins = '        manifestPlaceholders["appAuthRedirectScheme"] = "%s"\n' % scheme
    else:
        ins = "        manifestPlaceholders += [appAuthRedirectScheme: '%s']\n" % scheme
    s = re.sub(r"(defaultConfig\s*\{\n)", lambda m: m.group(1) + ins, s, count=1)
    p.write_text(s)

# Manifest: internet + zmena veľkosti okna (Samsung Fold, rozdelená obrazovka, DeX)
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
if "android.permission.INTERNET" not in s:
    s = s.replace("<application",
                  '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
if "android:resizeableActivity" not in s:
    s = s.replace("<activity", '<activity\n            android:resizeableActivity="true"', 1)
m.write_text(s)
PY
fi

# --- macOS: sieť a URL schéma pre OAuth ---
if [ -d macos ]; then
  for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
    [ -f "$f" ] || continue
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.network.client bool true" "$f" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Set :com.apple.security.network.client true" "$f" 2>/dev/null \
      || echo "Upozornenie: PlistBuddy nie je dostupný, pridaj com.apple.security.network.client do $f ručne."
  done

  PLIST=macos/Runner/Info.plist
  if [ -f "$PLIST" ] && ! /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy \
      -c "Add :CFBundleURLTypes array" \
      -c "Add :CFBundleURLTypes:0 dict" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLName string oauth" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
      -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $SCHEME" \
      "$PLIST" 2>/dev/null \
      || echo "Upozornenie: URL schému $SCHEME pridaj do $PLIST ručne (CFBundleURLTypes)."
  fi
fi

flutter pub get
