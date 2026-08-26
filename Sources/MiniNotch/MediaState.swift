import AppKit
import Foundation

struct MediaState {
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

    func currentElapsedTime(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }

        let extra = isPlaying ? max(0, date.timeIntervalSince(receivedAt)) : 0
        return min(max(elapsedTime + extra, 0), duration)
    }

    func progress(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(currentElapsedTime(at: date) / duration, 0), 1)
    }
}
