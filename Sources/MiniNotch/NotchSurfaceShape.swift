import SwiftUI

/// Die Player-Fläche beginnt bündig an der oberen Bildschirmkante. Dadurch
/// verschmilzt die schwarze Hardware-Notch mit der schwarzen MiniNotch-Fläche,
/// statt wie ein separates Element über dem Player zu wirken.
struct NotchSurfaceShape: Shape {
    let bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(bottomCornerRadius, rect.height / 2, rect.width / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
