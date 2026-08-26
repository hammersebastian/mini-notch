#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/MiniNotch.app"

if [[ ! -d "$APP" ]]; then
  "$ROOT/scripts/build-app.sh"
fi

# Bereits laufende Entwicklungsinstanz schließen, damit man Änderungen sofort sieht.
pkill -x MiniNotch >/dev/null 2>&1 || true
sleep 0.2
open "$APP"

echo "MiniNotch wurde gestartet."
echo "Starte Spotify oder ein YouTube-Video und fahre mit der Maus über die Notch."
