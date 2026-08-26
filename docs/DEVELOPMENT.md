# MiniNotch – Entwicklung

Diese Anleitung richtet sich an Menschen, die MiniNotch aus dem Quellcode
bauen, testen oder eine DMG veröffentlichen möchten. Für die Installation der
fertigen App genügt die [Haupt-README](../README.md).

## Voraussetzungen auf dem Build-Mac

MiniNotch wird aktuell ausschließlich für Apple Silicon und macOS 14 oder neuer
gebaut. Für den Ziel-Mac ist davon nichts erforderlich; nur der Build-Mac
benötigt:

1. Apple Command Line Tools mit Swift
2. Git
3. Homebrew
4. `media-control` – wird vom Setup-Script installiert
5. optional VS Code mit den Erweiterungen Swift und CodeLLDB

Die vollständige Xcode-App ist nicht nötig. Wenn `swift --version` nicht
funktioniert, die Command Line Tools installieren:

```bash
xcode-select --install
```

Falls Homebrew fehlt, nach der [offiziellen Anleitung](https://brew.sh)
installieren und das Terminal anschließend neu öffnen. Git ist normalerweise
bereits über die Command Line Tools verfügbar; andernfalls:

```bash
brew install git
```

## Repository einrichten

```bash
git clone https://github.com/hammersebastian/mini-notch.git
cd mini-notch
./scripts/setup.sh
```

Für private Repositories ist eine GitHub-Authentifizierung erforderlich, etwa
über `gh auth login`. Das Setup prüft Swift und Homebrew und installiert
`media-control`, falls es noch fehlt.

Optional in VS Code öffnen:

```bash
code .
```

Die empfohlenen VS-Code-Tasks erreichst du über `⇧⌘P` → `Tasks: Run Task`:

- **MiniNotch: Setup** – Abhängigkeiten prüfen/installieren
- **MiniNotch: Build + Start** – Debug-App bauen und starten
- **MiniNotch: Test Media** – rohe Now-Playing-Daten anzeigen
- **MiniNotch: Release installieren** – lokale Release-App installieren

## Entwickeln und testen

Medienerkennung separat prüfen:

```bash
./scripts/test-media.sh
```

Starte dafür Spotify oder ein YouTube-Video. Das Script gibt JSON-Zeilen wie
`title`, `artist`, `playing` und meist `artworkData` aus. Mit `Ctrl+C` beenden.

Die Debug-App bauen und direkt starten:

```bash
./scripts/dev.sh
```

Die App liegt danach unter `build/MiniNotch.app`.

### Manueller Funktionstest

1. Spotify starten und Musik abspielen.
2. Prüfen, ob Cover, Titel/Interpret und Player-Anzeige an der Notch erscheinen.
3. Über die Notch fahren und Play/Pause, Zurück, Weiter, Timeline und Lautstärke testen.
4. Titel in Spotify wechseln und das optionale Hervorheben prüfen.
5. Menüleisten-Icon → **Einstellungen …** öffnen.
6. Medien und Codex-Limits einzeln aktivieren und deaktivieren.
7. In der erweiterten Codex-Ansicht Fortschrittsbalken, Restzeit und Rücksetzzeitpunkt prüfen.
8. Farben, Autostart und **Neuen Titel kurz hervorheben** testen.
9. Unter **Automatisches Ausblenden** den Zugriff anfordern und das Überdecken der Notch durch ein aktives Fenster testen.
10. Spotify/Browser schließen und prüfen, ob die Medienansicht verschwindet.

## Lokale Release-App

Für eine lokale Installation ohne DMG:

```bash
./scripts/install-app.sh
```

Das Script erzeugt einen Release-Build, ersetzt ausschließlich
`~/Applications/MiniNotch.app` und öffnet ihn. Danach kann der Autostart in den
MiniNotch-Einstellungen aktiviert werden.

Nach Änderungen aus dem Repository:

```bash
git pull --ff-only
./scripts/setup.sh
./scripts/install-app.sh
```

`./scripts/setup.sh` ist nur nötig, wenn sich Abhängigkeiten geändert haben.

## Release-DMG erstellen

Auf dem Build-Mac einmalig sicherstellen, dass `media-control` vorhanden ist:

```bash
brew install media-control
```

Dann die DMG erzeugen:

```bash
./scripts/create-dmg.sh
```

Das Script baut `arm64`, bettet `media-control` samt MediaRemote-Adapter in
`MiniNotch.app` ein, prüft die App-Signatur und erzeugt:

```text
build/releases/MiniNotch-0.1.0-arm64.dmg
```

Die DMG enthält einen Applications-Shortcut und `THIRD_PARTY.md`. Sie wird
nicht eingecheckt, weil `build/` absichtlich in `.gitignore` steht. Stattdessen
die DMG als Asset zu einem [GitHub Release](https://github.com/hammersebastian/mini-notch/releases) hochladen.

### Signieren und Notarisieren

Für eine öffentliche Verteilung ohne Gatekeeper-Warnung ist eine Apple Developer
ID erforderlich. Der Build kann mit einer vorhandenen Identität signiert
werden:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Dein Name (TEAMID)" ./scripts/create-dmg.sh
```

Danach die erzeugte DMG bei Apple notarisieren und das Notarisierungs-Ticket an
die DMG heften. Ohne diesen Schritt kann ein Nutzer MiniNotch beim ersten Start
über Finder → Rechtsklick → **Öffnen** freigeben.

## Projektstruktur

```text
MiniNotch/
├── .vscode/                  VS-Code-Tasks
├── Resources/                App-Icon, Menüleisten-Icon und Info.plist
├── Sources/MiniNotch/        SwiftUI- und AppKit-Code
├── docs/                     Screenshots und diese Entwicklerdokumentation
├── scripts/                  Setup-, Build-, Test- und Release-Scripts
├── THIRD_PARTY.md            Lizenzhinweise für media-control
├── Package.swift             Swift-Package-Konfiguration
└── README.md                 Projektvorstellung und DMG-Installation
```

## Technische Hinweise

MiniNotch nutzt `media-control` einschließlich MediaRemote-Adapter für
Now-Playing-Daten. `scripts/build-app.sh` kopiert die Apple-Silicon-Version
nach `MiniNotch.app/Contents/Resources/media-control`; der Ziel-Mac braucht
deshalb kein Homebrew. Das Projekt kommuniziert mit dem Helper nur lokal, um
Medieninformationen abzufragen und Wiedergabe zu steuern.

Die optionale Codex-Ansicht liest nach `codex login` die lokale Datei
`~/.codex/auth.json` und fragt damit aktuelle Nutzungsgrenzen ab. Zugangsdaten
werden nicht gespeichert, geloggt oder verändert. Die Anzeige aktualisiert sich
beim Start, beim Wechsel zur Codex-Ansicht, auf Knopfdruck und danach alle fünf
Minuten. Der verwendete Usage-Endpunkt ist nicht öffentlich dokumentiert und
kann sich ändern.

Die in der DMG enthaltenen Komponenten `media-control` und
`mediaremote-adapter` stehen unter BSD-3-Clause. Vollständige Hinweise stehen in
[THIRD_PARTY.md](../THIRD_PARTY.md).

## Fehlerbehebung

### YouTube wird nicht erkannt

MiniNotch liest die System-Now-Playing-Quelle. Browser und Webseiten müssen ihre
Wiedergabe als Media Session an macOS melden. Spotify funktioniert meist am
zuverlässigsten.

### Cover erscheint verzögert

Das ist normal: MediaRemote kann Artwork später als Titel und Interpret liefern.

### Spulen funktioniert bei einem Player nicht

`media-control seek` hängt davon ab, ob die jeweilige Medien-App Seeking über
MediaRemote unterstützt. Spotify funktioniert meist besser als manche
Browser-Player.

### Autostart schlägt im Entwicklungsbuild fehl

Zuerst `./scripts/install-app.sh` ausführen und Autostart anschließend aus
`~/Applications/MiniNotch.app` aktivieren.

### Nach einem macOS-Update fehlen Medieninformationen

MiniNotch beenden und erneut starten. Auf dem Build-Mac zusätzlich prüfen:

```bash
media-control get
```

### `swift build` meldet eine nicht unterstützte SDK- oder Compiler-Version

Die Apple Command Line Tools über **Systemeinstellungen → Allgemein →
Softwareupdate** aktualisieren. Falls nötig anschließend erneut ausführen:

```bash
xcode-select --install
```

Danach das Terminal neu starten und `./scripts/setup.sh` wiederholen.
