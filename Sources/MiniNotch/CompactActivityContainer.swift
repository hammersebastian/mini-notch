import SwiftUI

/// Gemeinsame äußere Layout-Hülle für kompakte Activity-Inhalte.
///
/// Der Container reserviert den Bereich der Hardware-Notch und füllt die
/// verbleibende kompakte Fläche. Inhaltsspezifisches Layout wie Padding,
/// Typografie und Bedienelemente bleibt bei der jeweiligen Activity-View.
struct CompactActivityContainer<Content: View>: View {
    let topInset: CGFloat
    private let content: Content

    init(
        topInset: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.topInset = topInset
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: topInset)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
