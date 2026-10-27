import AppKit
import Combine
import Foundation
import SwiftUI

public enum PomodoroPhase: String, CaseIterable, Identifiable, Sendable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    public var id: String { rawValue }

    public var defaultMinutes: Int {
        switch self {
        case .focus: return 25
        case .shortBreak: return 5
        case .longBreak: return 15
        }
    }

    public var symbolName: String {
        switch self {
        case .focus: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .focus: return Color(red: 1.0, green: 0.45, blue: 0.22)
        case .shortBreak: return Color(red: 0.16, green: 0.84, blue: 0.62)
        case .longBreak: return Color(red: 0.24, green: 0.64, blue: 0.98)
        }
    }
}

@MainActor
public final class UtilitiesViewModel: ObservableObject {
    @Published public private(set) var currentPhase: PomodoroPhase = .focus
    @Published public private(set) var remainingSeconds: Int = 25 * 60
    @Published public private(set) var totalSeconds: Int = 25 * 60
    @Published public private(set) var isTimerRunning: Bool = false
    @Published public private(set) var completedPomodoros: Int = 0
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

    public var remainingFraction: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    public func selectPhase(_ phase: PomodoroPhase) {
        pauseTimer()
        currentPhase = phase
        totalSeconds = phase.defaultMinutes * 60
        remainingSeconds = totalSeconds
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
                    self.handlePhaseCompleted()
                }
            }
        }
    }

    public func pauseTimer() {
        isTimerRunning = false
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    public func resetTimer(minutes: Int? = nil) {
        pauseTimer()
        let mins = minutes ?? currentPhase.defaultMinutes
        totalSeconds = max(60, mins * 60)
        remainingSeconds = totalSeconds
    }

    public func adjustDuration(byMinutes delta: Int) {
        let newTotal = max(60, min(120 * 60, totalSeconds + delta * 60))
        let newRemaining = max(60, min(newTotal, remainingSeconds + delta * 60))
        totalSeconds = newTotal
        remainingSeconds = newRemaining
    }

    public func skipToNextPhase() {
        handlePhaseCompleted()
    }

    private func handlePhaseCompleted() {
        pauseTimer()
        NSSound.beep()
        if currentPhase == .focus {
            completedPomodoros += 1
            if completedPomodoros % 4 == 0 {
                selectPhase(.longBreak)
            } else {
                selectPhase(.shortBreak)
            }
        } else {
            selectPhase(.focus)
        }
    }

    public func copyScratchpadToClipboard() {
        guard !scratchpadText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(scratchpadText, forType: .string)
    }
}
