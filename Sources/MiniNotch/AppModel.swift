import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
enum NotchPresentation: Equatable {
    case collapsed
    case expanded
}

enum NotchContent: String, CaseIterable, Identifiable {
    case media
    case codexUsage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media:
            return "Medien"
        case .codexUsage:
            return "Codex-Limits"
        }
    }

    var symbol: String {
        switch self {
        case .media:
            return "music.note"
        case .codexUsage:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension NotchContent: NotchActivity {
    /// Media und die bestehende Codex-Ansicht sind gleichrangige, manuell
    /// wechselbare Basisinhalte. Spätere Warnungen werden eigene Activities.
    var priority: Int { ActivityPriority.persistentContent }

    var autoDismissAfter: TimeInterval? { nil }

    var isActive: Bool { true }
}

struct DisplayOption: Identifiable, Hashable {
    let id: UInt32
    let name: String
}

@MainActor
final class AppModel: ObservableObject {
    let activityManager: ActivityManager

    @Published var media = MediaState.empty
    @Published var isHovered = false
    @Published var isCoveredByFrontmostWindow = false
    @Published var hasAccessibilityPermission = false
    @Published var physicalNotchWidth: CGFloat = 190
    @Published var physicalNotchHeight: CGFloat = 32
    @Published var lastError: String?
    @Published var codexUsage = CodexUsageSnapshot.loading
    @Published private(set) var displayOptions: [DisplayOption]

    @Published var selectedDisplayID: UInt32? {
        didSet {
            if let selectedDisplayID {
                UserDefaults.standard.set(Int(selectedDisplayID), forKey: Self.selectedDisplayIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.selectedDisplayIDKey)
            }
        }
    }

    @Published var notchBackgroundColor: Color {
        didSet {
            storeColor(notchBackgroundColor, forKey: Self.notchBackgroundColorKey)
        }
    }

    @Published var waveColor: Color {
        didSet {
            storeColor(waveColor, forKey: Self.waveColorKey)
        }
    }

    @Published var codexUsageNormalColor: Color {
        didSet {
            storeColor(codexUsageNormalColor, forKey: Self.codexUsageNormalColorKey)
        }
    }

    @Published var codexUsageWarningColor: Color {
        didSet {
            storeColor(codexUsageWarningColor, forKey: Self.codexUsageWarningColorKey)
        }
    }

    @Published var codexUsageCriticalColor: Color {
        didSet {
            storeColor(codexUsageCriticalColor, forKey: Self.codexUsageCriticalColorKey)
        }
    }

    /// Gespeichert werden nur deaktivierte Inhalte. Dadurch sind spätere neue
    /// Inhaltsarten ohne Migration automatisch verfügbar.
    @Published private(set) var disabledNotchContents: Set<NotchContent> {
        didSet {
            UserDefaults.standard.set(
                disabledNotchContents.map(\.rawValue),
                forKey: Self.disabledNotchContentsKey
            )
        }
    }

    @Published private(set) var launchAtLogin: Bool

    private var keepsEmptyMediaViewVisible = false
    private var activityManagerCancellables = Set<AnyCancellable>()

    private static let notchBackgroundColorKey = "notchBackgroundColor"
    private static let waveColorKey = "waveColor"
    private static let codexUsageNormalColorKey = "codexUsageNormalColor"
    private static let codexUsageWarningColorKey = "codexUsageWarningColor"
    private static let codexUsageCriticalColorKey = "codexUsageCriticalColor"
    private static let selectedDisplayIDKey = "selectedDisplayID"
    private static let notchContentKey = "notchContent"
    private static let disabledNotchContentsKey = "disabledNotchContents"

    private static let defaultNotchBackgroundColor = Color.black
    private static let defaultWaveColor = Color(red: 0.15, green: 0.65, blue: 0.77)
    private static let defaultCodexUsageNormalColor = Color.mint
    private static let defaultCodexUsageWarningColor = Color.orange
    private static let defaultCodexUsageCriticalColor = Color.red

    init() {
        let disabledContents = Set(
            (UserDefaults.standard.stringArray(forKey: Self.disabledNotchContentsKey) ?? [])
                .compactMap(NotchContent.init(rawValue:))
        )
        let storedContent = UserDefaults.standard.string(forKey: Self.notchContentKey)
            .flatMap(NotchContent.init(rawValue:))
        let initialContent = storedContent.flatMap { content in
            disabledContents.contains(content) ? nil : content
        } ?? NotchContent.allCases.first { !disabledContents.contains($0) }

        displayOptions = Self.currentDisplayOptions()
        selectedDisplayID = (UserDefaults.standard.object(forKey: Self.selectedDisplayIDKey) as? NSNumber)?.uint32Value
        disabledNotchContents = disabledContents

        activityManager = ActivityManager(
            activities: NotchContent.allCases.filter { !disabledContents.contains($0) },
            selectedActivityID: initialContent?.id
        )

        notchBackgroundColor = Self.storedColor(
            forKey: Self.notchBackgroundColorKey,
            default: Self.defaultNotchBackgroundColor
        )
        waveColor = Self.storedColor(
            forKey: Self.waveColorKey,
            default: Self.defaultWaveColor
        )
        codexUsageNormalColor = Self.storedColor(
            forKey: Self.codexUsageNormalColorKey,
            default: Self.defaultCodexUsageNormalColor
        )
        codexUsageWarningColor = Self.storedColor(
            forKey: Self.codexUsageWarningColorKey,
            default: Self.defaultCodexUsageWarningColor
        )
        codexUsageCriticalColor = Self.storedColor(
            forKey: Self.codexUsageCriticalColorKey,
            default: Self.defaultCodexUsageCriticalColor
        )

        launchAtLogin = SMAppService.mainApp.status == .enabled

        activityManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &activityManagerCancellables)

        activityManager.$currentActivityID
            .dropFirst()
            .sink { activityID in
                if let activityID {
                    UserDefaults.standard.set(activityID, forKey: Self.notchContentKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.notchContentKey)
                }
            }
            .store(in: &activityManagerCancellables)
    }

    var notchContent: NotchContent? {
        activityManager.currentActivityID.flatMap(NotchContent.init(rawValue:))
    }

    var presentation: NotchPresentation {
        // Temporäre Compact-Activities öffnen keine inhaltlich fremde
        // Media-/Codex-Ansicht. Der bestehende Hover-Zustand bleibt erhalten
        // und greift wieder, sobald eine Basis-Activity sichtbar ist.
        if activityManager.currentActivity is VolumeActivity {
            return .collapsed
        }

        return isHovered ? .expanded : .collapsed
    }

    var shouldShowNotch: Bool {
        guard !isCoveredByFrontmostWindow else { return false }
        return true
    }

    func updateMedia(_ newMedia: MediaState) {
        media = newMedia

        if newMedia.hasMedia {
            keepsEmptyMediaViewVisible = false
            if isNotchContentEnabled(.media) {
                activityManager.publish(NotchContent.media)
            }
        } else if !keepsEmptyMediaViewVisible {
            // Ohne laufende Wiedergabe ist Media keine verfügbare Activity.
            // Eine ausdrücklich gewählte leere Medienansicht bleibt wie bisher
            // erreichbar, bis ein anderer Inhalt ausgewählt wird.
            activityManager.removeActivity(withID: NotchContent.media.id)
        }
    }

    func updateCodexUsage(_ usage: CodexUsageSnapshot) {
        codexUsage = usage
    }

    func updateSystemVolume(
        _ normalizedVolume: Double,
        isMuted: Bool = false,
        presentsActivity: Bool
    ) {
        let activity = VolumeActivity(
            normalizedVolume: normalizedVolume,
            isMuted: isMuted
        )
        if presentsActivity {
            activityManager.publish(activity)
        }
    }

    func selectDisplay(_ displayID: UInt32?) {
        selectedDisplayID = displayID
    }

    func refreshDisplayOptions() {
        displayOptions = Self.currentDisplayOptions()
    }

    func selectedScreen() -> NSScreen? {
        guard let selectedDisplayID else { return nil }

        return NSScreen.screens.first { Self.displayID(for: $0) == selectedDisplayID }
    }

    var isSelectedDisplayUnavailable: Bool {
        selectedDisplayID != nil && selectedScreen() == nil
    }

    var enabledNotchContents: [NotchContent] {
        NotchContent.allCases.filter { !disabledNotchContents.contains($0) }
    }

    func isNotchContentEnabled(_ content: NotchContent) -> Bool {
        !disabledNotchContents.contains(content)
    }

    func setNotchContentEnabled(_ content: NotchContent, isEnabled: Bool) {
        guard isNotchContentEnabled(content) != isEnabled else { return }

        if isEnabled {
            disabledNotchContents.remove(content)
            if notchContent == nil {
                selectNotchContent(content)
            } else if content != .media || media.hasMedia {
                activityManager.publish(content)
            }
        } else {
            let wasSelected = notchContent == content
            disabledNotchContents.insert(content)
            activityManager.removeActivity(withID: content.id)

            if wasSelected {
                keepsEmptyMediaViewVisible = false
                if let nextContent = enabledNotchContents.first {
                    activityManager.publish(nextContent)
                    activityManager.selectActivity(withID: nextContent.id)
                }
            }
        }
    }

    /// Eine explizite Auswahl darf die leere Medienansicht anzeigen. So kann
    /// der Tab jederzeit erreichbar bleiben, obwohl gerade nichts läuft.
    func selectNotchContent(_ content: NotchContent) {
        guard isNotchContentEnabled(content) else { return }

        activityManager.publish(content)
        activityManager.selectActivity(withID: content.id)
        keepsEmptyMediaViewVisible = content == .media && !media.hasMedia

        if content != .media && !media.hasMedia {
            activityManager.removeActivity(withID: NotchContent.media.id)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }

            launchAtLogin = SMAppService.mainApp.status == .enabled
            lastError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            lastError = "Autostart konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }

    func resetColorsToDefaults() {
        notchBackgroundColor = Self.defaultNotchBackgroundColor
        waveColor = Self.defaultWaveColor
        codexUsageNormalColor = Self.defaultCodexUsageNormalColor
        codexUsageWarningColor = Self.defaultCodexUsageWarningColor
        codexUsageCriticalColor = Self.defaultCodexUsageCriticalColor
    }

    private static func storedColor(forKey key: String, default defaultColor: Color) -> Color {
        guard let hex = UserDefaults.standard.string(forKey: key),
              let color = Color(hex: hex) else {
            return defaultColor
        }
        return color
    }

    private func storeColor(_ color: Color, forKey key: String) {
        UserDefaults.standard.set(color.hexString, forKey: key)
    }

    private static func currentDisplayOptions() -> [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = displayID(for: screen) else { return nil }

            let mainScreenSuffix = screen == NSScreen.main ? " (Hauptbildschirm)" : ""
            return DisplayOption(id: displayID, name: screen.localizedName + mainScreenSuffix)
        }
    }

    private static func displayID(for screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private extension Color {
    init?(hex: String) {
        let normalizedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedHex.count == 7,
              normalizedHex.first == "#",
              let value = UInt32(normalizedHex.dropFirst(), radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(
            format: "#%02X%02X%02X",
            Int((nsColor.redComponent * 255).rounded()),
            Int((nsColor.greenComponent * 255).rounded()),
            Int((nsColor.blueComponent * 255).rounded())
        )
    }
}
