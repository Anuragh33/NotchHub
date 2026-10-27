import SwiftUI

public struct PomodoroTimerView: View {
    @ObservedObject var viewModel: UtilitiesViewModel

    public init(viewModel: UtilitiesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let accent = viewModel.currentPhase.accentColor
        let pulseExpanded = viewModel.isTimerRunning && (viewModel.remainingSeconds % 2 == 0)

        HStack(spacing: 22) {
            // Left: Animated Circular Pomodoro Ring with Pulsing Aura
            ZStack {
                // Pulsing ambient glow when timer is running
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(viewModel.isTimerRunning ? 0.38 : 0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 58
                        )
                    )
                    .frame(width: 112, height: 112)
                    .scaleEffect(pulseExpanded ? 1.12 : 0.94)
                    .animation(.easeInOut(duration: 0.95), value: pulseExpanded)

                // Background Track Ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 7)
                    .frame(width: 90, height: 90)

                // Animated Remaining Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(viewModel.remainingFraction))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [accent.opacity(0.65), accent, .white]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)
                    .shadow(color: accent.opacity(0.55), radius: 6, x: 0, y: 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.remainingSeconds)

                // Center Countdown & Phase Icon
                VStack(spacing: 2) {
                    Image(systemName: viewModel.currentPhase.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                        .scaleEffect(pulseExpanded ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: pulseExpanded)

                    Text(viewModel.formattedTimer)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.2), value: viewModel.remainingSeconds)

                    Text(viewModel.currentPhase.rawValue.uppercased())
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 106, height: 102)

            // Right: Phase Selector, Pomodoro Cycle Dots, Duration Steppers & Transport Controls
            VStack(alignment: .leading, spacing: 10) {
                // Phase Selector Pills
                HStack(spacing: 6) {
                    ForEach(PomodoroPhase.allCases) { phase in
                        let isSelected = viewModel.currentPhase == phase
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                viewModel.selectPhase(phase)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: phase.symbolName)
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text(phase.rawValue)
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.78))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? phase.accentColor : Color.white.opacity(0.09))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // 4-Session Pomodoro Cycle Dots
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            let filled = (viewModel.completedPomodoros % 4) > index ||
                                (viewModel.completedPomodoros > 0 && viewModel.completedPomodoros % 4 == 0)
                            Circle()
                                .fill(filled ? accent : Color.white.opacity(0.18))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .help("Completed Focus Sessions: \(viewModel.completedPomodoros)")
                }

                // Transport & Duration Controls
                HStack(spacing: 10) {
                    // Play / Pause Primary Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.toggleTimer()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isTimerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(viewModel.isTimerRunning ? "Pause" : "Start")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent)
                                .shadow(color: accent.opacity(0.45), radius: 6, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    // Reset Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.resetTimer()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .help("Reset Timer")

                    // Next Phase Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.skipToNextPhase()
                        }
                    }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .help("Skip to Next Phase")

                    Spacer()

                    // -5m / +5m Quick Steppers
                    HStack(spacing: 5) {
                        Button(action: { viewModel.adjustDuration(byMinutes: -5) }) {
                            Text("-5m")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.09)))
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.adjustDuration(byMinutes: 5) }) {
                            Text("+5m")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.09)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}
