#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Fehler: Der App-Build funktioniert nur auf macOS."
  exit 1
fi

CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Benutzung: $0 [debug|release]"
  exit 1
fi

TARGET_ARCH="${MININOTCH_ARCH:-arm64}"
if [[ "$TARGET_ARCH" != "arm64" ]]; then
  echo "Fehler: Dieser Build ist aktuell nur für Apple Silicon (arm64) vorgesehen."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Fehler: Homebrew wird auf dem Build-Mac benötigt, um media-control einzubetten."
  exit 1
fi

MEDIA_CONTROL_PREFIX="$(brew --prefix media-control 2>/dev/null || true)"
if [[ -z "$MEDIA_CONTROL_PREFIX" || ! -x "$MEDIA_CONTROL_PREFIX/bin/media-control" ]]; then
  echo "Fehler: media-control fehlt auf dem Build-Mac. Führe zuerst 'brew install media-control' aus."
  exit 1
fi

for REQUIRED_PATH in \
  "$MEDIA_CONTROL_PREFIX/lib/media-control/mediaremote-adapter.pl" \
  "$MEDIA_CONTROL_PREFIX/lib/media-control/MediaRemoteAdapterTestClient" \
  "$MEDIA_CONTROL_PREFIX/Frameworks/MediaRemoteAdapter.framework"; do
  if [[ ! -e "$REQUIRED_PATH" ]]; then
    echo "Fehler: media-control ist unvollständig: $REQUIRED_PATH"
    exit 1
  fi
done

echo "==> Swift Build ($CONFIG) ..."
swift build -c "$CONFIG" --arch "$TARGET_ARCH"

BIN_DIR="$(swift build -c "$CONFIG" --arch "$TARGET_ARCH" --show-bin-path)"
APP_DIR="$ROOT/build/MiniNotch.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
MEDIA_CONTROL_DIR="$RESOURCES/media-control"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_DIR/MiniNotch" "$MACOS/MiniNotch"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$RESOURCES/MenuBarIcon.png"

echo "==> Bette media-control ein ..."
mkdir -p "$MEDIA_CONTROL_DIR"
ditto "$MEDIA_CONTROL_PREFIX/bin" "$MEDIA_CONTROL_DIR/bin"
ditto "$MEDIA_CONTROL_PREFIX/lib" "$MEDIA_CONTROL_DIR/lib"
ditto "$MEDIA_CONTROL_PREFIX/Frameworks" "$MEDIA_CONTROL_DIR/Frameworks"

chmod +x "$MACOS/MiniNotch"

# Alle verschachtelten Mach-O-Dateien einzeln signieren, anschließend das Bundle.
# Mit CODE_SIGN_IDENTITY kann später eine Developer-ID-Signatur verwendet werden.
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:--}"
sign_path() {
  local path="$1"
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$path" >/dev/null
  else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$path" >/dev/null
  fi
}

sign_path "$MEDIA_CONTROL_DIR/Frameworks/MediaRemoteAdapter.framework"
sign_path "$MEDIA_CONTROL_DIR/lib/media-control/MediaRemoteAdapterTestClient"
sign_path "$MACOS/MiniNotch"
sign_path "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo
echo "Fertig: $APP_DIR"
