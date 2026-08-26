#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh" release

DEST="$HOME/Applications"
mkdir -p "$DEST"

pkill -x MiniNotch >/dev/null 2>&1 || true
# LaunchServices braucht kurz, um die beendete Instanz aus der Registrierung
# zu entfernen. Ohne Pause kann das anschließende `open` mit Fehler -600
# gegen den gerade beendeten Prozess laufen.
sleep 0.2
rm -rf "$DEST/MiniNotch.app"
cp -R "$ROOT/build/MiniNotch.app" "$DEST/MiniNotch.app"

open "$DEST/MiniNotch.app"

echo "Installiert nach: $DEST/MiniNotch.app"
echo "Jetzt kannst du in MiniNotch > Einstellungen den Autostart aktivieren."
