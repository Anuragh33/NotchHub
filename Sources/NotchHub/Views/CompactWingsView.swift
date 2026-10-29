import AppKit
import SwiftUI

public struct CompactWingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    let hardwareNotchWidth: CGFloat

    public init(viewModel: NotchViewModel, hardwareNotchWidth: CGFloat) {
        self.viewModel = viewModel
        self.hardwareNotchWidth = hardwareNotchWidth
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let banner = viewModel.activeBanner {
                bannerLeftWing(banner: banner)
                Spacer(minLength: hardwareNotchWidth)
                bannerRightWing(banner: banner)
            } else if viewModel.mediaService.currentTrack.isPlaying {
                mediaLeftWing
                Spacer(minLength: hardwareNotchWidth)
                mediaRightWing
            } else {
                defaultLeftWing
                Spacer(minLength: hardwareNotchWidth)
                defaultRightWing
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.activeBanner)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.mediaService.currentTrack.isPlaying)
    }

    // MARK: - Banner Wing Views (HUD Popups)
    private func bannerLeftWing(banner: NotchBanner) -> some View {
        HStack(spacing: 5) {
            Image(systemName: banner.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accentColor(for: banner.accentColorName))

            Text(banner.title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 11)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private func bannerRightWing(banner: NotchBanner) -> some View {
        HStack(spacing: 4) {
            Text(banner.subtitle)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 11)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    // MARK: - Now Playing Wing Views
    private var mediaLeftWing: some View {
        HStack(spacing: 5) {
            // Mini animated audio equalizer waveform bars
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { idx in
                    Capsule()
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 2.2, height: max(3.0, viewModel.mediaService.simulatedAudioLevels[idx] * 12.0))
                        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: viewModel.mediaService.simulatedAudioLevels[idx])
                }
            }
            .frame(width: 14, height: 14)

            Text(viewModel.mediaService.currentTrack.title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 11)
    }

    private var mediaRightWing: some View {
        HStack(spacing: 4) {
            Text(viewModel.mediaService.currentTrack.artist.isEmpty ? viewModel.mediaService.currentTrack.formattedElapsed : viewModel.mediaService.currentTrack.artist)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)

            Image(systemName: "music.note")
                .font(.system(size: 9))
                .foregroundColor(.green.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 11)
    }

    // MARK: - Default Wing Views (Pomodoro & AI / Battery)
    private var defaultLeftWing: some View {
        let timerAccent = viewModel.utilitiesViewModel.currentPhase.accentColor

        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2.2)
                    .frame(width: 15, height: 15)

                Circle()
                    .trim(from: 0.0, to: CGFloat(viewModel.utilitiesViewModel.remainingFraction))
                    .stroke(
                        timerAccent,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 15, height: 15)
            }

            Text(viewModel.utilitiesViewModel.formattedTimer)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.utilitiesViewModel.isTimerRunning ? timerAccent : .white.opacity(0.88))
                .contentTransition(.numericText(countsDown: true))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 11)
    }

    private var defaultRightWing: some View {
        let battery = viewModel.batteryService.currentState

        return HStack(spacing: 6) {
            // AI Quota
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.cyan)

                Text("\(viewModel.aiUsageViewModel.averageRemainingPercentInt)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Mini Battery Indicator
            HStack(spacing: 2.5) {
                Image(systemName: battery.batterySymbol)
                    .font(.system(size: 9.5))
                    .foregroundColor(battery.isCharging ? .green : (battery.percentage <= 20 ? .red : .white.opacity(0.8)))

                Text("\(battery.percentage)%")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 11)
    }

    private func accentColor(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "red": return .red
        default: return .green
        }
    }
}
