import AppKit
import SwiftUI

public struct MediaControllerView: View {
    @ObservedObject var viewModel: MediaViewModel

    public init(viewModel: MediaViewModel) {
        self.viewModel = viewModel
    }

    private var accentColor: Color {
        Color(nsColor: NSColor(hex: viewModel.track.accentHex) ?? .systemIndigo)
    }

    public var body: some View {
        HStack(spacing: 16) {
            // High-Resolution Album Artwork with subtle blurred glow
            ZStack {
                if let artwork = viewModel.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 96)
                        .blur(radius: 18)
                        .opacity(0.62)
                        .scaleEffect(1.08)

                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentColor.gradient)
                        .frame(width: 92, height: 92)
                }
            }
            .frame(width: 98, height: 98)

            // Track Metadata, Progress Bar, and Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(viewModel.track.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(viewModel.track.source.rawValue)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                )
                        }

                        Text("\(viewModel.track.artist) — \(viewModel.track.album)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer()

                    EqualizerWaveView(
                        levels: viewModel.equalizerLevels,
                        isPlaying: viewModel.track.isPlaying,
                        accentColor: accentColor,
                        barWidth: 3.2,
                        maxBarHeight: 20.0
                    )
                }

                // Interactive Scrubbing Progress Bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 5)

                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(6.0, geo.size.width * viewModel.track.progress),
                                    height: 5
                                )
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = min(max(value.location.x / max(1, geo.size.width), 0.0), 1.0)
                                    viewModel.seek(to: fraction)
                                }
                        )
                    }
                    .frame(height: 8)

                    HStack {
                        Text(viewModel.formattedTime(viewModel.track.elapsedTime))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))

                        Spacer()

                        Text("-\(viewModel.formattedTime(max(0, viewModel.track.duration - viewModel.track.elapsedTime)))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                // Playback Transport Controls
                HStack(spacing: 18) {
                    Button(action: { viewModel.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.track.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: accentColor.opacity(0.5), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}
