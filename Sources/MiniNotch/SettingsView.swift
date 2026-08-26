import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let requestAccessibilityPermission: () -> Void

    var body: some View {
        Form {
            Section("Notch-Anzeige") {
                Picker(
                    "Bildschirm",
                    selection: Binding(
                        get: { model.selectedDisplayID },
                        set: { model.selectDisplay($0) }
                    )
                ) {
                    Text("Automatisch").tag(nil as UInt32?)

                    ForEach(model.displayOptions) { display in
                        Text(display.name).tag(Optional(display.id))
                    }

                    if let selectedDisplayID = model.selectedDisplayID,
                       model.isSelectedDisplayUnavailable {
                        Text("Nicht verfügbar").tag(Optional(selectedDisplayID))
                    }
                }

                Text("Automatisch verwendet den Bildschirm mit Hardware-Notch, sonst den Bildschirm unter dem Mauszeiger.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.isSelectedDisplayUnavailable {
                    Text("Der gewählte Bildschirm ist momentan nicht verbunden. Bis er wieder verfügbar ist, wird automatisch ein anderer Bildschirm verwendet.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ForEach(NotchContent.allCases) { content in
                    Toggle(
                        isOn: Binding(
                            get: { model.isNotchContentEnabled(content) },
                            set: { model.setNotchContentEnabled(content, isEnabled: $0) }
                        )
                    ) {
                        Label(content.title, systemImage: content.symbol)
                    }
                }

                Text("Aktive Inhalte stehen in der aufgeklappten Notch zur Auswahl. Bei nur einem aktiven Inhalt wird die Auswahlleiste ausgeblendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.enabledNotchContents.isEmpty {
                    Text("Es ist kein Inhalt aktiv. Die Notch zeigt einen Hinweis an.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Automatisches Ausblenden") {
                if model.hasAccessibilityPermission {
                    Label(
                        "Bei Überschneidung mit dem aktiven Fenster ausblenden",
                        systemImage: "checkmark.shield"
                    )
                    .foregroundStyle(.green)
                } else {
                    Text("Damit MiniNotch Fensterüberschneidungen erkennen kann, erlaube MiniNotch unter Bedienungshilfen den Zugriff.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Zugriff anfordern") {
                        requestAccessibilityPermission()
                    }

                    Text("Falls MiniNotch bereits erlaubt ist: Bitte die Freigabe für die gerade gestartete MiniNotch-App bestätigen. Entwicklungs- und installierte Versionen können getrennte Einträge haben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
