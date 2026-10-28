import AppKit
import Combine
import Foundation

public struct PinnedApp: Identifiable, Equatable {
    public let path: String
    public var id: String { path }
    public var name: String {
        FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
    }
}

@MainActor
public final class AppLauncherViewModel: ObservableObject {
    private static let storageKey = "com.notchhub.launcher.pinned.v1"

    @Published public private(set) var pinned: [PinnedApp] = []

    public init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.storageKey) {
            pinned = saved.filter { FileManager.default.fileExists(atPath: $0) }.map(PinnedApp.init)
        } else {
            let defaults = [
                "com.apple.finder", "com.apple.Safari", "com.apple.Terminal",
                "com.apple.Notes", "com.apple.iCal", "com.apple.ActivityMonitor",
                "com.apple.systempreferences"
            ]
            pinned = defaults.compactMap {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path
            }.map(PinnedApp.init)
            persist()
        }
    }

    public func launch(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    public func pin(path: String) {
        guard !pinned.contains(where: { $0.path == path }) else { return }
        pinned.append(PinnedApp(path: path))
        persist()
    }

    public func unpin(_ app: PinnedApp) {
        pinned.removeAll { $0 == app }
        persist()
    }

    public func chooseAppToPin() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Pin"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            for url in panel.urls { pin(path: url.path) }
        }
    }

    private func persist() {
        UserDefaults.standard.set(pinned.map(\.path), forKey: Self.storageKey)
    }
}
