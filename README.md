# MiniNotch

Kleine native macOS-App für die MacBook-Notch. Sie zeigt die aktuell aktive System-Medienquelle an – primär Spotify, aber auch Browser/YouTube, wenn macOS die Wiedergabe als Now Playing meldet.

![UI-Referenz](docs/reference-ui.png)

## Funktionen in V0.1

- Titel, Interpret und Cover direkt an der Notch
- Spotify und andere macOS-Now-Playing-Quellen, z. B. YouTube im Browser
- Hover: größere Player-Ansicht
- Play/Pause, vorheriger und nächster Titel
- anklick-/ziehbare Timeline zum Spulen
- Systemlautstärke
- animierter Equalizer
- beim Titelwechsel optional für ca. 2,8 Sekunden größere Notch
- umschaltbare Codex-Limits: 5-Stunden- und Wochenverbrauch in Prozent
- Menüleisten-App ohne Dock-Icon
- optionale Anmeldung beim Login
- wenn keine Medienquelle gemeldet wird, ist MiniNotch unsichtbar

## Lokal installieren

Diese Anleitung installiert und baut MiniNotch aus dem Quellcode. Sie wurde für Apple-Silicon- und Intel-Macs mit macOS 14 oder neuer ausgelegt.

### Voraussetzungen

Du brauchst **nicht die komplette Xcode-App**. Für den Build reichen normalerweise:

1. macOS 14 oder neuer
2. Apple Command Line Tools mit Swift
3. Git
4. Homebrew
5. optional: VS Code zum Bearbeiten und Debuggen
6. `media-control` (wird durch das Setup-Script installiert)

### Apple Command Line Tools

Falls `swift --version` im Terminal nicht funktioniert:

```bash
xcode-select --install
```

Danach das Installationsfenster von macOS abschließen.

### Homebrew

Falls `brew --version` noch nicht funktioniert, Homebrew nach der offiziellen Anleitung installieren: <https://brew.sh>. Anschließend das Terminal neu öffnen.

Git wird normalerweise bereits mit den Apple Command Line Tools installiert. Falls nicht, kann es über Homebrew installiert werden:

```bash
brew install git
```

### Repository herunterladen

Im Terminal einen gewünschten Zielordner wählen und das Repository klonen:

```bash
git clone https://github.com/hammersebastian/mini-notch.git
cd mini-notch
```

Für private Repositories muss GitHub für HTTPS authentifiziert sein, beispielsweise mit der [GitHub-CLI](https://cli.github.com/):

```bash
gh auth login
```

Danach den `git clone`-Befehl erneut ausführen.

### VS Code

Beim Öffnen des Projekts empfiehlt VS Code automatisch:

- Swift
- CodeLLDB

Die Swift-Erweiterung ist für normales Bearbeiten/Fehleranzeige ausreichend. CodeLLDB ist nur fürs Debugging nötig.

## Schnellstart

### 1. Optional: in VS Code öffnen

Im Terminal:

```bash
cd /Pfad/zu/mini-notch
code .
```

Oder in VS Code: **File → Open Folder… → MiniNotch**.

### 2. Setup ausführen

Im integrierten VS-Code-Terminal:

```bash
./scripts/setup.sh
```

Das Script prüft Swift und Homebrew und installiert `media-control`, falls es noch fehlt. Es verändert keine Systemeinstellungen außerhalb der Homebrew-Installation.

Alternativ in VS Code:

**Terminal → Run Task… → MiniNotch: Setup**

### 3. Medienerkennung separat testen

Spotify starten und einen Song abspielen. Dann:

```bash
./scripts/test-media.sh
```

Es sollten JSON-Zeilen mit u. a. `title`, `artist`, `playing` und meist `artworkData` erscheinen.

Jetzt zusätzlich YouTube in Safari/Chrome ausprobieren. Wenn der Browser die Media Session an macOS meldet, wechselt die Ausgabe auf das Video.

Mit `Ctrl+C` beenden.

### 4. App bauen und starten

```bash
./scripts/dev.sh
```

Oder in VS Code einfach:

**Terminal → Run Build Task…**

Shortcut: `⇧⌘B`

Das erzeugt:

```text
build/MiniNotch.app
```

und öffnet die App direkt.

## So testest du die Funktionen

1. Spotify starten und Musik abspielen.
2. Oben an der echten MacBook-Notch sollten Cover, Titel/Interpret und die Player-Anzeige erscheinen.
3. Mit der Maus über die Notch fahren: sie klappt nach unten auf.
4. Play/Pause, Zurück und Weiter anklicken.
5. In der Timeline klicken oder ziehen, um zu spulen.
6. Lautstärkeregler bewegen.
7. In Spotify zum nächsten Song springen. Die Notch sollte ca. 2,8 Sekunden größer werden.
8. Menüleisten-Musiknote → **Einstellungen …**.
9. **Neuen Titel kurz hervorheben** aus- und wieder einschalten.
10. Über die Notch fahren und oben direkt zwischen **Medien** und **Codex** wechseln. Die Codex-Ansicht zeigt das 5-Stunden- und Wochenlimit; beim Hover erscheinen Fortschrittsbalken sowie die verbleibende Zeit und der genaue Rücksetzzeitpunkt.
11. Spotify/Browser komplett schließen. In der Medienansicht verschwindet MiniNotch, sobald macOS keine Now-Playing-Quelle mehr meldet.

## Release lokal installieren

Wenn alles funktioniert:

```bash
./scripts/install-app.sh
```

Das baut eine Release-Version und kopiert sie nach:

```text
~/Applications/MiniNotch.app
```

Anschließend kannst du in den MiniNotch-Einstellungen **Beim Anmelden starten** aktivieren.

## Aktualisieren

In den lokalen Repository-Ordner wechseln, Änderungen abrufen und die App erneut installieren:

```bash
cd /Pfad/zu/mini-notch
git pull --ff-only
./scripts/install-app.sh
```

Falls sich Abhängigkeiten geändert haben, vorher noch einmal `./scripts/setup.sh` ausführen.

## VS-Code-Tasks

`⇧⌘P` → `Tasks: Run Task`:

- **MiniNotch: Setup** – Abhängigkeiten prüfen/installieren
- **MiniNotch: Build + Start** – Debug-App bauen und starten
- **MiniNotch: Test Media** – rohe Now-Playing-Daten anzeigen
- **MiniNotch: Release installieren** – lokale Release-App installieren

## Projektstruktur

```text
MiniNotch/
├── .vscode/
├── Resources/
│   └── Info.plist
├── Sources/MiniNotch/
│   ├── AppDelegate.swift
│   ├── AppModel.swift
│   ├── EqualizerView.swift
│   ├── MediaControlService.swift
│   ├── MediaState.swift
│   ├── MiniNotchApp.swift
│   ├── NotchPanelController.swift
│   ├── NotchView.swift
│   ├── SeekBar.swift
│   ├── SettingsView.swift
│   └── SystemVolumeService.swift
├── docs/
│   └── reference-ui.png
├── scripts/
├── THIRD_PARTY.md
├── Package.swift
└── README.md
```

## Hinweise

### YouTube wird nicht erkannt

MiniNotch liest die System-Now-Playing-Quelle. Browser und Webseiten müssen ihre Wiedergabe an macOS melden. Spotify funktioniert in der Regel am zuverlässigsten. YouTube funktioniert bei Browsern mit Media-Session-Unterstützung häufig ebenfalls.

### Cover erscheint verzögert

Das ist normal. Die MediaRemote-Metadaten können das Artwork etwas später liefern als den Titel.

### Spulen funktioniert bei einem Player nicht

`media-control seek` hängt davon ab, ob die aktuelle Medien-App Seeking über MediaRemote akzeptiert. Spotify funktioniert meist besser als manche Browser/Player.

### Autostart schlägt im Entwicklungsbuild fehl

Installiere die App zuerst mit:

```bash
./scripts/install-app.sh
```

und aktiviere Autostart dann aus `~/Applications/MiniNotch.app`.

### App nach macOS-Update plötzlich ohne Medien

Im Menüleisten-Icon **Medienerkennung neu starten** wählen und zusätzlich prüfen:

```bash
media-control get
```

### `swift build` meldet eine nicht unterstützte SDK- oder Compiler-Version

Die Apple Command Line Tools passen dann nicht zu der installierten macOS-Version. Die Tools über **Systemeinstellungen → Allgemein → Softwareupdate** aktualisieren. Falls danach weiterhin ein Fehler erscheint, die Command Line Tools mit dem macOS-Installer neu installieren lassen:

```bash
xcode-select --install
```

Danach das Terminal neu starten und `./scripts/setup.sh` erneut ausführen.

## Aktueller technischer Aufbau

MiniNotch verwendet für die V0.1 das separat installierte `media-control`. Das ermöglicht aktuelle Now-Playing-Daten auch auf neueren macOS-Versionen. Für eine spätere Version kann der zugrunde liegende MediaRemote-Adapter direkt mit der App gebündelt werden; dann braucht der zweite Mac kein Homebrew mehr.

## Datenschutz und Sicherheit

- MiniNotch kommuniziert mit `media-control` nur lokal, um die macOS-Now-Playing-Daten abzufragen und zu steuern.
- Die optionale Codex-Ansicht liest nach `codex login` die lokale Datei `~/.codex/auth.json` und fragt damit aktuelle Nutzungsgrenzen ab. Zugangsdaten werden nicht gespeichert, geloggt oder verändert.
- Das Release-Installationsscript ersetzt ausschließlich `~/Applications/MiniNotch.app` und startet anschließend diese lokale App.

### Codex-Limits

Für die Codex-Anzeige muss auf dem Mac einmal `codex login` ausgeführt worden sein. MiniNotch liest danach ausschließlich die lokale Datei `~/.codex/auth.json` und ruft damit die aktuellen 5-Stunden- und Wochenlimits von ChatGPT ab. Zugangsdaten werden weder gespeichert noch geloggt oder verändert. Die Anzeige aktualisiert sich beim Start, beim Wechsel auf die Codex-Ansicht, auf Knopfdruck und danach alle fünf Minuten.

Der dafür verwendete Usage-Endpunkt ist derzeit nicht öffentlich dokumentiert und kann sich daher durch OpenAI ändern.
