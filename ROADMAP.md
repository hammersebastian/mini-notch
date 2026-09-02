# MiniNotch Roadmap

> **Vision:** MiniNotch soll keine überladene Widget-Sammlung werden, sondern eine kleine, native macOS-App, die genau das in der Notch zeigt, was gerade wichtig ist.

MiniNotch entwickelt sich damit von einem Media-Player in der Notch zu einer schlanken **Dynamic-Island-ähnlichen Live-Activity-Oberfläche für macOS**.

---

## Grundprinzip

MiniNotch unterscheidet langfristig zwischen drei Zuständen:

```text
                   ┌──── Notch ────┐

IDLE
         Hardware Notch / unsichtbar


ACTIVITY
      🎵   Fred again..   ▮▮

      🔊   ███████░░ 72 %

      ⚡   Charging 68 %

      ⏱   04:32


EXPANDED
        komplette Hover UI
```

Die Notch soll im Normalfall möglichst ruhig bleiben.

Temporäre Ereignisse wie Lautstärkeänderungen, ein angeschlossenes Netzteil, ein beendeter Timer oder verbundene AirPods dürfen sich kurz in den Vordergrund schieben und anschließend wieder verschwinden.

---

# Übersicht

| Version | Schwerpunkt | Ziel |
|---|---|---|
| **v0.2** | Live Activity Basis | Gemeinsame Architektur für temporäre Notch-Aktivitäten |
| **v0.3** | System HUD | Lautstärke, Helligkeit, Laden und Akku |
| **v0.4** | Geräte | AirPods, Bluetooth-Audio und Audio Output |
| **v0.5** | Produktivität | Kalender und Timer |
| **v0.6** | Developer Features | Codex Usage und Warnungen ausbauen |
| **v0.7** | File Activities | Dateiübertragungen, Downloads und Drop Shelf |
| **v0.8** | Interaktion | Gesten, Activity-Steuerung und Customizing |
| **v0.9** | Qualität | Performance, Multi-Monitor, Accessibility und Tests |
| **v1.0** | Stable Release | Stabile, fokussierte macOS Dynamic Island |

---

# v0.2 – Activity Engine

## Ziel

Bevor weitere Features direkt in die bestehende UI eingebaut werden, bekommt MiniNotch eine gemeinsame Activity-Architektur.

Media, Codex, Volume, Battery, Timer und spätere Funktionen sollen nicht jeweils ihre eigene Zustandslogik besitzen.

Stattdessen entscheidet eine zentrale Stelle:

> Welche Aktivität soll gerade in der Notch angezeigt werden?

---

## NotchActivity

Beispiel für ein gemeinsames Interface:

```swift
protocol NotchActivity {
    var id: String { get }
    var priority: Int { get }

    var presentation: ActivityPresentation { get }

    var isActive: Bool { get }

    var autoDismissAfter: TimeInterval? { get }
}
```

Mögliche Darstellungsarten:

```swift
enum ActivityPresentation {
    case compact
    case expanded
    case notification
}
```

---

## ActivityManager

Der `ActivityManager` verwaltet alle aktuell verfügbaren Activities.

Beispielhafte Prioritäten:

```text
Priority

100   Timer beendet
 90   Kritischer Akku
 80   Volume / Brightness
 70   AirPods verbunden
 60   Charging
 50   Codex Warnung
 30   Media
 20   Calendar
```

Dadurch kann Media als Standard-Aktivität weiterlaufen, während wichtigere Events temporär übernehmen.

### Beispiel

```text
┌───────────────┐
│     MEDIA     │
└───────┬───────┘
        │
        │ Lautstärke geändert
        ▼
┌───────────────┐
│    VOLUME     │
│ ███████░ 72 % │
└───────┬───────┘
        │
        │ nach 1,5 Sekunden
        ▼
┌───────────────┐
│     MEDIA     │
└───────────────┘
```

---

## Übergänge

Die Activity Engine sollte gemeinsame Übergänge anbieten:

```text
hidden
  │
  ▼
compact
  │
  ▼
activity
  │
  ▼
expanded
```

Später kann daraus eine zentrale State Machine entstehen.

---

## GitHub Issues

- [x] `[Architecture] Introduce NotchActivity protocol`
- [x] `[Architecture] Add ActivityManager`
- [x] `[Architecture] Add activity priorities`
- [x] `[Architecture] Add automatic activity dismissal`
- [x] `[Architecture] Add shared activity lifecycle`
- [x] `[UI] Add shared compact activity container`
- [x] `[UI] Add activity transition animations`

---

# v0.3 – macOS System HUD

## Ziel

Die ersten neuen Live Activities sollen direkt auf alltägliche macOS-Systemereignisse reagieren.

---

# Volume Activity

Beim Ändern der Lautstärke öffnet sich MiniNotch kurz.

```text
┌──────────────────────────┐
│ 🔊  ███████░░   72 %     │
└──────────────────────────┘
```

Mute:

```text
┌──────────────────────────┐
│ 🔇        Stumm           │
└──────────────────────────┘
```

Danach verschwindet die Activity automatisch wieder.

Empfohlene Standarddauer:

```text
1,2 – 1,5 Sekunden
```

---

## Settings

```text
System Activities

[x] Lautstärke anzeigen
[x] Änderung animieren

Anzeigedauer
1,5 Sekunden
```

---

# Brightness Activity

Analog zur Lautstärke:

```text
┌──────────────────────────┐
│ ☀︎  ██████░░░   64 %     │
└──────────────────────────┘
```

Optional in der Expanded View:

```text
┌──────────────────────────┐
│ Display                  │
│                          │
│ MacBook Pro              │
│ ██████░░░        64 %    │
└──────────────────────────┘
```

---

# Charging Activity

Beim Anschließen des Netzteils:

```text
┌──────────────────────────┐
│ ⚡  MacBook Pro           │
│     68 % · Lädt          │
└──────────────────────────┘
```

Optional:

```text
┌──────────────────────────┐
│ ⚡ 68 %                   │
│ 1 h 24 min bis voll      │
└──────────────────────────┘
```

Akku vollständig geladen:

```text
┌──────────────────────────┐
│ ✓ Akku geladen           │
│           100 %          │
└──────────────────────────┘
```

---

# Low Battery Activity

Warnung bei niedrigem Akkustand:

```text
┌──────────────────────────┐
│ ⚠ Akku niedrig           │
│            10 %          │
└──────────────────────────┘
```

Optional unterschiedliche Schwellen:

```text
20 %   Hinweis
10 %   Warnung
 5 %   Kritisch
```

---

## GitHub Issues

- [x] `[System HUD] Add volume activity`
- [x] `[System HUD] Add mute state`
- [ ] `[System HUD] Add brightness activity`
- [ ] `[Battery] Add charging activity`
- [ ] `[Battery] Add fully charged activity`
- [ ] `[Battery] Add low battery warning`
- [ ] `[Settings] Add System Activities section`

---

# v0.4 – AirPods & Audio Devices

## Ziel

MiniNotch reagiert auf Audio-Geräte und erlaubt einen schnellen Wechsel des Audio-Ausgangs.

---

# AirPods Connection Activity

Beim Verbinden:

```text
┌──────────────────────────┐
│ AirPods Pro              │
│ ✓ Verbunden              │
└──────────────────────────┘
```

Wenn Batteriestände verfügbar sind:

```text
┌──────────────────────────┐
│ AirPods Pro              │
│                          │
│ L 84 %        R 80 %     │
│ Case 61 %                │
└──────────────────────────┘
```

Beim Trennen:

```text
┌──────────────────────────┐
│ AirPods Pro              │
│ Verbindung getrennt      │
└──────────────────────────┘
```

---

# Audio Output Switcher

In der Expanded View:

```text
┌──────────────────────────┐
│ Audio                    │
│                          │
│ ● AirPods Pro            │
│ ○ MacBook Pro Speakers   │
│ ○ Studio Display         │
│ ○ HDMI                   │
└──────────────────────────┘
```

Ein Klick auf ein Gerät wechselt direkt den Audio-Ausgang.

---

## GitHub Issues

- [ ] `[Bluetooth] Detect audio device connection`
- [ ] `[Bluetooth] Add AirPods connection activity`
- [ ] `[Bluetooth] Add disconnect activity`
- [ ] `[Bluetooth] Show available battery information`
- [ ] `[Audio] Discover output devices`
- [ ] `[Audio] Add output device selector`
- [ ] `[Audio] Switch output device from notch`

---

# v0.5 – Calendar & Timer

## Ziel

MiniNotch bekommt kleine Produktivitätsfunktionen, ohne zu einer kompletten Kalender- oder Aufgaben-App zu werden.

---

# Next Meeting

MiniNotch zeigt nur den nächsten relevanten Termin.

```text
┌──────────────────────────┐
│ Daily                    │
│ 14:30                    │
│                          │
│ in 12 min                │
└──────────────────────────┘
```

Kurz vor Beginn:

```text
┌──────────────────────────┐
│ 📅 Daily                 │
│ beginnt in 5 Minuten     │
└──────────────────────────┘
```

---

## Expanded Calendar View

```text
┌──────────────────────────┐
│ Heute                    │
│                          │
│ 14:30  Daily             │
│ 15:00  Review            │
│ 16:30  Planning          │
└──────────────────────────┘
```

---

## Calendar Settings

```text
Kalender

[x] Nächsten Termin anzeigen

Automatisch öffnen:

( ) nie
( ) 5 Minuten vorher
(x) 10 Minuten vorher
( ) 15 Minuten vorher
```

---

# Timer

Timer können über die Menüleisten-App gestartet werden.

```text
Timer

5 Minuten
10 Minuten
15 Minuten
30 Minuten

Benutzerdefiniert...
```

Laufender Timer:

```text
┌──────────────────────────┐
│ ⏱        04:38           │
└──────────────────────────┘
```

Expanded:

```text
┌──────────────────────────┐
│          04:38           │
│                          │
│   ⏸ Pause     +1 min     │
│                          │
│        Abbrechen         │
└──────────────────────────┘
```

Timer beendet:

```text
┌──────────────────────────┐
│ ✓ Timer beendet          │
└──────────────────────────┘
```

Diese Activity sollte eine sehr hohe Priorität besitzen und nicht sofort verschwinden.

---

## GitHub Issues

- [ ] `[Calendar] Request Calendar permission`
- [ ] `[Calendar] Read upcoming event`
- [ ] `[Calendar] Add upcoming meeting activity`
- [ ] `[Calendar] Add Today overview`
- [ ] `[Calendar] Add notification threshold settings`
- [ ] `[Timer] Implement timer service`
- [ ] `[Timer] Add timer presets`
- [ ] `[Timer] Add compact countdown`
- [ ] `[Timer] Add expanded timer controls`
- [ ] `[Timer] Add completed timer activity`

---

# v0.6 – Developer Usage & Codex

## Ziel

Codex Usage ist eines der Features, mit denen sich MiniNotch von vielen klassischen Notch-Apps unterscheiden kann.

Dieses Feature sollte daher nicht nur bestehen bleiben, sondern gezielt erweitert werden.

---

# Codex Compact View

```text
┌──────────────────────────┐
│ CODEX                    │
│                          │
│ 5h        72 %           │
│ Week      41 %           │
└──────────────────────────┘
```

Alternativ:

```text
┌──────────────────────────┐
│ CODEX                    │
│                          │
│ 5H    ███████░░  72 %    │
│ WEEK  ████░░░░░  41 %    │
└──────────────────────────┘
```

---

# Codex Limit Alerts

Settings:

```text
Codex Warnungen

[x] bei 50 %
[x] bei 75 %
[x] bei 90 %
[x] bei 100 %
[x] bei Reset
```

Warnung:

```text
┌──────────────────────────┐
│ Codex                    │
│                          │
│ ⚠ 90 % des 5h-Limits     │
│ Reset in 38 min          │
└──────────────────────────┘
```

Limit erreicht:

```text
┌──────────────────────────┐
│ Codex                    │
│                          │
│ Limit erreicht           │
└──────────────────────────┘
```

Reset:

```text
┌──────────────────────────┐
│ Codex                    │
│                          │
│ ✓ Limit zurückgesetzt    │
└──────────────────────────┘
```

---

# UsageProvider

Langfristig sollte die Datenquelle abstrahiert werden.

```swift
protocol UsageProvider {
    var name: String { get }

    func fetchUsage() async throws -> UsageSnapshot
}
```

Dadurch könnten später zusätzliche Developer-Tools ergänzt werden.

```text
Developer Usage

Codex
Claude
Gemini
GitHub Copilot
```

Nur Dienste sollten unterstützt werden, deren Usage-Daten zuverlässig und sauber abrufbar sind.

---

## GitHub Issues

- [ ] `[Codex] Add configurable limit warnings`
- [ ] `[Codex] Add reset notification`
- [ ] `[Codex] Improve compact usage visualization`
- [ ] `[Codex] Add dedicated warning activities`
- [ ] `[Architecture] Introduce UsageProvider`
- [ ] `[Developer] Prepare additional usage providers`

---

# v0.7 – File Activities

## Ziel

Dateiaktivitäten passen besonders gut zum Dynamic-Island-Prinzip, weil sie temporär auftreten, einen Fortschritt besitzen und anschließend verschwinden.

---

# File Copy Activity

Eine Datei:

```text
┌──────────────────────────┐
│ IMG_8392.ARW             │
│                          │
│ ███████░░       76 %     │
│                          │
│ 843 MB / 1.1 GB          │
└──────────────────────────┘
```

Mehrere Dateien:

```text
┌──────────────────────────┐
│ 147 Dateien              │
│                          │
│ ████████░       82 %     │
└──────────────────────────┘
```

Abgeschlossen:

```text
┌──────────────────────────┐
│ ✓ 147 Dateien kopiert    │
└──────────────────────────┘
```

---

# Downloads

Wenn technisch zuverlässig möglich, beginnt die Unterstützung zunächst mit Safari.

```text
┌──────────────────────────┐
│ Xcode_26.dmg             │
│                          │
│ ██████░░░       61 %     │
│                          │
│ 28 MB/s · 19 s           │
└──────────────────────────┘
```

Mehrere Downloads:

```text
┌──────────────────────────┐
│ ↓ 3 Downloads            │
│                          │
│ ███████░░       71 %     │
└──────────────────────────┘
```

---

# Drop Shelf

Dateien können direkt auf die Notch gezogen werden.

Beim Drag:

```text
┌──────────────────────────┐
│                          │
│      Datei hier          │
│       ablegen            │
│                          │
└──────────────────────────┘
```

Expanded Shelf:

```text
┌──────────────────────────┐
│ Shelf                    │
│                          │
│ IMG_2383.jpg             │
│ Rechnung.pdf             │
│ Screenshot.png           │
└──────────────────────────┘
```

Ziel ist kein vollständiger Datei-Manager, sondern ein temporärer Ablageort.

---

## GitHub Issues

- [ ] `[Files] Investigate file copy progress APIs`
- [ ] `[Files] Detect file copy progress`
- [ ] `[Files] Add copy progress activity`
- [ ] `[Files] Add copy completed activity`
- [ ] `[Downloads] Investigate Safari download integration`
- [ ] `[Downloads] Add Safari download activity`
- [ ] `[Shelf] Add notch drop target`
- [ ] `[Shelf] Add temporary file shelf`
- [ ] `[Shelf] Add remove/open actions`

---

# v0.8 – Gestures & Customization

## Ziel

MiniNotch wird schneller bedienbar, ohne dass ständig Buttons sichtbar sein müssen.

---

# Gesten

Mögliche Standardbelegung:

```text
Swipe links
→ Vorheriger Titel

Swipe rechts
→ Nächster Titel

Scroll
→ Lautstärke

Doppelklick
→ Play / Pause
```

---

## Gesture Settings

```text
Gesten

Swipe links
Vorheriger Titel

Swipe rechts
Nächster Titel

Scroll
Lautstärke

Doppelklick
Play / Pause
```

Optional können Nutzer später Aktionen selbst zuweisen.

---

# Activity Settings

Nutzer entscheiden, welche Activities aktiv sind.

```text
Activities

Media                 ● Ein
Volume                ● Ein
Brightness            ● Ein
Battery               ● Ein
Bluetooth             ● Ein
Calendar              ○ Aus
Timer                 ● Ein
Codex                  ● Ein
Files                  ● Ein
Downloads              ○ Aus
```

---

## Activity-Reihenfolge

Optional:

```text
Reihenfolge

≡ Timer
≡ Codex
≡ Media
≡ Calendar
```

Die technische Priorität kritischer Events sollte davon unabhängig bleiben.

Ein Low-Battery- oder Timer-Ende-Event darf also nicht durch eine manuelle Sortierung unter Media landen.

---

## GitHub Issues

- [ ] `[Gestures] Add horizontal swipe handling`
- [ ] `[Gestures] Add scroll handling`
- [ ] `[Gestures] Add double-click handling`
- [ ] `[Settings] Add gesture configuration`
- [ ] `[Settings] Add activity enable/disable toggles`
- [ ] `[Settings] Add activity order`
- [ ] `[Settings] Add activity display duration configuration`

---

# v0.9 – Polish, Performance & Reliability

## Ziel

Vor Version 1.0 werden keine großen neuen Feature-Bereiche mehr begonnen.

Der Fokus liegt auf Stabilität.

---

# Central Notch State Machine

Langfristig sollte der komplette UI-Zustand zentral verwaltet werden.

```text
                ┌────────┐
                │ hidden │
                └───┬────┘
                    │
                    ▼
               ┌─────────┐
               │ compact │
               └────┬────┘
                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼
    ┌──────────┐        ┌──────────┐
    │ activity │        │ expanded │
    └────┬─────┘        └────┬─────┘
         │                   │
         └─────────┬─────────┘
                   ▼
               ┌─────────┐
               │ compact │
               └─────────┘
```

---

# Performance

Ziele:

- Nahezu keine CPU-Last im Idle
- Möglichst event-driven statt Polling
- Keine unnötigen Timer
- Media Artwork cachen
- Activities nur neu rendern, wenn sich Daten wirklich ändern
- Hintergrunddienste nur aktivieren, wenn das Feature eingeschaltet ist

---

# Multi-Monitor

Folgende Fälle müssen zuverlässig funktionieren:

```text
MacBook Display
+
externer Monitor
```

```text
MacBook geöffnet
→ externer Monitor vorhanden
```

```text
MacBook geschlossen
→ nur externer Monitor
```

```text
Monitor getrennt
→ MiniNotch migriert sauber
```

```text
Monitor erneut verbunden
→ Position wird korrekt wiederhergestellt
```

Außerdem:

- unterschiedliche Auflösungen
- unterschiedliche Skalierungen
- Display Hot-Plug
- Spaces
- Fullscreen Apps

---

# Accessibility

Unterstützen:

- Reduce Motion
- VoiceOver
- Keyboard Navigation
- größere Schrift
- ausreichender Kontrast

Bei aktivem Reduce Motion sollten beispielsweise Skalierungs- und Bounce-Effekte reduziert oder deaktiviert werden.

---

# Tests

Wichtige Unit Tests:

```text
ActivityManager

✓ höchste Priorität gewinnt
✓ Activity läuft automatisch aus
✓ dauerhafte Activity bleibt bestehen
✓ Media wird nach temporärer Activity wiederhergestellt
✓ neue höhere Priority ersetzt aktuelle Activity
✓ deaktivierte Activity wird ignoriert
```

State Machine:

```text
✓ hidden → compact
✓ compact → expanded
✓ compact → activity
✓ activity → compact
✓ expanded → compact
```

---

## GitHub Issues

- [ ] `[Core] Introduce central notch state machine`
- [ ] `[Performance] Reduce background polling`
- [ ] `[Performance] Cache media artwork`
- [ ] `[Performance] Disable unused observers`
- [ ] `[Displays] Improve multi-monitor support`
- [ ] `[Displays] Handle display reconnect`
- [ ] `[Accessibility] Support Reduce Motion`
- [ ] `[Accessibility] Add VoiceOver labels`
- [ ] `[Accessibility] Improve keyboard navigation`
- [ ] `[Testing] Add ActivityManager unit tests`
- [ ] `[Testing] Add state transition tests`
- [ ] `[Testing] Add activity priority tests`

---

# v1.0 – Stable Release

## Zielumfang

MiniNotch 1.0 sollte bewusst fokussiert bleiben.

```text
MiniNotch 1.0

✓ Now Playing

✓ Media Controls

✓ Volume HUD

✓ Brightness HUD

✓ Battery / Charging

✓ AirPods / Audio Devices

✓ Calendar

✓ Timer

✓ Codex Usage

✓ Live Activity System

✓ Gestures

✓ Customization

✓ Multi-Monitor

✓ Autostart

✓ Accessibility

✓ Stable Activity Engine
```

---

# Feature-Prioritäten

## Sehr hohe Priorität

```text
★★★★★ Activity Engine
★★★★★ Volume HUD
★★★★★ Brightness HUD
★★★★★ Battery / Charging
★★★★★ Activity Priorities
```

## Hohe Priorität

```text
★★★★☆ AirPods
★★★★☆ Audio Output
★★★★☆ Calendar
★★★★☆ Timer
★★★★☆ Codex Alerts
★★★★☆ File Progress
```

## Mittlere Priorität

```text
★★★☆☆ Downloads
★★★☆☆ Gestures
★★★☆☆ Drop Shelf
★★★☆☆ Developer Usage Provider
```

## Später

```text
★★☆☆☆ Clipboard
★★☆☆☆ Pomodoro
★★☆☆☆ Kamera/Mikrofon Activity
```

---

# Features, die vor v1.0 bewusst nicht geplant sind

MiniNotch soll vor Version 1.0 nicht zu einer Sammlung beliebiger Widgets werden.

Daher vorerst nicht:

```text
✗ Wetter

✗ Aktien

✗ CPU/RAM Dashboard

✗ komplette Reminder-App

✗ kompletter Clipboard Manager

✗ ChatGPT direkt in der Notch

✗ vollständiges Notification Center

✗ Kamera / Mirror

✗ große Plugin-Plattform
```

Diese Features können nach v1.0 neu bewertet werden.

---

# Langfristige Idee – Plugin / Provider Architektur

Nach einer stabilen Version 1.0 kann über ein kleines Erweiterungssystem nachgedacht werden.

Beispiel:

```swift
protocol MiniNotchProvider {
    var identifier: String { get }
    var displayName: String { get }

    func activities() -> [NotchActivity]
}
```

Dann könnten interne oder externe Provider existieren:

```text
MiniNotch

├── MediaProvider
├── BatteryProvider
├── VolumeProvider
├── CalendarProvider
├── CodexProvider
├── TimerProvider
└── FileProvider
```

Wichtig:

> Erst abstrahieren, wenn mehrere reale Implementierungen existieren.

Keine Plugin-Architektur bauen, bevor klar ist, dass sie tatsächlich gebraucht wird.

---

# Empfohlene nächste GitHub Issues

Wenn die Entwicklung jetzt weitergeht, sollten die nächsten Issues genau in dieser Reihenfolge umgesetzt werden:

```text
01  Create NotchActivity abstraction

02  Implement ActivityManager with priorities

03  Add automatic activity dismissal

04  Add activity transition animations

05  Add Volume Live Activity

06  Add Brightness Live Activity

07  Add Battery Charging Activity

08  Add Low Battery Activity

09  Add Activity toggles to Settings

10  Add AirPods connection Activity
```

Danach sollte ein neues Feature möglichst nur noch eine neue Activity veröffentlichen müssen.

Beispiel:

```swift
let activity = BatteryActivity(...)

activityManager.publish(activity)
```

Die Notch selbst muss dadurch nicht mehr für jedes Feature separat umgebaut werden.

---

# Beispiel für den späteren Activity Flow

Situation:

- Spotify spielt Musik
- Lautstärke wird verändert
- AirPods verbinden sich
- anschließend läuft wieder Musik

```text
TIME ───────────────────────────────────────────────→


MEDIA

┌────────────────────────┐
│ 🎵  Fred again..   ▮▮  │
└────────────────────────┘

            │
            │ Volume geändert
            ▼

VOLUME

┌────────────────────────┐
│ 🔊  ███████░░   72 %   │
└────────────────────────┘

            │
            │ AirPods verbinden sich
            ▼

AIRPODS

┌────────────────────────┐
│ AirPods Pro            │
│ ✓ Verbunden            │
└────────────────────────┘

            │
            │ Activity beendet
            ▼

MEDIA

┌────────────────────────┐
│ 🎵  Fred again..   ▮▮  │
└────────────────────────┘
```

---

# Beispiel: mehrere Activities gleichzeitig

Angenommen:

```text
Media läuft
Codex erreicht 90 %
Timer endet gleichzeitig
```

Prioritäten:

```text
Media          30
Codex Alert    50
Timer End     100
```

Anzeige:

```text
1.

┌────────────────────────┐
│ ✓ Timer beendet        │
└────────────────────────┘


2.

┌────────────────────────┐
│ Codex                  │
│ ⚠ 90 % des 5h-Limits   │
└────────────────────────┘


3.

┌────────────────────────┐
│ 🎵  Fred again..   ▮▮  │
└────────────────────────┘
```

Der ActivityManager übernimmt die Reihenfolge automatisch.

---

# Design-Grundsätze

## 1. Die Notch bleibt ruhig

Keine permanent blinkenden oder wechselnden Informationen.

---

## 2. Events statt Dashboard

MiniNotch ist kein Systemmonitor.

Es zeigt:

> Was passiert gerade?

und nicht:

> Welche 20 Systemwerte existieren?

---

## 3. Compact First

Jede Activity muss zuerst in einer kleinen Darstellung funktionieren.

```text
┌──────────────────────┐
│ 🔊 ███████░ 72 %     │
└──────────────────────┘
```

Erst danach wird eine Expanded View ergänzt.

---

## 4. Temporäre Informationen verschwinden automatisch

Beispiele:

```text
Volume      → 1,5 s

Brightness  → 1,5 s

Charging    → 2,0 s

AirPods     → 2,0 s

Codex Alert → 3,0 s
```

Ausnahmen:

```text
Timer beendet
kritischer Fehler
aktive Nutzerinteraktion
```

---

## 5. Media ist der Default

Wenn Musik oder andere Medien laufen und keine wichtigere Activity aktiv ist:

```text
┌────────────────────────┐
│ 🎵 Titel          ▮▮   │
└────────────────────────┘
```

---

# Zielbild

MiniNotch soll langfristig keine Kopie von NotchNook oder Boring Notch werden.

Der Fokus liegt auf:

```text
small

native

fast

context-aware

event-driven
```

Das Produktversprechen:

> **MiniNotch zeigt genau das, was gerade wichtig ist.**

Nicht mehr.

Nicht weniger.
