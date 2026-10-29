import AppKit
import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var mediaService: MediaService = .shared

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            if mediaService.currentTrack.hasTrack {
                activeTrackContent(track: mediaService.currentTrack)
            } else {
                emptyStateContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func activeTrackContent(track: NowPlayingTrack) -> some View {
        HStack(spacing: 16) {
            // Album Artwork
            ZStack {
                if let data = track.artworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    )
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

            // Track Meta, Progress, and Controls
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(track.artist.isEmpty ? (track.album.isEmpty ? "Now Playing" : track.album) : track.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Mini Sound Wave
                    HStack(spacing: 2.5) {
                        ForEach(0..<mediaService.simulatedAudioLevels.count, id: \.self) { idx in
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.green.opacity(0.8), Color.mint],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                                .frame(width: 3, height: max(4.0, mediaService.simulatedAudioLevels[idx] * 20.0))
                                .animation(.spring(response: 0.18, dampingFraction: 0.6), value: mediaService.simulatedAudioLevels[idx])
                        }
                    }
                    .frame(height: 22)
                }

                // Progress Bar
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)

                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.white, .white.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(0, geo.size.width * CGFloat(track.progress)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(track.formattedElapsed)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        Text(track.formattedDuration)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Controls
                HStack(spacing: 22) {
                    Spacer()

                    Button {
                        mediaService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        mediaService.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .white.opacity(0.3), radius: 6)

                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .offset(x: track.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        mediaService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var emptyStateContent: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("No Media Playing")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Play audio in Spotify, Apple Music, or Safari to control it from the notch")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(URL(string: "music://")!)
                } label: {
                    Label("Music", systemImage: "play.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    NSWorkspace.shared.open(URL(string: "spotify://")!)
                } label: {
                    Label("Spotify", systemImage: "play.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(20)
    }
}
