import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure as menu-bar / notch utility app so clicking inside never steals active app focus
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        self.notchWindowController = controller
        controller.showWindow()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
