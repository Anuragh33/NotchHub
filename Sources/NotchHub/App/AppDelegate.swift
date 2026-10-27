import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var menuBarManager: MenuBarManager?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure as menu-bar / notch utility app so clicking inside never steals active app focus
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        self.notchWindowController = controller
        self.menuBarManager = MenuBarManager(notchViewModel: controller.viewModel)
        controller.showWindow()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
