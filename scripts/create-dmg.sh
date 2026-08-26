#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/MiniNotch.app"
STAGING_DIR=""

cleanup() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

"$ROOT/scripts/build-app.sh" release

APP_ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/MiniNotch")"
if [[ "$APP_ARCHS" != "arm64" ]]; then
  echo "Fehler: Die App enthält nicht ausschließlich die erwartete arm64-Architektur: $APP_ARCHS"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
RELEASE_DIR="$ROOT/build/releases"
DMG_PATH="$RELEASE_DIR/MiniNotch-$VERSION-arm64.dmg"

mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mininotch-dmg.XXXXXX")"

ditto "$APP_DIR" "$STAGING_DIR/MiniNotch.app"
cp "$ROOT/THIRD_PARTY.md" "$STAGING_DIR/THIRD_PARTY.md"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "MiniNotch $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

echo "Fertig: $DMG_PATH"
echo "Enthält MiniNotch inklusive media-control für Apple Silicon."
