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

echo "==> Swift Build ($CONFIG) ..."
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$ROOT/build/MiniNotch.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_DIR/MiniNotch" "$MACOS/MiniNotch"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

chmod +x "$MACOS/MiniNotch"

# Ad-hoc signieren. Für die private lokale Nutzung reicht das aus.
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo
echo "Fertig: $APP_DIR"
