import SwiftUI

struct EqualizerView: View {
    let playing: Bool
    let compact: Bool
    let color: Color

    init(playing: Bool, compact: Bool = false, color: Color) {
        self.playing = playing
        self.compact = compact
        self.color = color
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !playing)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: compact ? 2 : 3) {
                ForEach(0..<6, id: \.self) { index in
                    let phase = time * 2.6 + Double(index) * 0.82
                    let height = playing
                        ? (compact ? 4 + abs(sin(phase)) * 10 : 7 + abs(sin(phase)) * 15)
                        : (compact ? 4 : 5)

                    Capsule()
                        .fill(color)
                        .frame(width: compact ? 2.5 : 3.5, height: height)
                }
            }
            .frame(width: compact ? 28 : 38, height: compact ? 18 : 28)
        }
    }
}
