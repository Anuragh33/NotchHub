import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct FileShelfView: View {
    @ObservedObject var viewModel: ShelfViewModel

    public init(viewModel: ShelfViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text("Temporary Drop Shelf (\(viewModel.items.count))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                if !viewModel.items.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.clearAll()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Clear All")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.items.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            viewModel.isDropTargeted ? Color.cyan : Color.white.opacity(0.22),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.isDropTargeted ? Color.cyan.opacity(0.14) : Color.white.opacity(0.04))
                        )

                    VStack(spacing: 5) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(viewModel.isDropTargeted ? .cyan : .white.opacity(0.55))
                        Text("Drop files, images, or text snippets here to hold temporarily")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(height: 82)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.items) { item in
                            ShelfItemCard(item: item, viewModel: viewModel)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 82)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .onDrop(
            of: [.fileURL, .image, .utf8PlainText, .plainText, .url],
            isTargeted: $viewModel.isDropTargeted
        ) { providers in
            handleDropProviders(providers)
        }
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    let resolvedURL: URL? = {
                        if let urlData = data as? Data {
                            return URL(dataRepresentation: urlData, relativeTo: nil)
                        } else if let directURL = data as? URL {
                            return directURL
                        }
                        return nil
                    }()
                    if let url = resolvedURL {
                        Task { @MainActor in
                            viewModel.addFileURL(url)
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    if let nsImage = object as? NSImage {
                        Task { @MainActor in
                            viewModel.addDroppedImage(nsImage)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    let extractedText: String? = {
                        if let str = data as? String {
                            return str
                        } else if let rawData = data as? Data {
                            return String(data: rawData, encoding: .utf8)
                        }
                        return nil
                    }()
                    if let text = extractedText {
                        Task { @MainActor in
                            viewModel.addTextSnippet(text)
                        }
                    }
                }
            }
        }
        return true
    }
}

private struct ShelfItemCard: View {
    let item: ShelfItem
    @ObservedObject var viewModel: ShelfViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                Text("Drag out to share")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.85))
            }
            .frame(width: 112, alignment: .leading)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.removeItem(item.id)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                )
        )
        .onDrag {
            viewModel.itemProvider(for: item)
        }
    }
}
