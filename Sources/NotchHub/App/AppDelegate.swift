import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var menuBarManager: MenuBarManager?
    private let globalHotKeyManager = GlobalHotKeyManager()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure as menu-bar / notch utility app so clicking inside never steals active app focus
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        self.notchWindowController = controller
        self.menuBarManager = MenuBarManager(notchViewModel: controller.viewModel)
        controller.showWindow()

        // Register global ⌃⌥K shortcut to toggle the NotchHub Command Palette from anywhere
        globalHotKeyManager.register { [weak controller] in
            controller?.viewModel.toggleCommandPalette()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
