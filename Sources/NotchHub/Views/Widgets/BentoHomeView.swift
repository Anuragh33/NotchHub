import AppKit
import SwiftUI

public struct BentoHomeView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var aiViewModel: AIUsageViewModel
    @ObservedObject var timerViewModel: UtilitiesViewModel
    @ObservedObject var shelfViewModel: ShelfViewModel
    @ObservedObject var clipboardViewModel: ClipboardViewModel

    public init(notchViewModel: NotchViewModel) {
        self.notchViewModel = notchViewModel
        self.aiViewModel = notchViewModel.aiUsageViewModel
        self.timerViewModel = notchViewModel.utilitiesViewModel
        self.shelfViewModel = notchViewModel.shelfViewModel
        self.clipboardViewModel = notchViewModel.clipboardViewModel
    }

    public var body: some View {
        let timerAccent = timerViewModel.currentPhase.accentColor

        HStack(spacing: 10) {
            // Bento Card 1: Synced AI Quotas Matrix
            Button(action: {
                withAnimation(NotchViewModel.springAnimation) {
                    notchViewModel.selectedTab = .aiUsage
                }
            }) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text("AI Quotas")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text("\(aiViewModel.averageRemainingPercentInt)%")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }

                    VStack(spacing: 4) {
                        ForEach(aiViewModel.providers.prefix(4)) { item in
                            let color = Color(nsColor: NSColor(hex: item.provider.accentHex) ?? .systemBlue)
                            HStack(spacing: 6) {
                                Text(item.provider.rawValue)
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 52, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(height: 4)
                                        Capsule(style: .continuous)
                                            .fill(item.needsSignIn ? Color.orange : color)
                                            .frame(
                                                width: max(4.0, geo.size.width * (item.needsSignIn ? 0.2 : item.remainingPercent)),
                                                height: 4
                                            )
                                    }
                                }
                                .frame(height: 4)

                                Text(item.needsSignIn ? "Auth" : "\(item.remainingPercentInt)%")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(item.needsSignIn ? .orange : .white.opacity(0.75))
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.09), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.13), lineWidth: 0.8)
                        )
                )
            }
            .buttonStyle(.plain)

            // Bento Card 2: Interactive Animated Pomodoro Focus Tile
            VStack(spacing: 6) {
                HStack {
                    Text(timerViewModel.currentPhase.rawValue)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(timerAccent)
                    Spacer()
                    Button(action: {
                        withAnimation(NotchViewModel.springAnimation) {
                            notchViewModel.selectedTab = .timer
                        }
                    }) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 54, height: 54)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(timerViewModel.remainingFraction))
                        .stroke(
                            timerAccent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)

                    Button(action: { timerViewModel.toggleTimer() }) {
                        VStack(spacing: 1) {
                            Image(systemName: timerViewModel.isTimerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(timerAccent)
                            Text(timerViewModel.formattedTimer)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(11)
            .frame(width: 128)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [timerAccent.opacity(0.16), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(timerAccent.opacity(0.32), lineWidth: 0.8)
                    )
            )

            // Bento Card 3: Stacked Media / Shelf + Clipboard Quick Tiles
            VStack(spacing: 8) {
                if notchViewModel.mediaService.currentTrack.isPlaying {
                    // Top Mini Tile: Now Playing Music
                    Button(action: {
                        withAnimation(NotchViewModel.springAnimation) {
                            notchViewModel.selectTab(.media)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.green)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.green.opacity(0.18)))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(notchViewModel.mediaService.currentTrack.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(notchViewModel.mediaService.currentTrack.artist.isEmpty ? "Now Playing" : notchViewModel.mediaService.currentTrack.artist)
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.green.opacity(0.25), lineWidth: 0.7)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    // Top Mini Tile: Drop Shelf
                    Button(action: {
                        withAnimation(NotchViewModel.springAnimation) {
                            notchViewModel.selectTab(.shelf)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.cyan.opacity(0.16)))

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Drop Shelf")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(shelfViewModel.items.count) held items")
                                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Bottom Mini Tile: Clipboard History
                Button(action: {
                    withAnimation(NotchViewModel.springAnimation) {
                        notchViewModel.selectTab(.clipboard)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.purple)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.purple.opacity(0.18)))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Clipboard")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(clipboardViewModel.entries.first?.previewText ?? "\(clipboardViewModel.entries.count) clips saved")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 158)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}
