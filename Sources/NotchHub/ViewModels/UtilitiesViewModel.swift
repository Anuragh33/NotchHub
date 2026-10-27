import AppKit
import Combine
import Foundation

@MainActor
public final class UtilitiesViewModel: ObservableObject {
    @Published public private(set) var remainingSeconds: Int = 25 * 60
    @Published public private(set) var totalSeconds: Int = 25 * 60
    @Published public private(set) var isTimerRunning: Bool = false
    @Published public var scratchpadText: String {
        didSet {
            UserDefaults.standard.set(scratchpadText, forKey: Self.scratchpadStorageKey)
        }
    }

    private static let scratchpadStorageKey = "com.notchhub.scratchpad.text"
    private var countdownTimer: Timer?

    public init() {
        self.scratchpadText = UserDefaults.standard.string(forKey: Self.scratchpadStorageKey) ?? ""
    }

    public var formattedTimer: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    public var timerProgress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    public func toggleTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    public func startTimer() {
        guard !isTimerRunning else { return }
        if remainingSeconds <= 0 {
            remainingSeconds = totalSeconds
        }
        isTimerRunning = true
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.pauseTimer()
                    NSSound.beep()
                }
            }
        }
    }

    public func pauseTimer() {
        isTimerRunning = false
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    public func resetTimer(minutes: Int = 25) {
        pauseTimer()
        totalSeconds = max(1, minutes * 60)
        remainingSeconds = totalSeconds
    }

    public func copyScratchpadToClipboard() {
        guard !scratchpadText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(scratchpadText, forType: .string)
    }
}
