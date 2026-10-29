import AppKit
import Combine
import Foundation

public struct PaletteResult: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let symbolName: String
    public let appPath: String?
    public let action: @MainActor () -> Void
}

@MainActor
public final class CommandPaletteViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public private(set) var focusTick: Int = 0

    public weak var notch: NotchViewModel?
    private var installedApps: [(name: String, path: String)]?

    public init() {}

    public func requestFocus() {
        focusTick += 1
    }

    public var results: [PaletteResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let commands = allCommands()
        guard !trimmed.isEmpty else { return Array(commands.prefix(8)) }

        var matched = commands.filter {
            $0.title.lowercased().contains(trimmed) || $0.subtitle.lowercased().contains(trimmed)
        }
        let apps = loadInstalledApps()
            .filter { $0.name.lowercased().contains(trimmed) }
            .sorted { $0.name.lowercased().hasPrefix(trimmed) && !$1.name.lowercased().hasPrefix(trimmed) }
            .prefix(5)
        for app in apps {
            matched.append(PaletteResult(
                title: "Launch \(app.name)",
                subtitle: "Application",
                symbolName: "app.fill",
                appPath: app.path,
                action: { [weak self] in
                    self?.notch?.appLauncherViewModel.launch(path: app.path)
                    self?.notch?.collapseImmediately()
                }
            ))
        }
        return matched
    }

    public func run(_ result: PaletteResult) {
        result.action()
        query = ""
    }

    public func runFirst() {
        if let first = results.first { run(first) }
    }

    private func loadInstalledApps() -> [(name: String, path: String)] {
        if let cached = installedApps { return cached }
        let fm = FileManager.default
        let dirs = [
            "/Applications", "/System/Applications", "/System/Applications/Utilities",
            "/Applications/Utilities", NSHomeDirectory() + "/Applications"
        ]
        var found: [(String, String)] = []
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                found.append((String(item.dropLast(4)), dir + "/" + item))
            }
        }
        installedApps = found
        return found
    }

    private func allCommands() -> [PaletteResult] {
        guard let notch else { return [] }
        let timer = notch.utilitiesViewModel
        var list: [PaletteResult] = []

        func add(_ title: String, _ subtitle: String, _ symbol: String, _ action: @escaping @MainActor () -> Void) {
            list.append(PaletteResult(title: title, subtitle: subtitle, symbolName: symbol, appPath: nil, action: action))
        }

        add("Start Focus Session", "Pomodoro • 25 min", "flame.fill") {
            timer.selectPhase(.focus); timer.startTimer(); notch.expandImmediately(to: .timer)
        }
        add(timer.isTimerRunning ? "Pause Timer" : "Resume Timer", "Pomodoro", "playpause.fill") {
            timer.toggleTimer()
        }
        add("Start Short Break", "Pomodoro • 5 min", "cup.and.saucer.fill") {
            timer.selectPhase(.shortBreak); timer.startTimer(); notch.expandImmediately(to: .timer)
        }
        add("Open Home", "Dashboard", "square.grid.2x2.fill") { notch.expandImmediately(to: .home) }
        add("Open Now Playing", "Music & media player", "music.note") { notch.expandImmediately(to: .media) }
        add("Play / Pause Music", "Now Playing", "playpause.fill") { notch.mediaService.togglePlayPause() }
        add("Next Track", "Now Playing", "forward.fill") { notch.mediaService.nextTrack() }
        add("Previous Track", "Now Playing", "backward.fill") { notch.mediaService.previousTrack() }
        add("Open Camera Mirror", "Instant meeting check", "camera.fill") { notch.expandImmediately(to: .mirror) }
        add("Check Battery & MagSafe", "Power HUD", "bolt.badge.checkmark.fill") {
            let batt = notch.batteryService.currentState
            notch.showBanner(NotchBanner(
                icon: batt.batterySymbol,
                title: batt.isCharging ? "MagSafe Charging" : "Battery Status",
                subtitle: "\(batt.percentage)% • \(batt.isACConnected ? "AC Power" : "On Battery")",
                accentColorName: batt.isCharging ? "green" : (batt.percentage <= 20 ? "red" : "blue")
            ))
        }
        add("Open AI Usage", "Quotas", "sparkles") { notch.expandImmediately(to: .aiUsage) }
        add("Open Drop Shelf", "Files", "tray.and.arrow.down.fill") { notch.expandImmediately(to: .shelf) }
        add("Open Clipboard History", "Clipboard", "doc.on.clipboard.fill") { notch.expandImmediately(to: .clipboard) }
        add("Open App Launcher", "Pinned apps", "square.grid.3x3.fill") { notch.expandImmediately(to: .apps) }
        add("Sync AI Accounts", "Refresh usage", "arrow.triangle.2.circlepath") {
            Task { await notch.aiUsageViewModel.refreshLiveStatuses() }
        }
        for provider in AIProviderType.allCases {
            add("Sign in to \(provider.rawValue)", "AI account", provider.symbolName) {
                notch.aiUsageViewModel.openSignInWindow(for: provider)
            }
        }
        add("Clear Clipboard History", "Clipboard", "trash") { notch.clipboardViewModel.clearAll() }
        add("Clear Drop Shelf", "Files", "trash") { notch.shelfViewModel.clearAll() }
        add("Notch Display: Always", "Settings", "eye.fill") { notch.setNotchDisplayMode(.always) }
        add("Notch Display: Off When Idle", "Settings", "eye.slash.fill") { notch.setNotchDisplayMode(.offWhenIdle) }
        add("Toggle Compact Wings", "Settings", "rectangle.expand.vertical") { notch.toggleCompactWingsMode() }
        add("Toggle Menu Bar Icon", "Settings", "menubar.rectangle") { notch.toggleMenuBarIcon() }
        add("Quit NotchHub", "App", "power") { NSApplication.shared.terminate(nil) }
        return list
    }
}
