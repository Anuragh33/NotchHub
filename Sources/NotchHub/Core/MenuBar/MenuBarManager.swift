import AppKit
import Combine

@MainActor
public final class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let notchViewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()

    public init(notchViewModel: NotchViewModel) {
        self.notchViewModel = notchViewModel
        super.init()
        setupStatusItem()
        bindViewModel()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = notchViewModel.isMenuBarIconEnabled

        if let button = item.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.image = NSImage(
                systemSymbolName: "sparkles.rectangle.stack.fill",
                accessibilityDescription: "NotchHub"
            )?.withSymbolConfiguration(symbolConfig)
            button.imagePosition = .imageLeading
            button.title = " \(notchViewModel.aiUsageViewModel.averageRemainingPercentInt)%"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        }

        let menu = NSMenu(title: "NotchHub")
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        rebuildMenu(menu)
    }

    private func bindViewModel() {
        notchViewModel.$isMenuBarIconEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                self.statusItem?.isVisible = enabled
            }
            .store(in: &cancellables)

        notchViewModel.aiUsageViewModel.$providers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let button = self.statusItem?.button {
                    button.title = " \(self.notchViewModel.aiUsageViewModel.averageRemainingPercentInt)%"
                }
            }
            .store(in: &cancellables)
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let headerItem = NSMenuItem(title: "NotchHub — Dynamic Island Hub", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Section 1: Open Notch Modules
        let openHome = NSMenuItem(title: "Open Bento Home Dashboard", action: #selector(openHomeTab), keyEquivalent: "1")
        openHome.target = self
        openHome.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil)
        menu.addItem(openHome)

        let openAI = NSMenuItem(title: "Open AI Subscription Quotas", action: #selector(openAITab), keyEquivalent: "2")
        openAI.target = self
        openAI.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        menu.addItem(openAI)

        let openTimer = NSMenuItem(title: "Open Animated Pomodoro Timer", action: #selector(openTimerTab), keyEquivalent: "3")
        openTimer.target = self
        openTimer.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        menu.addItem(openTimer)

        let openShelf = NSMenuItem(title: "Open File Drop Shelf", action: #selector(openShelfTab), keyEquivalent: "4")
        openShelf.target = self
        openShelf.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
        menu.addItem(openShelf)

        let openClipboard = NSMenuItem(title: "Open Clipboard History", action: #selector(openClipboardTab), keyEquivalent: "5")
        openClipboard.target = self
        openClipboard.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)
        menu.addItem(openClipboard)

        let openApps = NSMenuItem(title: "Open Pinned App Dock", action: #selector(openAppsTab), keyEquivalent: "6")
        openApps.target = self
        openApps.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: nil)
        menu.addItem(openApps)

        let openPalette = NSMenuItem(title: "Command Palette (⌃⌥K)", action: #selector(openPaletteTab), keyEquivalent: "k")
        openPalette.target = self
        openPalette.image = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
        menu.addItem(openPalette)

        menu.addItem(.separator())

        // Section 2: Real-Time Synced AI Subscription Usage
        let aiHeader = NSMenuItem(title: "Synced System AI Accounts", action: nil, keyEquivalent: "")
        aiHeader.isEnabled = false
        menu.addItem(aiHeader)

        for usage in notchViewModel.aiUsageViewModel.providers {
            let statusStr = usage.needsSignIn
                ? "Sign In Required — Click to Connect"
                : "\(usage.remainingPercentInt)% remaining • \(usage.planName)"
            let title = "\(usage.provider.rawValue): \(statusStr)"
            let item = NSMenuItem(title: title, action: #selector(selectAIProviderFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = usage.provider.rawValue
            item.image = NSImage(systemSymbolName: usage.provider.symbolName, accessibilityDescription: usage.provider.rawValue)
            menu.addItem(item)
        }

        let refreshAI = NSMenuItem(title: "Sync All AI Accounts Now", action: #selector(refreshAIQuotas), keyEquivalent: "r")
        refreshAI.target = self
        refreshAI.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(refreshAI)

        menu.addItem(.separator())

        // Section 3: Notch Display Always / Off & Settings
        let displayHeader = NSMenuItem(title: "Notch Display Settings", action: nil, keyEquivalent: "")
        displayHeader.isEnabled = false
        menu.addItem(displayHeader)

        let modeAlways = NSMenuItem(title: "Notch Display: Always", action: #selector(setDisplayAlways), keyEquivalent: "")
        modeAlways.target = self
        modeAlways.state = (notchViewModel.notchDisplayMode == .always) ? .on : .off
        menu.addItem(modeAlways)

        let modeIdleOff = NSMenuItem(title: "Notch Display: Off When Not in Use (Hover Only)", action: #selector(setDisplayOffWhenIdle), keyEquivalent: "")
        modeIdleOff.target = self
        modeIdleOff.state = (notchViewModel.notchDisplayMode == .offWhenIdle) ? .on : .off
        menu.addItem(modeIdleOff)

        let modeCompletelyOff = NSMenuItem(title: "Notch Display: Completely Off (Menu Bar Only)", action: #selector(setDisplayCompletelyOff), keyEquivalent: "")
        modeCompletelyOff.target = self
        modeCompletelyOff.state = (notchViewModel.notchDisplayMode == .completelyOff) ? .on : .off
        menu.addItem(modeCompletelyOff)

        menu.addItem(.separator())

        let toggleWings = NSMenuItem(
            title: notchViewModel.isCompactWingsEnabled ? "Compact Wings: On" : "Compact Wings: Off",
            action: #selector(toggleCompactWings),
            keyEquivalent: "w"
        )
        toggleWings.target = self
        toggleWings.state = notchViewModel.isCompactWingsEnabled ? .on : .off
        menu.addItem(toggleWings)

        let toggleMenuBar = NSMenuItem(
            title: "Show Menu Bar Icon (Re-enable in Notch Settings)",
            action: #selector(toggleMenuBarIconVisibility),
            keyEquivalent: "m"
        )
        toggleMenuBar.target = self
        toggleMenuBar.state = notchViewModel.isMenuBarIconEnabled ? .on : .off
        menu.addItem(toggleMenuBar)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NotchHub", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openHomeTab() {
        notchViewModel.expandImmediately(to: .home)
    }

    @objc private func openAITab() {
        notchViewModel.expandImmediately(to: .aiUsage)
    }

    @objc private func openTimerTab() {
        notchViewModel.expandImmediately(to: .timer)
    }

    @objc private func openShelfTab() {
        notchViewModel.expandImmediately(to: .shelf)
    }

    @objc private func openClipboardTab() {
        notchViewModel.expandImmediately(to: .clipboard)
    }

    @objc private func openAppsTab() {
        notchViewModel.expandImmediately(to: .apps)
    }

    @objc private func openPaletteTab() {
        notchViewModel.toggleCommandPalette()
    }

    @objc private func selectAIProviderFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = AIProviderType(rawValue: raw) else { return }
        notchViewModel.aiUsageViewModel.selectedProvider = provider
        if let usage = notchViewModel.aiUsageViewModel.providers.first(where: { $0.provider == provider }),
           usage.needsSignIn {
            notchViewModel.aiUsageViewModel.openSignInWindow(for: provider)
        } else {
            notchViewModel.expandImmediately(to: .aiUsage)
        }
    }

    @objc private func refreshAIQuotas() {
        Task {
            await notchViewModel.aiUsageViewModel.refreshLiveStatuses()
        }
    }

    @objc private func setDisplayAlways() {
        notchViewModel.setNotchDisplayMode(.always)
    }

    @objc private func setDisplayOffWhenIdle() {
        notchViewModel.setNotchDisplayMode(.offWhenIdle)
    }

    @objc private func setDisplayCompletelyOff() {
        notchViewModel.setNotchDisplayMode(.completelyOff)
    }

    @objc private func toggleCompactWings() {
        notchViewModel.toggleCompactWingsMode()
    }

    @objc private func toggleMenuBarIconVisibility() {
        notchViewModel.toggleMenuBarIcon()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
