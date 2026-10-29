import AppKit
import Combine
import Foundation

public struct NowPlayingTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public let elapsedTime: TimeInterval
    public let isPlaying: Bool
    public let playbackRate: Double
    public let artworkData: Data?
    public let bundleIdentifier: String?

    public static let empty = NowPlayingTrack(
        title: "",
        artist: "",
        album: "",
        duration: 0,
        elapsedTime: 0,
        isPlaying: false,
        playbackRate: 0,
        artworkData: nil,
        bundleIdentifier: nil
    )

    public var hasTrack: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsedTime / duration, 0.0), 1.0)
    }

    public var formattedElapsed: String {
        formatTime(elapsedTime)
    }

    public var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

@MainActor
public final class MediaService: ObservableObject {
    public static let shared = MediaService()

    @Published public private(set) var currentTrack: NowPlayingTrack = .empty
    @Published public private(set) var simulatedAudioLevels: [CGFloat] = [0.2, 0.4, 0.7, 0.5, 0.8, 0.3, 0.6]

    private var pollTimer: AnyCancellable?
    private var waveformTimer: AnyCancellable?
    private var isMediaRemoteAvailable: Bool = false

    private typealias MRGetInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias MRSendCommandFunc = @convention(c) (Int, Any?) -> Bool
    private typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void

    private var getNowPlayingInfoFunc: MRGetInfoFunc?
    private var sendCommandFunc: MRSendCommandFunc?

    public init() {
        setupMediaRemoteBindings()
        startObserving()
    }

    private func setupMediaRemoteBindings() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return
        }

        if let getInfoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfoFunc = unsafeBitCast(getInfoSym, to: MRGetInfoFunc.self)
        }

        if let sendSym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommandFunc = unsafeBitCast(sendSym, to: MRSendCommandFunc.self)
        }

        if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFunc = unsafeBitCast(regSym, to: MRRegisterFunc.self)
            registerFunc(DispatchQueue.main)
        }

        isMediaRemoteAvailable = (getNowPlayingInfoFunc != nil)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshNowPlaying()
            }
        }
    }

    public func startObserving() {
        refreshNowPlaying()

        pollTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNowPlaying()
            }

        waveformTimer = Timer.publish(every: 0.12, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateWaveform()
            }
    }

    public func stopObserving() {
        pollTimer?.cancel()
        pollTimer = nil
        waveformTimer?.cancel()
        waveformTimer = nil
    }

    public func refreshNowPlaying() {
        if let getInfo = getNowPlayingInfoFunc {
            getInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] rawDict in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let track = self.parseMediaRemoteDict(rawDict), track.hasTrack {
                        self.currentTrack = track
                    } else {
                        self.fallbackToAppleScript()
                    }
                }
            }
        } else {
            fallbackToAppleScript()
        }
    }

    private func parseMediaRemoteDict(_ dict: [String: Any]) -> NowPlayingTrack? {
        guard !dict.isEmpty else { return nil }

        let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)
            ?? (dict["title"] as? String) ?? ""
        let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String)
            ?? (dict["artist"] as? String) ?? ""
        let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)
            ?? (dict["album"] as? String) ?? ""
        let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0.0
        let elapsed = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0.0
        let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0.0
        let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

        guard !title.isEmpty else { return nil }

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: rate > 0.0,
            playbackRate: rate,
            artworkData: artworkData,
            bundleIdentifier: nil
        )
    }

    private func fallbackToAppleScript() {
        // Query Spotify or Apple Music via lightweight AppleScript
        let scriptSource = """
        if application "Spotify" is running then
            tell application "Spotify"
                set pState to player state as string
                set trName to name of current track
                set trArtist to artist of current track
                set trAlbum to album of current track
                set trDur to (duration of current track) / 1000
                set trPos to player position
                return "Spotify|||" & pState & "|||" & trName & "|||" & trArtist & "|||" & trAlbum & "|||" & trDur & "|||" & trPos
            end tell
        else if application "Music" is running then
            tell application "Music"
                set pState to player state as string
                if pState is not "stopped" then
                    set trName to name of current track
                    set trArtist to artist of current track
                    set trAlbum to album of current track
                    set trDur to duration of current track
                    set trPos to player position
                    return "Music|||" & pState & "|||" & trName & "|||" & trArtist & "|||" & trAlbum & "|||" & trDur & "|||" & trPos
                end if
            end tell
        end if
        return ""
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource),
           let result = script.executeAndReturnError(&error).stringValue,
           !result.isEmpty {
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 7 {
                let app = parts[0]
                let state = parts[1]
                let title = parts[2]
                let artist = parts[3]
                let album = parts[4]
                let duration = Double(parts[5]) ?? 0
                let elapsed = Double(parts[6]) ?? 0

                let isPlaying = (state.lowercased() == "playing")

                self.currentTrack = NowPlayingTrack(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    elapsedTime: elapsed,
                    isPlaying: isPlaying,
                    playbackRate: isPlaying ? 1.0 : 0.0,
                    artworkData: nil,
                    bundleIdentifier: app == "Spotify" ? "com.spotify.client" : "com.apple.Music"
                )
            }
        }
    }

    public func togglePlayPause() {
        if let send = sendCommandFunc {
            _ = send(2, nil) // 2 = TogglePlayPause
        } else {
            runAppleScriptCommand("playpause")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    public func nextTrack() {
        if let send = sendCommandFunc {
            _ = send(4, nil) // 4 = NextTrack
        } else {
            runAppleScriptCommand("next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    public func previousTrack() {
        if let send = sendCommandFunc {
            _ = send(5, nil) // 5 = PreviousTrack
        } else {
            runAppleScriptCommand("previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refreshNowPlaying()
        }
    }

    private func runAppleScriptCommand(_ action: String) {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to \(action)
        else if application "Music" is running then
            tell application "Music" to \(action)
        end if
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    private func updateWaveform() {
        guard currentTrack.isPlaying else {
            simulatedAudioLevels = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15]
            return
        }

        simulatedAudioLevels = (0..<7).map { _ in
            CGFloat.random(in: 0.25...0.95)
        }
    }
}
