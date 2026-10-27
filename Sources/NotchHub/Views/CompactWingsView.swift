import AppKit
import SwiftUI

public struct CompactWingsView: View {
    @ObservedObject var aiUsageViewModel: AIUsageViewModel
    @ObservedObject var utilitiesViewModel: UtilitiesViewModel
    let hardwareNotchWidth: CGFloat

    public init(
        aiUsageViewModel: AIUsageViewModel,
        utilitiesViewModel: UtilitiesViewModel,
        hardwareNotchWidth: CGFloat
    ) {
        self.aiUsageViewModel = aiUsageViewModel
        self.utilitiesViewModel = utilitiesViewModel
        self.hardwareNotchWidth = hardwareNotchWidth
    }

    public var body: some View {
        let timerAccent = utilitiesViewModel.currentPhase.accentColor

        HStack(spacing: 0) {
            // Left Wing: Animated Mini Pomodoro Progress Ring & Countdown
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 2.2)
                        .frame(width: 15, height: 15)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(utilitiesViewModel.remainingFraction))
                        .stroke(
                            timerAccent,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 15, height: 15)
                }

                Text(utilitiesViewModel.formattedTimer)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(utilitiesViewModel.isTimerRunning ? timerAccent : .white.opacity(0.88))
                    .contentTransition(.numericText(countsDown: true))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 11)

            // Center Spacer matching the exact physical camera cutout width
            Spacer(minLength: hardwareNotchWidth)

            // Right Wing: Live Synced AI Quota Percentage & Connected Account Indicator
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.cyan)

                Text("\(aiUsageViewModel.averageRemainingPercentInt)%")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Circle()
                    .fill(aiUsageViewModel.authenticatedCount > 0 ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 11)
        }
        .frame(maxHeight: .infinity)
    }
}
