import AppKit
import SwiftUI

public struct CommandPaletteView: View {
    @ObservedObject var viewModel: CommandPaletteViewModel

    public init(viewModel: CommandPaletteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search Input Bar
            HStack(spacing: 8) {
                Image(systemName: "command.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.cyan)

                TextField("Type a command or search installed macOS apps...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .onSubmit {
                        viewModel.runFirst()
                    }

                if !viewModel.query.isEmpty {
                    Button(action: { viewModel.query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }

                Text("⌃⌥K")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 0.9)
                    )
            )

            // Instant Filtered Action & App Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.results) { item in
                        Button(action: {
                            viewModel.run(item)
                        }) {
                            HStack(spacing: 8) {
                                if let appPath = item.appPath {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: item.symbolName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.cyan)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.cyan.opacity(0.16)))
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 52)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}
