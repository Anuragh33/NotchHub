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

        let headerItem = NSMenuItem(title: "NotchHub — Dynamic Island & AI Quotas", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Section 1: Open Notch Tabs
        let openMedia = NSMenuItem(title: "Open Media Controller", action: #selector(openMediaTab), keyEquivalent: "1")
        openMedia.target = self
        openMedia.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: nil)
        menu.addItem(openMedia)

        let openAI = NSMenuItem(title: "Open AI Subscription Quotas", action: #selector(openAITab), keyEquivalent: "2")
        openAI.target = self
        openAI.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        menu.addItem(openAI)

        let openShelf = NSMenuItem(title: "Open File Drop Shelf", action: #selector(openShelfTab), keyEquivalent: "3")
        openShelf.target = self
        openShelf.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
        menu.addItem(openShelf)

        menu.addItem(.separator())

        // Section 2: Live AI Subscription Remaining Usage
        let aiHeader = NSMenuItem(title: "AI Subscription Remaining Usage", action: nil, keyEquivalent: "")
        aiHeader.isEnabled = false
        menu.addItem(aiHeader)

        for usage in notchViewModel.aiUsageViewModel.providers {
            let title = "\(usage.provider.rawValue): \(usage.remainingPercentInt)% remaining (\(usage.remainingUnits)/\(usage.totalUnits) \(usage.unitLabel))"
            let item = NSMenuItem(title: title, action: #selector(selectAIProviderFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = usage.provider.rawValue
            item.image = NSImage(systemSymbolName: usage.provider.symbolName, accessibilityDescription: usage.provider.rawValue)
            menu.addItem(item)
        }

        let refreshAI = NSMenuItem(title: "Refresh Ollama & AI Quotas", action: #selector(refreshAIQuotas), keyEquivalent: "r")
        refreshAI.target = self
        refreshAI.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        menu.addItem(refreshAI)

        menu.addItem(.separator())

        // Section 3: Appearance & Menu Bar Icon Toggle
        let toggleWings = NSMenuItem(
            title: notchViewModel.isCompactWingsEnabled ? "Disable Compact Wings" : "Enable Compact Wings",
            action: #selector(toggleCompactWings),
            keyEquivalent: "w"
        )
        toggleWings.target = self
        toggleWings.state = notchViewModel.isCompactWingsEnabled ? .on : .off
        menu.addItem(toggleWings)

        let toggleMenuBar = NSMenuItem(
            title: "Show Menu Bar Icon (Re-enable inside Notch)",
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

    @objc private func openMediaTab() {
        notchViewModel.expandImmediately(to: .media)
    }

    @objc private func openAITab() {
        notchViewModel.expandImmediately(to: .aiUsage)
    }

    @objc private func openShelfTab() {
        notchViewModel.expandImmediately(to: .shelf)
    }

    @objc private func selectAIProviderFromMenu(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String,
           let provider = AIProviderType(rawValue: raw) {
            notchViewModel.aiUsageViewModel.selectedProvider = provider
        }
        notchViewModel.expandImmediately(to: .aiUsage)
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
