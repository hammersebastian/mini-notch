#!/usr/bin/env bash
set -euo pipefail

MEDIA_CONTROL="$(command -v media-control || true)"
if [[ -z "$MEDIA_CONTROL" && -x /opt/homebrew/bin/media-control ]]; then MEDIA_CONTROL=/opt/homebrew/bin/media-control; fi
if [[ -z "$MEDIA_CONTROL" && -x /usr/local/bin/media-control ]]; then MEDIA_CONTROL=/usr/local/bin/media-control; fi

if [[ -z "$MEDIA_CONTROL" ]]; then
  echo "media-control fehlt. Führe zuerst ./scripts/setup.sh aus."
  exit 1
fi

echo "Streaming läuft. Starte Spotify oder YouTube. Mit Ctrl+C beenden."
exec "$MEDIA_CONTROL" stream --no-diff
