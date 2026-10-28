import AppKit
import SwiftUI

public struct AppLauncherView: View {
    @ObservedObject var viewModel: AppLauncherViewModel
    let onLaunched: () -> Void

    public init(viewModel: AppLauncherViewModel, onLaunched: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onLaunched = onLaunched
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Text("Pinned App Dock (\(viewModel.pinned.count))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Button(action: {
                    viewModel.chooseAppToPin()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Pin App")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.pinned) { app in
                        PinnedAppButton(
                            app: app,
                            onLaunch: {
                                viewModel.launch(path: app.path)
                                onLaunched()
                            },
                            onUnpin: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    viewModel.unpin(app)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 82)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

private struct PinnedAppButton: View {
    let app: PinnedApp
    let onLaunch: () -> Void
    let onUnpin: () -> Void

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 42, height: 42)
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                Text(app.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 64)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Launch \(app.name)") {
                onLaunch()
            }
            Button(role: .destructive, action: onUnpin) {
                Text("Unpin \(app.name)")
            }
        }
    }
}
