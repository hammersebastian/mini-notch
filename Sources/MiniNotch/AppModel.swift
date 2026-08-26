import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
enum NotchPresentation: Equatable {
    case collapsed
    case trackPeek
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
}

@MainActor
final class AppModel: ObservableObject {
    @Published var media = MediaState.empty
    @Published var isHovered = false
    @Published var isPeeking = false
    @Published var physicalNotchWidth: CGFloat = 190
    @Published var physicalNotchHeight: CGFloat = 32
    @Published var lastError: String?
    @Published var systemVolume: Double = 0.5
    @Published var codexUsage = CodexUsageSnapshot.loading

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

    @Published var notchContent: NotchContent {
        didSet {
            UserDefaults.standard.set(notchContent.rawValue, forKey: "notchContent")
            if notchContent == .codexUsage {
                isPeeking = false
            }
        }
    }

    @Published var showTrackChangePeek: Bool {
        didSet {
            UserDefaults.standard.set(showTrackChangePeek, forKey: "showTrackChangePeek")
            if !showTrackChangePeek {
                isPeeking = false
            }
        }
    }

    @Published private(set) var launchAtLogin: Bool

    private var peekTask: Task<Void, Never>?

    private static let notchBackgroundColorKey = "notchBackgroundColor"
    private static let waveColorKey = "waveColor"
    private static let codexUsageNormalColorKey = "codexUsageNormalColor"
    private static let codexUsageWarningColorKey = "codexUsageWarningColor"
    private static let codexUsageCriticalColorKey = "codexUsageCriticalColor"

    private static let defaultNotchBackgroundColor = Color.black
    private static let defaultWaveColor = Color(red: 0.15, green: 0.65, blue: 0.77)
    private static let defaultCodexUsageNormalColor = Color.mint
    private static let defaultCodexUsageWarningColor = Color.orange
    private static let defaultCodexUsageCriticalColor = Color.red

    init() {
        if let stored = UserDefaults.standard.object(forKey: "showTrackChangePeek") as? Bool {
            showTrackChangePeek = stored
        } else {
            showTrackChangePeek = true
        }

        if let stored = UserDefaults.standard.string(forKey: "notchContent"),
           let content = NotchContent(rawValue: stored) {
            notchContent = content
        } else {
            notchContent = .media
        }

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
    }

    var presentation: NotchPresentation {
        if notchContent == .codexUsage {
            return isHovered ? .expanded : .collapsed
        }

        if isHovered { return .expanded }
        if isPeeking { return .trackPeek }
        return .collapsed
    }

    var shouldShowNotch: Bool {
        switch notchContent {
        case .media:
            return media.hasMedia
        case .codexUsage:
            return true
        }
    }

    func updateMedia(_ newMedia: MediaState) {
        let previous = media
        media = newMedia

        guard newMedia.hasMedia else {
            isPeeking = false
            peekTask?.cancel()
            return
        }

        let changed = previous.hasMedia && previous.trackKey != newMedia.trackKey
        if changed && showTrackChangePeek {
            triggerTrackPeek()
        }
    }

    func updateCodexUsage(_ usage: CodexUsageSnapshot) {
        codexUsage = usage
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

    private func triggerTrackPeek() {
        peekTask?.cancel()
        isPeeking = true

        peekTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            self?.isPeeking = false
        }
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
