import AppKit
import SwiftUI

public struct QuickUtilitiesBar: View {
    @ObservedObject var utilitiesViewModel: UtilitiesViewModel
    @ObservedObject var notchViewModel: NotchViewModel

    public init(
        utilitiesViewModel: UtilitiesViewModel,
        notchViewModel: NotchViewModel
    ) {
        self.utilitiesViewModel = utilitiesViewModel
        self.notchViewModel = notchViewModel
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 1. Quick Pomodoro Timer Control Pill
            HStack(spacing: 6) {
                Button(action: { utilitiesViewModel.toggleTimer() }) {
                    Image(systemName: utilitiesViewModel.isTimerRunning ? "pause.fill" : "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(utilitiesViewModel.isTimerRunning ? Color.orange : Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Text(utilitiesViewModel.formattedTimer)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(utilitiesViewModel.isTimerRunning ? Color.orange : .white)
                    .frame(width: 42, alignment: .leading)

                Button(action: { utilitiesViewModel.resetTimer(minutes: 25) }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Reset 25m Pomodoro")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                utilitiesViewModel.isTimerRunning ? Color.orange.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 0.8
                            )
                    )
            )

            // 2. Local Scratchpad Input
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                TextField("Quick scratchpad note...", text: $utilitiesViewModel.scratchpadText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)

                if !utilitiesViewModel.scratchpadText.isEmpty {
                    Button(action: { utilitiesViewModel.copyScratchpadToClipboard() }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Scratchpad")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )

            // 3. Settings & Compact Wings Toggle / Quit Menu
            Menu {
                Button(action: {
                    notchViewModel.toggleCompactWingsMode()
                }) {
                    Label(
                        notchViewModel.isCompactWingsEnabled ? "Disable Compact Wings" : "Enable Compact Wings",
                        systemImage: notchViewModel.isCompactWingsEnabled ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                    )
                }

                Divider()

                Button("Set 25m Focus Timer") {
                    utilitiesViewModel.resetTimer(minutes: 25)
                    utilitiesViewModel.startTimer()
                }

                Button("Set 5m Short Break") {
                    utilitiesViewModel.resetTimer(minutes: 5)
                    utilitiesViewModel.startTimer()
                }

                Divider()

                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit NotchHub", systemImage: "power")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .padding(.top, 2)
    }
}
