import SwiftUI

public struct NotchShape: Shape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public init(topCornerRadius: CGFloat = 10.0, bottomCornerRadius: CGFloat = 18.0) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let topR = min(topCornerRadius, rect.width / 4.0, rect.height / 2.0)
        let botR = min(bottomCornerRadius, (rect.width - topR * 2.0) / 2.0, rect.height - topR)

        var path = Path()

        // Start at top-left outer ear edge (flush with the top of the screen)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left inverse ear cutout curving down into the left vertical wall of the notch
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )

        // Left vertical edge down to bottom-left corner start
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - botR))

        // Bottom-left smooth continuous corner
        path.addCurve(
            to: CGPoint(x: rect.minX + topR + botR, y: rect.maxY),
            control1: CGPoint(x: rect.minX + topR, y: rect.maxY - botR * 0.45),
            control2: CGPoint(x: rect.minX + topR + botR * 0.45, y: rect.maxY)
        )

        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - topR - botR, y: rect.maxY))

        // Bottom-right smooth continuous corner
        path.addCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - botR),
            control1: CGPoint(x: rect.maxX - topR - botR * 0.45, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - topR, y: rect.maxY - botR * 0.45)
        )

        // Right vertical edge up to top-right inverse ear cutout
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))

        // Top-right inverse ear cutout curving out to flush menu bar top edge
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )

        // Close along top edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}
