import Foundation

struct VolumeActivity: NotchActivity, Equatable {
    static let activityID = "system.volume"
    static let displayDuration: TimeInterval = 1.5

    let normalizedVolume: Double
    let isMuted: Bool

    init(normalizedVolume: Double, isMuted: Bool = false) {
        self.normalizedVolume = min(max(normalizedVolume, 0), 1)
        self.isMuted = isMuted
    }

    var percentage: Int {
        Int((normalizedVolume * 100).rounded())
    }

    var percentageText: String {
        "\(percentage) %"
    }

    var displayText: String {
        isMuted ? "Stumm" : percentageText
    }

    var id: String { Self.activityID }

    var priority: Int { ActivityPriority.systemHUD }

    var autoDismissAfter: TimeInterval? { Self.displayDuration }

    var isActive: Bool { true }
}
