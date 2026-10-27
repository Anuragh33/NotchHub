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

        let headerItem = NSMenuItem(title: "NotchHub — AI Quotas, Pomodoro & Shelf", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Section 1: Open Notch Tabs
        let openAI = NSMenuItem(title: "Open AI Subscription Quotas", action: #selector(openAITab), keyEquivalent: "1")
        openAI.target = self
        openAI.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        menu.addItem(openAI)

        let openTimer = NSMenuItem(title: "Open Animated Pomodoro Timer", action: #selector(openTimerTab), keyEquivalent: "2")
        openTimer.target = self
        openTimer.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
        menu.addItem(openTimer)

        let openShelf = NSMenuItem(title: "Open File Drop Shelf", action: #selector(openShelfTab), keyEquivalent: "3")
        openShelf.target = self
        openShelf.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
        menu.addItem(openShelf)

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

        // Section 3: Settings (Compact Wings & Menu Bar Icon Toggle)
        let toggleWings = NSMenuItem(
            title: notchViewModel.isCompactWingsEnabled ? "Disable Compact Wings" : "Enable Compact Wings",
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

    @objc private func openAITab() {
        notchViewModel.expandImmediately(to: .aiUsage)
    }

    @objc private func openTimerTab() {
        notchViewModel.expandImmediately(to: .timer)
    }

    @objc private func openShelfTab() {
        notchViewModel.expandImmediately(to: .shelf)
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
