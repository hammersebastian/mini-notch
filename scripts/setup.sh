#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Fehler: MiniNotch kann nur auf macOS gebaut werden."
  exit 1
fi

echo "==> Prüfe Swift Toolchain ..."
if ! command -v swift >/dev/null 2>&1; then
  echo
  echo "Swift wurde nicht gefunden."
  echo "Installiere zuerst die Apple Command Line Tools mit:"
  echo "  xcode-select --install"
  echo "Danach dieses Script erneut starten."
  exit 1
fi
swift --version | head -n 1

echo
echo "==> Prüfe Homebrew ..."
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew wurde nicht gefunden."
  echo "Installiere Homebrew von https://brew.sh und starte danach dieses Script erneut."
  exit 1
fi

echo
echo "==> Prüfe media-control ..."
if command -v media-control >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/media-control ]] || [[ -x /usr/local/bin/media-control ]]; then
  echo "media-control ist bereits installiert."
else
  brew install media-control
fi

echo
echo "==> Kurzer Test ..."
MEDIA_CONTROL="$(command -v media-control || true)"
if [[ -z "$MEDIA_CONTROL" ]]; then
  if [[ -x /opt/homebrew/bin/media-control ]]; then MEDIA_CONTROL=/opt/homebrew/bin/media-control; fi
  if [[ -x /usr/local/bin/media-control ]]; then MEDIA_CONTROL=/usr/local/bin/media-control; fi
fi

"$MEDIA_CONTROL" get >/dev/null || true

echo
echo "Fertig. Jetzt:"
echo "  ./scripts/build-app.sh"
echo "  ./scripts/run-app.sh"
