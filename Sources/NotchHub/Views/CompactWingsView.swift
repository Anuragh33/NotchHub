import AppKit
import SwiftUI

public struct CompactWingsView: View {
    @ObservedObject var mediaViewModel: MediaViewModel
    @ObservedObject var utilitiesViewModel: UtilitiesViewModel
    let hardwareNotchWidth: CGFloat

    public init(
        mediaViewModel: MediaViewModel,
        utilitiesViewModel: UtilitiesViewModel,
        hardwareNotchWidth: CGFloat
    ) {
        self.mediaViewModel = mediaViewModel
        self.utilitiesViewModel = utilitiesViewModel
        self.hardwareNotchWidth = hardwareNotchWidth
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left Wing: Miniature Album Artwork + Playback Indicator
            HStack(spacing: 6) {
                if let artwork = mediaViewModel.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.indigo.gradient)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }

                Text(mediaViewModel.track.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .frame(maxWidth: 42, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)

            // Center Spacer matching the exact physical camera cutout width
            Spacer(minLength: hardwareNotchWidth)

            // Right Wing: Active Pomodoro Timer or Animated Audio Equalizer Waveform
            HStack(spacing: 6) {
                if utilitiesViewModel.isTimerRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text(utilitiesViewModel.formattedTimer)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.orange)
                    }
                } else {
                    EqualizerWaveView(
                        levels: mediaViewModel.equalizerLevels,
                        isPlaying: mediaViewModel.track.isPlaying,
                        accentColor: Color(nsColor: NSColor(hex: mediaViewModel.track.accentHex) ?? .systemIndigo),
                        barWidth: 2.5,
                        maxBarHeight: 14.0
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(maxHeight: .infinity)
    }
}
