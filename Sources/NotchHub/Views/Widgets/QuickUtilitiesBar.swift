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
        let timerAccent = utilitiesViewModel.currentPhase.accentColor

        HStack(spacing: 8) {
            // 1. Quick Animated Pomodoro Timer Pill
            HStack(spacing: 6) {
                Button(action: { utilitiesViewModel.toggleTimer() }) {
                    Image(systemName: utilitiesViewModel.isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(utilitiesViewModel.isTimerRunning ? timerAccent : Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(NotchViewModel.springAnimation) {
                        notchViewModel.selectedTab = .timer
                    }
                }) {
                    Text(utilitiesViewModel.formattedTimer)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(utilitiesViewModel.isTimerRunning ? timerAccent : .white)
                        .frame(width: 42, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Open Animated Pomodoro Timer")

                Button(action: { utilitiesViewModel.resetTimer() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Reset Timer")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                utilitiesViewModel.isTimerRunning ? timerAccent.opacity(0.55) : Color.white.opacity(0.12),
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

            // 3. Command Palette Trigger (⌃⌥K)
            Button(action: {
                withAnimation(NotchViewModel.springAnimation) {
                    notchViewModel.selectedTab = (notchViewModel.selectedTab == .palette) ? .home : .palette
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "command")
                        .font(.system(size: 10, weight: .bold))
                    Text("K")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(notchViewModel.selectedTab == .palette ? .black : .white.opacity(0.85))
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    Capsule(style: .continuous)
                        .fill(notchViewModel.selectedTab == .palette ? Color.cyan : Color.white.opacity(0.10))
                )
            }
            .buttonStyle(.plain)
            .help("Toggle Command Palette (⌃⌥K)")

            // 4. Settings Menu (Notch Display Always/Off, Idle Pill Width, Menu Bar Icon On/Off, Compact Wings On/Off, AI Sign-In, Quit)
            Menu {
                Button(action: {
                    notchViewModel.toggleNotchAlwaysDisplayed()
                }) {
                    Label(
                        notchViewModel.notchDisplayMode == .always
                            ? "Notch Display: Always (Click to Set Off When Idle)"
                            : "Notch Display: Off When Idle (Click to Set Always)",
                        systemImage: notchViewModel.notchDisplayMode == .always ? "eye.fill" : "eye.slash.fill"
                    )
                }

                Menu("Notch Display Mode (\(notchViewModel.notchDisplayMode.rawValue))") {
                    ForEach(NotchDisplayMode.allCases) { mode in
                        Button(action: {
                            notchViewModel.setNotchDisplayMode(mode)
                        }) {
                            HStack {
                                Text(mode == .always ? "Always Display Notch" : (mode == .offWhenIdle ? "Off When Not in Use (Hover to Show)" : "Completely Off (Menu Bar Only)"))
                                if notchViewModel.notchDisplayMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Menu("Idle Pill Width (\(notchViewModel.idlePillPreset.rawValue))") {
                    ForEach(IdlePillWidthPreset.allCases) { preset in
                        Button(action: {
                            withAnimation(NotchViewModel.springAnimation) {
                                notchViewModel.idlePillPreset = preset
                            }
                        }) {
                            HStack {
                                Text(preset.rawValue)
                                if notchViewModel.idlePillPreset == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Button(action: {
                    notchViewModel.toggleMenuBarIcon()
                }) {
                    Label(
                        notchViewModel.isMenuBarIconEnabled ? "Menu Bar Icon: On (Click to Turn Off)" : "Menu Bar Icon: Off (Click to Turn On)",
                        systemImage: notchViewModel.isMenuBarIconEnabled ? "menubar.rectangle" : "menubar.arrow.up.rectangle"
                    )
                }

                Button(action: {
                    notchViewModel.toggleCompactWingsMode()
                }) {
                    Label(
                        notchViewModel.isCompactWingsEnabled ? "Compact Wings: On (Click to Turn Off)" : "Compact Wings: Off (Click to Turn On)",
                        systemImage: notchViewModel.isCompactWingsEnabled ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
                    )
                }

                Divider()

                Menu("Sign In / Connect AI Account...") {
                    ForEach(AIProviderType.allCases) { provider in
                        Button(action: {
                            notchViewModel.aiUsageViewModel.openSignInWindow(for: provider)
                        }) {
                            Label("Sign In to \(provider.rawValue)...", systemImage: provider.symbolName)
                        }
                    }
                }

                Button(action: {
                    Task {
                        await notchViewModel.aiUsageViewModel.refreshLiveStatuses()
                    }
                }) {
                    Label("Sync All AI Accounts Now", systemImage: "arrow.triangle.2.circlepath")
                }

                Divider()

                Button("Start 25m Focus Pomodoro") {
                    utilitiesViewModel.selectPhase(.focus)
                    utilitiesViewModel.startTimer()
                    notchViewModel.expandImmediately(to: .timer)
                }

                Button("Start 5m Short Break") {
                    utilitiesViewModel.selectPhase(.shortBreak)
                    utilitiesViewModel.startTimer()
                    notchViewModel.expandImmediately(to: .timer)
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
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 28, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
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
