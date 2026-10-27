import AppKit
import SwiftUI

@main
public struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    public init() {}

    public var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
