import AppKit
import Combine
import SwiftUI

@MainActor
public final class MediaViewModel: ObservableObject {
    @Published public private(set) var track: MediaTrackState
    @Published public private(set) var artwork: NSImage?
    @Published public private(set) var equalizerLevels: [CGFloat] = [0.35, 0.7, 0.5, 0.9, 0.4, 0.75]

    private let mediaService: MediaServiceProtocol
    private var refreshTimer: Timer?
    private var equalizerTimer: Timer?
    private var wavePhase: Double = 0.0

    public init(mediaService: MediaServiceProtocol = HybridAppleScriptMediaService()) {
        self.mediaService = mediaService
        self.track = MediaTrackState(
            title: "Midnight Horizon",
            artist: "Kiasmos & Olafur",
            album: "Blurred Epics (Deluxe)",
            duration: 248,
            elapsedTime: 84,
            isPlaying: true,
            source: .interactivePreview
        )
        startTimers()
        Task {
            await refreshNowPlaying()
        }
    }

    public func refreshNowPlaying() async {
        let result = await mediaService.fetchCurrentState()
        self.track = result.state
        self.artwork = result.artwork
    }

    public func togglePlayPause() {
        Task {
            await mediaService.togglePlayPause()
            await refreshNowPlaying()
        }
    }

    public func nextTrack() {
        Task {
            await mediaService.nextTrack()
            await refreshNowPlaying()
        }
    }

    public func previousTrack() {
        Task {
            await mediaService.previousTrack()
            await refreshNowPlaying()
        }
    }

    public func seek(to progress: Double) {
        Task {
            await mediaService.seek(to: progress)
            await refreshNowPlaying()
        }
    }

    public func formattedTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startTimers() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshNowPlaying()
            }
        }

        equalizerTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.track.isPlaying {
                    self.wavePhase += 0.48
                    self.equalizerLevels = (0..<6).map { index in
                        let offset = Double(index) * 0.85
                        let primary = abs(sin(self.wavePhase + offset))
                        let harmonic = abs(cos(self.wavePhase * 1.35 - offset * 0.6)) * 0.45
                        return CGFloat(min(max(0.2 + (primary * 0.6 + harmonic * 0.35), 0.18), 1.0))
                    }
                } else {
                    self.equalizerLevels = Array(repeating: 0.18, count: 6)
                }
            }
        }
    }
}
