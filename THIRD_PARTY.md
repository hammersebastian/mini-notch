# Drittanbieter-Komponente

MiniNotch selbst enthält in diesem ZIP keinen fremden Binärcode.

Zur Laufzeit wird das separat installierte Tool `media-control` von ungive verwendet:

- Repository: https://github.com/ungive/media-control
- Grundlage: https://github.com/ungive/mediaremote-adapter
- Lizenz der zugrunde liegenden Projekte: BSD-3-Clause (siehe jeweiliges Repository)

`./scripts/setup.sh` installiert `media-control` über Homebrew, wenn es noch nicht vorhanden ist.
