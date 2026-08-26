import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Notch-Anzeige") {
                Picker("Inhalt", selection: $model.notchContent) {
                    ForEach(NotchContent.allCases) { content in
                        Text(content.title).tag(content)
                    }
                }

                Text("Bei Codex-Limits werden das 5-Stunden- und das wöchentliche Limit in Prozent sowie die Rücksetzzeit mit Datum und Uhrzeit angezeigt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Wiedergabe") {
                Toggle("Neuen Titel kurz hervorheben", isOn: $model.showTrackChangePeek)

                Text("Beim Titelwechsel wird die Notch für ca. 2,8 Sekunden größer und zeigt den neuen Song deutlicher an.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Farben") {
                ColorPicker("Notch-Hintergrund", selection: $model.notchBackgroundColor, supportsOpacity: false)
                ColorPicker("Wave-Animation", selection: $model.waveColor, supportsOpacity: false)

                ColorPicker("Codex: Normal (bis 74 %)", selection: $model.codexUsageNormalColor, supportsOpacity: false)
                ColorPicker("Codex: Warnung (75–89 %)", selection: $model.codexUsageWarningColor, supportsOpacity: false)
                ColorPicker("Codex: Kritisch (ab 90 %)", selection: $model.codexUsageCriticalColor, supportsOpacity: false)

                Button("Farben auf Standardwerte zurücksetzen") {
                    model.resetColorsToDefaults()
                }
            }

            Section("System") {
                Toggle(
                    "Beim Anmelden starten",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }

            if let error = model.lastError {
                Section("Hinweis") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460, height: 500)
    }
}
