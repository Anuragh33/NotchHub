import SwiftUI

public struct EqualizerWaveView: View {
    public let levels: [CGFloat]
    public let isPlaying: Bool
    public var accentColor: Color = .indigo
    public var barWidth: CGFloat = 3.0
    public var maxBarHeight: CGFloat = 16.0

    public init(
        levels: [CGFloat],
        isPlaying: Bool,
        accentColor: Color = .indigo,
        barWidth: CGFloat = 3.0,
        maxBarHeight: CGFloat = 16.0
    ) {
        self.levels = levels
        self.isPlaying = isPlaying
        self.accentColor = accentColor
        self.barWidth = barWidth
        self.maxBarHeight = maxBarHeight
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: barWidth,
                        height: max(3.0, (isPlaying ? level : 0.2) * maxBarHeight)
                    )
                    .animation(
                        .easeInOut(duration: 0.14).delay(Double(index) * 0.015),
                        value: level
                    )
            }
        }
        .frame(height: maxBarHeight)
    }
}
