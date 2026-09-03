import AppKit
import Foundation

struct MediaState {
    private static let timelineDisplayDelay: TimeInterval = 1

    var bundleIdentifier: String = ""
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var isPlaying: Bool = false
    var duration: Double = 0
    var elapsedTime: Double = 0
    var artwork: NSImage?
    var receivedAt: Date = Date()

    static let empty = MediaState()

    var hasMedia: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trackKey: String {
        [bundleIdentifier, title, artist, album].joined(separator: "|")
    }

    var hasTimeline: Bool {
        duration.isFinite && duration > 0
    }

    func currentElapsedTime(at date: Date = Date()) -> Double {
        guard hasTimeline else { return 0 }

        let extra = isPlaying ? max(0, date.timeIntervalSince(receivedAt)) : 0
        return min(max(elapsedTime + extra, 0), duration)
    }

    /// Source-Player wie Spotify stellen die letzte vollständig vergangene
    /// Sekunde dar. Der kleine Anzeigeversatz hält unsere Timeline mit dieser
    /// Ganzsekundenanzeige synchron, ohne die interne Medienposition zu ändern.
    func displayedElapsedTime(at date: Date = Date()) -> Double {
        let currentElapsedTime = currentElapsedTime(at: date)
        guard currentElapsedTime < duration else { return duration }
        return max(currentElapsedTime - Self.timelineDisplayDelay, 0)
    }

    func progress(at date: Date = Date()) -> Double {
        guard hasTimeline else { return 0 }
        return min(max(displayedElapsedTime(at: date) / duration, 0), 1)
    }

    func elapsedTimeText(at date: Date = Date()) -> String {
        guard hasTimeline else { return "--:--" }
        return Self.playbackTimeText(displayedElapsedTime(at: date))
    }

    var durationText: String {
        guard hasTimeline else { return "--:--" }
        return Self.playbackTimeText(duration)
    }

    func timelineAccessibilityText(at date: Date = Date()) -> String {
        guard hasTimeline else { return "Zeitangaben nicht verfügbar" }
        return "\(elapsedTimeText(at: date)) von \(durationText)"
    }

    static func playbackTimeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }

        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
