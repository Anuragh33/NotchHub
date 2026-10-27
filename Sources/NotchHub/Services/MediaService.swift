import AppKit
import Foundation

public enum MediaPlayerSource: String, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case interactivePreview = "NotchHub Preview"
}

public struct MediaTrackState: Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var isPlaying: Bool
    public var source: MediaPlayerSource
    public var accentHex: String
    public var secondaryHex: String

    public init(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        isPlaying: Bool,
        source: MediaPlayerSource,
        accentHex: String = "#6366F1",
        secondaryHex: String = "#EC4899"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = max(1.0, duration)
        self.elapsedTime = min(max(0.0, elapsedTime), max(1.0, duration))
        self.isPlaying = isPlaying
        self.source = source
        self.accentHex = accentHex
        self.secondaryHex = secondaryHex
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsedTime / duration, 0.0), 1.0)
    }
}

@MainActor
public protocol MediaServiceProtocol: AnyObject {
    func fetchCurrentState() async -> (state: MediaTrackState, artwork: NSImage?)
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async
    func seek(to progress: Double) async
}

@MainActor
public final class HybridAppleScriptMediaService: MediaServiceProtocol {
    private var previewIndex: Int = 0
    private var previewTracks: [MediaTrackState] = [
        MediaTrackState(
            title: "Midnight Horizon",
            artist: "Kiasmos & Olafur",
            album: "Blurred Epics (Deluxe)",
            duration: 248,
            elapsedTime: 84,
            isPlaying: true,
            source: .interactivePreview,
            accentHex: "#4F46E5",
            secondaryHex: "#EC4899"
        ),
        MediaTrackState(
            title: "Veridis Quo",
            artist: "Daft Punk",
            album: "Discovery",
            duration: 345,
            elapsedTime: 42,
            isPlaying: true,
            source: .interactivePreview,
            accentHex: "#0EA5E9",
            secondaryHex: "#8B5CF6"
        ),
        MediaTrackState(
            title: "Subterranean Pulse",
            artist: "Bicep",
            album: "Isles",
            duration: 292,
            elapsedTime: 118,
            isPlaying: true,
            source: .interactivePreview,
            accentHex: "#10B981",
            secondaryHex: "#3B82F6"
        )
    ]

    private var artworkCache: [String: NSImage] = [:]

    public init() {}

    public func fetchCurrentState() async -> (state: MediaTrackState, artwork: NSImage?) {
        if let liveState = await queryRunningMediaPlayers() {
            let cacheKey = "\(liveState.source.rawValue)-\(liveState.title)-\(liveState.artist)"
            let art = artworkCache[cacheKey] ?? generateHighResArtwork(for: liveState)
            artworkCache[cacheKey] = art
            return (liveState, art)
        }

        // Advance interactive preview elapsed time if playing
        var current = previewTracks[previewIndex]
        if current.isPlaying {
            current.elapsedTime += 1.0
            if current.elapsedTime >= current.duration {
                previewIndex = (previewIndex + 1) % previewTracks.count
                current = previewTracks[previewIndex]
                current.elapsedTime = 0
            }
            previewTracks[previewIndex] = current
        }

        let cacheKey = "preview-\(current.title)"
        let art = artworkCache[cacheKey] ?? generateHighResArtwork(for: current)
        artworkCache[cacheKey] = art
        return (current, art)
    }

    public func togglePlayPause() async {
        if let activeApp = detectRunningPlayerApp() {
            let script = "tell application \"\(activeApp)\" to playpause"
            _ = await runAppleScript(script)
            return
        }
        previewTracks[previewIndex].isPlaying.toggle()
    }

    public func nextTrack() async {
        if let activeApp = detectRunningPlayerApp() {
            let script = "tell application \"\(activeApp)\" to next track"
            _ = await runAppleScript(script)
            return
        }
        let wasPlaying = previewTracks[previewIndex].isPlaying
        previewIndex = (previewIndex + 1) % previewTracks.count
        previewTracks[previewIndex].elapsedTime = 0
        previewTracks[previewIndex].isPlaying = wasPlaying
    }

    public func previousTrack() async {
        if let activeApp = detectRunningPlayerApp() {
            let script = "tell application \"\(activeApp)\" to previous track"
            _ = await runAppleScript(script)
            return
        }
        if previewTracks[previewIndex].elapsedTime > 5.0 {
            previewTracks[previewIndex].elapsedTime = 0
        } else {
            let wasPlaying = previewTracks[previewIndex].isPlaying
            previewIndex = (previewIndex - 1 + previewTracks.count) % previewTracks.count
            previewTracks[previewIndex].elapsedTime = 0
            previewTracks[previewIndex].isPlaying = wasPlaying
        }
    }

    public func seek(to progress: Double) async {
        let clamped = min(max(progress, 0.0), 1.0)
        if let activeApp = detectRunningPlayerApp() {
            let current = await fetchCurrentState().state
            let targetSeconds = current.duration * clamped
            let script = "tell application \"\(activeApp)\" to set player position to \(targetSeconds)"
            _ = await runAppleScript(script)
            return
        }
        let duration = previewTracks[previewIndex].duration
        previewTracks[previewIndex].elapsedTime = duration * clamped
    }

    // MARK: - Live AppleScript Bridge (Apple Music & Spotify)

    private func detectRunningPlayerApp() -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        let bundleIds = Set(runningApps.compactMap(\.bundleIdentifier))
        if bundleIds.contains("com.spotify.client") {
            return "Spotify"
        }
        if bundleIds.contains("com.apple.Music") {
            return "Music"
        }
        return nil
    }

    private func queryRunningMediaPlayers() async -> MediaTrackState? {
        let runningApps = NSWorkspace.shared.runningApplications
        let bundleIds = Set(runningApps.compactMap(\.bundleIdentifier))

        if bundleIds.contains("com.spotify.client") {
            let spotifyScript = """
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to (duration of current track) / 1000
                    set trackPosition to player position
                    set isPlayingState to (player state is playing)
                    return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (trackPosition as string) & "|||" & (isPlayingState as string)
                end if
            end tell
            """
            if let output = await runAppleScript(spotifyScript),
               let parsed = parseScriptOutput(output, source: .spotify) {
                return parsed
            }
        }

        if bundleIds.contains("com.apple.Music") {
            let musicScript = """
            tell application "Music"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to duration of current track
                    set trackPosition to player position
                    set isPlayingState to (player state is playing)
                    return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (trackPosition as string) & "|||" & (isPlayingState as string)
                end if
            end tell
            """
            if let output = await runAppleScript(musicScript),
               let parsed = parseScriptOutput(output, source: .appleMusic) {
                return parsed
            }
        }

        return nil
    }

    private func parseScriptOutput(_ output: String, source: MediaPlayerSource) -> MediaTrackState? {
        let parts = output.components(separatedBy: "|||")
        guard parts.count == 6 else { return nil }
        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let album = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 200.0
        let position = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let isPlaying = parts[5].lowercased().contains("true")

        return MediaTrackState(
            title: title,
            artist: artist.isEmpty ? "Unknown Artist" : artist,
            album: album,
            duration: max(1.0, duration),
            elapsedTime: max(0.0, position),
            isPlaying: isPlaying,
            source: source,
            accentHex: source == .spotify ? "#10B981" : "#F43F5E",
            secondaryHex: source == .spotify ? "#059669" : "#8B5CF6"
        )
    }

    private func runAppleScript(_ source: String) async -> String? {
        await Task.detached(priority: .utility) {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return nil }
            let descriptor = script.executeAndReturnError(&error)
            if error != nil { return nil }
            return descriptor.stringValue
        }.value
    }

    private func generateHighResArtwork(for track: MediaTrackState) -> NSImage {
        let size = NSSize(width: 240, height: 240)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let primaryColor = NSColor(hex: track.accentHex) ?? NSColor.systemIndigo
        let secondaryColor = NSColor(hex: track.secondaryHex) ?? NSColor.systemPink

        if let gradient = NSGradient(colors: [primaryColor, secondaryColor, NSColor.black]) {
            gradient.draw(in: rect, angle: 135)
        }

        // Subtle concentric vinyl/synth rings
        NSColor.white.withAlphaComponent(0.12).setStroke()
        for radius in stride(from: 36.0, through: 102.0, by: 16.0) {
            let circleRect = NSRect(
                x: size.width / 2.0 - radius,
                y: size.height / 2.0 - radius,
                width: radius * 2.0,
                height: radius * 2.0
            )
            let path = NSBezierPath(ovalIn: circleRect)
            path.lineWidth = 1.5
            path.stroke()
        }

        // Center glowing orb
        let orbRadius: CGFloat = 24.0
        let orbRect = NSRect(
            x: size.width / 2.0 - orbRadius,
            y: size.height / 2.0 - orbRadius,
            width: orbRadius * 2.0,
            height: orbRadius * 2.0
        )
        NSColor.white.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: orbRect).fill()

        image.unlockFocus()
        return image
    }
}

public extension NSColor {
    convenience init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
