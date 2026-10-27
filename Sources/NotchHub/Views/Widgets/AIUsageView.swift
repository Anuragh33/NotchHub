import AppKit
import SwiftUI

public struct AIUsageView: View {
    @ObservedObject var viewModel: AIUsageViewModel

    public init(viewModel: AIUsageViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let selected = viewModel.currentSelectedUsage
        let selectedColor = Color(nsColor: NSColor(hex: selected.provider.accentHex) ?? .systemBlue)

        VStack(alignment: .leading, spacing: 8) {
            // Top Row: 5 Provider Cards (Gemini, Claude, ChatGPT, OpenCode, Ollama)
            HStack(spacing: 8) {
                ForEach(viewModel.providers) { item in
                    AIProviderCompactCard(
                        item: item,
                        isSelected: item.provider == viewModel.selectedProvider,
                        onSelect: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                viewModel.selectedProvider = item.provider
                            }
                        }
                    )
                }
            }

            // Bottom Detail & Interactive Quota Bar for Selected Provider
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(selected.isOnline ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(selected.provider.rawValue) • \(selected.planName)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("\(selected.remainingUnits)/\(selected.totalUnits) \(selected.unitLabel) left • \(selected.resetDescription)")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .frame(width: 195, alignment: .leading)

                // Interactive Remaining Quota Scrubber
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 7)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [selectedColor, selectedColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(6.0, geo.size.width * selected.remainingPercent),
                                height: 7
                            )
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = min(max(value.location.x / max(1, geo.size.width), 0.0), 1.0)
                                viewModel.setRemainingFraction(for: selected.provider, remainingFraction: fraction)
                            }
                    )
                }
                .frame(height: 18)

                // Quick Action Buttons (-1, +1 used, Reset / Refresh)
                HStack(spacing: 5) {
                    Button(action: { viewModel.recordUsage(for: selected.provider, delta: 1) }) {
                        Text("-1")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Log 1 prompt used (decrease remaining)")

                    Button(action: { viewModel.recordUsage(for: selected.provider, delta: -1) }) {
                        Text("+1")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Restore 1 prompt")

                    Button(action: {
                        if selected.provider == .ollama {
                            Task { await viewModel.refreshLiveStatuses() }
                        } else {
                            viewModel.resetQuota(for: selected.provider)
                        }
                    }) {
                        Image(systemName: selected.provider == .ollama ? "arrow.clockwise" : "bolt.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(selectedColor)
                            .frame(width: 22, height: 20)
                            .background(Capsule().fill(selectedColor.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .help(selected.provider == .ollama ? "Probe Local Ollama Server" : "Reset Remaining Quota to 100%")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.7)
                    )
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

private struct AIProviderCompactCard: View {
    let item: AIProviderUsage
    let isSelected: Bool
    let onSelect: () -> Void

    private var accentColor: Color {
        Color(nsColor: NSColor(hex: item.provider.accentHex) ?? .systemBlue)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: item.provider.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)

                    Text(item.provider.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(item.remainingPercentInt)%")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("left")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                // Mini Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)

                        Capsule(style: .continuous)
                            .fill(accentColor)
                            .frame(width: max(4.0, geo.size.width * item.remainingPercent), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.20) : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(
                                isSelected ? accentColor.opacity(0.85) : Color.white.opacity(0.11),
                                lineWidth: isSelected ? 1.2 : 0.7
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
