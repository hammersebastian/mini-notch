import AppKit
import SwiftUI

struct MarqueeText: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 14) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        GeometryReader { proxy in
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let textWidth = (text as NSString).size(withAttributes: [.font: font]).width

            if textWidth <= proxy.size.width {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let gap: CGFloat = 32
                    let distance = textWidth + gap
                    let offset = -(context.date.timeIntervalSinceReferenceDate * 26)
                        .truncatingRemainder(dividingBy: distance)

                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .offset(x: offset)
                }
                .clipped()
            }
        }
        .frame(height: fontSize + 4)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
