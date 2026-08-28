import SwiftUI

/// Zeichnet die MiniNotch-Fläche. Für die aufgeklappte Darstellung kann die
/// obere Kante in die Hardware-Notch übergehen, ohne die übrige Menüleiste zu
/// übermalen.
struct NotchSurfaceShape: Shape {
    let bottomCornerRadius: CGFloat
    let topNotchWidth: CGFloat
    let topNotchHeight: CGFloat
    let topNotchTransitionRadius: CGFloat
    var expansionProgress: CGFloat

    init(
        bottomCornerRadius: CGFloat,
        topNotchWidth: CGFloat,
        topNotchHeight: CGFloat = 0,
        topNotchTransitionRadius: CGFloat = 0,
        expansionProgress: CGFloat = 0
    ) {
        self.bottomCornerRadius = bottomCornerRadius
        self.topNotchWidth = topNotchWidth
        self.topNotchHeight = topNotchHeight
        self.topNotchTransitionRadius = topNotchTransitionRadius
        self.expansionProgress = expansionProgress
    }

    var animatableData: CGFloat {
        get { expansionProgress }
        set { expansionProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(expansionProgress, 0), 1)
        let bottomRadius = min(bottomCornerRadius, rect.height / 2, rect.width / 2)

        // Im kompakten Endzustand verwenden wir die Systemform direkt. Das
        // garantiert eine sauber gerundete Unterkante, auch nachdem der
        // umgebende NSPanel-Rahmen selbst animiert wurde.
        if progress == 0 {
            return UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .path(in: rect)
        }

        let expandedNotchWidth = min(max(topNotchWidth, 0), rect.width)
        let notchWidth = rect.width + (expandedNotchWidth - rect.width) * progress
        let notchHeight = min(topNotchHeight * progress, rect.height)
        let notchLeft = rect.midX - notchWidth / 2
        let notchRight = rect.midX + notchWidth / 2
        let availableSideWidth = (rect.width - expandedNotchWidth) / 2
        let expandedTransitionRadius = min(
            topNotchTransitionRadius,
            topNotchHeight,
            expandedNotchWidth / 2,
            availableSideWidth
        )
        let notchTransitionRadius = expandedTransitionRadius * progress
        let containerTopY = notchHeight + notchTransitionRadius
        let topOuterCornerRadius = min(
            bottomCornerRadius,
            (rect.height - containerTopY) / 2,
            rect.width / 2
        ) * progress
        var path = Path()
        path.move(to: CGPoint(x: notchLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: notchRight, y: rect.minY))
        path.addLine(to: CGPoint(x: notchRight, y: notchHeight))
        path.addQuadCurve(
            to: CGPoint(x: notchRight + notchTransitionRadius, y: containerTopY),
            control: CGPoint(x: notchRight, y: containerTopY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topOuterCornerRadius, y: containerTopY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: containerTopY + topOuterCornerRadius),
            control: CGPoint(x: rect.maxX, y: containerTopY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: containerTopY + topOuterCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topOuterCornerRadius, y: containerTopY),
            control: CGPoint(x: rect.minX, y: containerTopY)
        )
        path.addLine(to: CGPoint(x: notchLeft - notchTransitionRadius, y: containerTopY))
        path.addQuadCurve(
            to: CGPoint(x: notchLeft, y: notchHeight),
            control: CGPoint(x: notchLeft, y: containerTopY)
        )
        path.addLine(to: CGPoint(x: notchLeft, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
