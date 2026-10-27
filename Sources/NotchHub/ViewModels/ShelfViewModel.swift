import AppKit
import Foundation
import UniformTypeIdentifiers

public enum ShelfItemKind: Sendable {
    case file(URL)
    case text(String)
    case image(URL, NSImage)
}

public struct ShelfItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let kind: ShelfItemKind
    public let icon: NSImage
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        kind: ShelfItemKind,
        icon: NSImage,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.icon = icon
        self.createdAt = createdAt
    }
}

@MainActor
public final class ShelfViewModel: ObservableObject {
    @Published public private(set) var items: [ShelfItem] = []
    @Published public var isDropTargeted: Bool = false

    public init() {
        // Seed with one sample quick-start snippet so the shelf is immediately interactive on first launch
        let sampleIcon = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Snippet") ?? NSImage()
        items = [
            ShelfItem(
                title: "Welcome Snippet.txt",
                subtitle: "Drag files, images, or text into the notch",
                kind: .text("NotchHub Quick Drop Shelf — Drag me out into any macOS app!"),
                icon: sampleIcon
            )
        ]
    }

    public func addFileURL(_ url: URL) {
        guard !items.contains(where: {
            if case .file(let existing) = $0.kind { return existing == url }
            if case .image(let existing, _) = $0.kind { return existing == url }
            return false
        }) else { return }

        let ext = url.pathExtension.lowercased()
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff"]

        if imageExtensions.contains(ext), let img = NSImage(contentsOf: url) {
            let item = ShelfItem(
                title: url.lastPathComponent,
                subtitle: "Image • \(url.deletingLastPathComponent().lastPathComponent)",
                kind: .image(url, img),
                icon: img
            )
            items.insert(item, at: 0)
        } else {
            let fileIcon = NSWorkspace.shared.icon(forFile: url.path)
            let item = ShelfItem(
                title: url.lastPathComponent,
                subtitle: url.deletingLastPathComponent().path,
                kind: .file(url),
                icon: fileIcon
            )
            items.insert(item, at: 0)
        }
    }

    public func addTextSnippet(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preview = String(trimmed.prefix(36))
        let icon = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Text") ?? NSImage()
        let item = ShelfItem(
            title: preview,
            subtitle: "\(trimmed.count) chars • Text Snippet",
            kind: .text(trimmed),
            icon: icon
        )
        items.insert(item, at: 0)
    }

    public func addDroppedImage(_ image: NSImage) {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "NotchDrop-\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = tempDir.appendingPathComponent(filename)

        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }

        let item = ShelfItem(
            title: filename,
            subtitle: "Dropped Image",
            kind: .image(fileURL, image),
            icon: image
        )
        items.insert(item, at: 0)
    }

    public func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func clearAll() {
        items.removeAll()
    }

    public func itemProvider(for item: ShelfItem) -> NSItemProvider {
        switch item.kind {
        case .file(let url), .image(let url, _):
            if let provider = NSItemProvider(contentsOf: url) {
                return provider
            }
            return NSItemProvider(object: url as NSURL)
        case .text(let snippet):
            return NSItemProvider(object: snippet as NSString)
        }
    }

    public func handlePasteboardDrop(_ pasteboard: NSPasteboard) -> Bool {
        var didAccept = false

        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            for url in urls {
                addFileURL(url)
            }
            didAccept = true
        } else if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
                  let firstImage = images.first {
            addDroppedImage(firstImage)
            didAccept = true
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            addTextSnippet(text)
            didAccept = true
        }

        return didAccept
    }
}
