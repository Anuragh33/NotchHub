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
            // Top Row: 5 Real System-Synced Provider Cards (Gemini, Claude, ChatGPT, OpenCode, Ollama)
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

            // Bottom Detail Strip: Real-Time Account Telemetry + Sign In / Sync Actions
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(selected.isAuthenticated ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)

                    VStack(alignment: .leading, spacing: 1.5) {
                        HStack(spacing: 5) {
                            Text(selected.planName)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if selected.needsSignIn {
                                Text("Needs Auth")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }

                        Text("\(selected.remainingUnits)/\(selected.totalUnits) \(selected.unitLabel) left • \(selected.resetDescription)")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Sign In / Connect Account Button
                Button(action: {
                    viewModel.openSignInWindow(for: selected.provider)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: selected.needsSignIn ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.badge.checkmark")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(selected.needsSignIn ? "Sign In" : "Account")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selected.needsSignIn ? .black : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selected.needsSignIn ? selectedColor : Color.white.opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
                .help("Sign in or manage \(selected.provider.rawValue) account credentials")

                // Live Sync Button
                Button(action: {
                    Task { await viewModel.refreshLiveStatuses() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                            .animation(
                                viewModel.isSyncing
                                    ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isSyncing
                            )
                        Text("Sync")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedColor.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)
                .help("Re-sync real-time usage from system accounts and APIs")
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

                    Circle()
                        .fill(item.isAuthenticated ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                }

                if item.needsSignIn {
                    Text("Sign In")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.orange)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(item.remainingPercentInt)%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("left")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                // Mini Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)

                        Capsule(style: .continuous)
                            .fill(item.needsSignIn ? Color.orange.opacity(0.6) : accentColor)
                            .frame(
                                width: max(4.0, geo.size.width * (item.needsSignIn ? 0.25 : item.remainingPercent)),
                                height: 4
                            )
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
