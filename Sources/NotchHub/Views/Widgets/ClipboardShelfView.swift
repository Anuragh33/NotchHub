import AppKit
import SwiftUI

public struct ClipboardShelfView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    public init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.purple)
                    Text("Clipboard History (\(viewModel.entries.count))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("• Password Safe")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.green.opacity(0.85))
                }

                Spacer()

                if !viewModel.entries.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearAll()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Clear")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.entries.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )

                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.purple.opacity(0.8))
                        Text("Copy any text, link, or image (`⌘C`) and it will appear here for one-click reuse")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(height: 82)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.entries) { entry in
                            ClipboardEntryCard(entry: entry, viewModel: viewModel)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 82)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

private struct ClipboardEntryCard: View {
    let entry: ClipboardEntry
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        Button(action: {
            viewModel.copy(entry)
        }) {
            HStack(spacing: 8) {
                switch entry.payload {
                case .image(let img):
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                case .text:
                    Image(systemName: entry.isLink ? "link" : "text.alignleft")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(entry.isLink ? .cyan : .purple)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill((entry.isLink ? Color.cyan : Color.purple).opacity(0.18))
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.previewText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text("Click to copy")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.purple.opacity(0.9))
                }
                .frame(width: 124, alignment: .leading)

                Button(action: {
                    viewModel.remove(entry.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.13), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
