import SwiftUI

struct SeekBar: View {
    let progress: Double
    let onSeek: (Double) -> Void

    @State private var dragProgress: Double?

    var body: some View {
        GeometryReader { geometry in
            let visibleProgress = dragProgress ?? progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))

                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * min(max(visibleProgress, 0), 1))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard geometry.size.width > 0 else { return }
                        dragProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                    }
                    .onEnded { value in
                        guard geometry.size.width > 0 else { return }
                        let value = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = nil
                        onSeek(value)
                    }
            )
        }
        .frame(height: 5)
    }
}
