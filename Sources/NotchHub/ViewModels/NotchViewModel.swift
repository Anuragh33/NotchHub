import AppKit
import Combine
import SwiftUI

public enum NotchExpansionState: String, Equatable, Sendable {
    case collapsed
    case compactWings
    case expanded
}

public enum NotchDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case always = "Always"
    case offWhenIdle = "Off When Not in Use"
    case completelyOff = "Completely Off"

    public var id: String { rawValue }
}

public enum IdlePillWidthPreset: String, CaseIterable, Identifiable, Sendable {
    case compact = "Compact"
    case standard = "Standard"
    case wide = "Wide"

    public var id: String { rawValue }

    public var extraWingsWidth: CGFloat {
        switch self {
        case .compact: return 118.0
        case .standard: return 152.0
        case .wide: return 194.0
        }
    }
}

public enum NotchTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Bento Home"
    case media = "Now Playing"
    case aiUsage = "AI Usage"
    case timer = "Pomodoro Timer"
    case shelf = "Drop Shelf"
    case clipboard = "Clipboard History"
    case apps = "App Dock"
    case mirror = "Camera Mirror"
    case palette = "Command Palette"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .aiUsage: return "sparkles"
        case .timer: return "timer"
        case .shelf: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .apps: return "square.grid.3x3.fill"
        case .mirror: return "camera.fill"
        case .palette: return "command"
        }
    }

    /// Tabs displayed as symbol-only pills on the left of the camera cutout
    public static var primaryLeftTabs: [NotchTab] {
        [.home, .media, .aiUsage, .timer, .shelf, .clipboard, .apps, .mirror]
    }
}

public struct NotchBanner: Equatable, Identifiable, Sendable {
    public let id: String
    public let icon: String
    public let title: String
    public let subtitle: String
    public let accentColorName: String

    public init(id: String = UUID().uuidString, icon: String, title: String, subtitle: String, accentColorName: String = "green") {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColorName = accentColorName
    }
}

@MainActor
public final class NotchViewModel: ObservableObject {
    private static let menuBarIconStorageKey = "com.notchhub.menubar.enabled"
    private static let compactWingsStorageKey = "com.notchhub.compactwings.enabled"
    private static let notchDisplayModeStorageKey = "com.notchhub.display.mode"
    private static let idlePillPresetStorageKey = "com.notchhub.idlepill.preset"

    @Published public private(set) var expansionState: NotchExpansionState = .compactWings
    @Published public var selectedTab: NotchTab = .home
    @Published public var notchDisplayMode: NotchDisplayMode {
        didSet {
            UserDefaults.standard.set(notchDisplayMode.rawValue, forKey: Self.notchDisplayModeStorageKey)
            if notchDisplayMode == .completelyOff {
                if !isMenuBarIconEnabled {
                    isMenuBarIconEnabled = true
                }
                collapseImmediately()
            } else if expansionState != .expanded {
                withAnimation(Self.springAnimation) {
                    expansionState = restingState
                }
            }
        }
    }
    @Published public var idlePillPreset: IdlePillWidthPreset {
        didSet {
            UserDefaults.standard.set(idlePillPreset.rawValue, forKey: Self.idlePillPresetStorageKey)
        }
    }
    @Published public var isCompactWingsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCompactWingsEnabled, forKey: Self.compactWingsStorageKey)
            if expansionState != .expanded {
                withAnimation(Self.springAnimation) {
                    expansionState = restingState
                }
            }
        }
    }
    @Published public var isMenuBarIconEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMenuBarIconEnabled, forKey: Self.menuBarIconStorageKey)
        }
    }
    @Published public var isHoveringNotch: Bool = false
    @Published public var isDraggingOverScreenTop: Bool = false
    @Published public private(set) var activeBanner: NotchBanner?

    public static let springAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.78)

    public let geometryManager: ScreenGeometryManager
    public let aiUsageViewModel: AIUsageViewModel
    public let shelfViewModel: ShelfViewModel
    public let clipboardViewModel: ClipboardViewModel
    public let appLauncherViewModel: AppLauncherViewModel
    public let commandPaletteViewModel: CommandPaletteViewModel
    public let utilitiesViewModel: UtilitiesViewModel
    public let mediaService: MediaService = .shared
    public let batteryService: BatteryService = .shared
    public let bluetoothService: BluetoothDeviceService = .shared
    public let cameraService: CameraMirrorService = .shared

    private var bannerDismissTask: Task<Void, Never>?

    private var hoverExpandTask: Task<Void, Never>?
    private var exitCollapseTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(
        geometryManager: ScreenGeometryManager = ScreenGeometryManager(),
        aiUsageViewModel: AIUsageViewModel = AIUsageViewModel(),
        shelfViewModel: ShelfViewModel = ShelfViewModel(),
        clipboardViewModel: ClipboardViewModel = ClipboardViewModel(),
        appLauncherViewModel: AppLauncherViewModel = AppLauncherViewModel(),
        commandPaletteViewModel: CommandPaletteViewModel = CommandPaletteViewModel(),
        utilitiesViewModel: UtilitiesViewModel = UtilitiesViewModel()
    ) {
        self.geometryManager = geometryManager
        self.aiUsageViewModel = aiUsageViewModel
        self.shelfViewModel = shelfViewModel
        self.clipboardViewModel = clipboardViewModel
        self.appLauncherViewModel = appLauncherViewModel
        self.commandPaletteViewModel = commandPaletteViewModel
        self.utilitiesViewModel = utilitiesViewModel

        let savedWings = UserDefaults.standard.object(forKey: Self.compactWingsStorageKey) as? Bool ?? true
        let savedMenuBar = UserDefaults.standard.object(forKey: Self.menuBarIconStorageKey) as? Bool ?? true
        let savedModeRaw = UserDefaults.standard.string(forKey: Self.notchDisplayModeStorageKey) ?? NotchDisplayMode.always.rawValue
        let savedMode = NotchDisplayMode(rawValue: savedModeRaw) ?? .always
        let savedPresetRaw = UserDefaults.standard.string(forKey: Self.idlePillPresetStorageKey) ?? IdlePillWidthPreset.standard.rawValue
        let savedPreset = IdlePillWidthPreset(rawValue: savedPresetRaw) ?? .standard

        self.isCompactWingsEnabled = savedWings
        self.isMenuBarIconEnabled = savedMenuBar
        self.notchDisplayMode = savedMode
        self.idlePillPreset = savedPreset
        self.expansionState = (savedMode == .always && savedWings) ? .compactWings : .collapsed

        self.commandPaletteViewModel.notch = self

        batteryService.onChargingConnected = { [weak self] pct in
            self?.showBanner(NotchBanner(
                icon: "bolt.fill",
                title: "MagSafe Connected",
                subtitle: "\(pct)% • Charging",
                accentColorName: "green"
            ))
        }

        batteryService.onChargingDisconnected = { [weak self] pct in
            self?.showBanner(NotchBanner(
                icon: "powerplug",
                title: "On Battery Power",
                subtitle: "\(pct)% remaining",
                accentColorName: "orange"
            ))
        }

        bluetoothService.onDeviceConnected = { [weak self] dev in
            self?.showBanner(NotchBanner(
                icon: dev.iconName,
                title: dev.name,
                subtitle: dev.isAirPods ? "AirPods Connected" : "Connected",
                accentColorName: "blue"
            ))
        }

        geometryManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var restingState: NotchExpansionState {
        if notchDisplayMode != .always {
            return .collapsed
        }
        return isCompactWingsEnabled ? .compactWings : .collapsed
    }

    public var isHiddenWhenIdle: Bool {
        switch notchDisplayMode {
        case .always:
            return false
        case .offWhenIdle:
            return expansionState != .expanded
        case .completelyOff:
            return true
        }
    }

    public var topEarRadius: CGFloat {
        switch expansionState {
        case .collapsed:
            return 8.0
        case .compactWings:
            return 10.0
        case .expanded:
            return 14.0
        }
    }

    public var bottomCornerRadius: CGFloat {
        switch expansionState {
        case .collapsed:
            return 12.0
        case .compactWings:
            return 15.0
        case .expanded:
            return 26.0
        }
    }

    public func currentNotchSize() -> CGSize {
        let base = geometryManager.currentGeometry.notchSize
        switch expansionState {
        case .collapsed:
            return CGSize(width: base.width + (topEarRadius * 2.0), height: base.height)
        case .compactWings:
            return CGSize(
                width: base.width + idlePillPreset.extraWingsWidth + (topEarRadius * 2.0),
                height: max(base.height, 34.0)
            )
        case .expanded:
            return CGSize(
                width: max(560.0, base.width + 360.0) + (topEarRadius * 2.0),
                height: 258.0
            )
        }
    }

    public func activeInteractiveScreenRect() -> CGRect {
        let geom = geometryManager.currentGeometry
        let size = currentNotchSize()
        let x = geom.notchFrame.midX - (size.width / 2.0)
        let y = geom.screenFrame.maxY - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Hover, Drag, and Expansion Physics (150ms Expand / 300ms Collapse)

    public func handleCursorMoved(at screenPoint: CGPoint) {
        guard notchDisplayMode != .completelyOff else { return }

        let interactiveRect = activeInteractiveScreenRect().insetBy(dx: -6.0, dy: -4.0)
        let inside = NSMouseInRect(screenPoint, interactiveRect, false)

        if inside {
            if !isHoveringNotch {
                isHoveringNotch = true
                scheduleHoverExpansion()
            }
            cancelCollapseTimer()
        } else {
            if isHoveringNotch {
                isHoveringNotch = false
                cancelHoverExpansion()
                scheduleExitCollapse()
            }
        }
    }

    public func handleMouseEnteredPanel() {
        guard notchDisplayMode != .completelyOff else { return }
        isHoveringNotch = true
        cancelCollapseTimer()
        scheduleHoverExpansion()
    }

    public func handleMouseExitedPanel() {
        let point = NSEvent.mouseLocation
        let interactiveRect = activeInteractiveScreenRect().insetBy(dx: -4.0, dy: -4.0)
        if !NSMouseInRect(point, interactiveRect, false) {
            isHoveringNotch = false
            cancelHoverExpansion()
            scheduleExitCollapse()
        }
    }

    public func handleOutsideClick(at screenPoint: CGPoint) {
        let interactiveRect = activeInteractiveScreenRect()
        if !NSMouseInRect(screenPoint, interactiveRect, false), expansionState == .expanded {
            cancelHoverExpansion()
            cancelCollapseTimer()
            withAnimation(Self.springAnimation) {
                expansionState = restingState
            }
        }
    }

    public func handleSystemDrag(at screenPoint: CGPoint) {
        guard notchDisplayMode != .completelyOff else { return }

        let geom = geometryManager.currentGeometry
        let topStripHeight: CGFloat = 60.0
        let topDragBand = CGRect(
            x: geom.screenFrame.minX,
            y: geom.screenFrame.maxY - topStripHeight,
            width: geom.screenFrame.width,
            height: topStripHeight
        )

        if NSMouseInRect(screenPoint, topDragBand, false) {
            isDraggingOverScreenTop = true
            shelfViewModel.isDropTargeted = true
            cancelHoverExpansion()
            cancelCollapseTimer()
            if selectedTab != .shelf || expansionState != .expanded {
                withAnimation(Self.springAnimation) {
                    selectedTab = .shelf
                    expansionState = .expanded
                }
            }
        } else if isDraggingOverScreenTop {
            let expandedRect = activeInteractiveScreenRect().insetBy(dx: -24.0, dy: -24.0)
            if !NSMouseInRect(screenPoint, expandedRect, false) {
                isDraggingOverScreenTop = false
                shelfViewModel.isDropTargeted = false
                scheduleExitCollapse()
            }
        }
    }

    public func handleSystemDragEnded() {
        isDraggingOverScreenTop = false
        shelfViewModel.isDropTargeted = false
        let point = NSEvent.mouseLocation
        if !NSMouseInRect(point, activeInteractiveScreenRect(), false) {
            scheduleExitCollapse()
        }
    }

    public func toggleCommandPalette() {
        if expansionState == .expanded && selectedTab == .palette {
            collapseImmediately()
        } else {
            expandImmediately(to: .palette)
            commandPaletteViewModel.requestFocus()
        }
    }

    public func toggleNotchAlwaysDisplayed() {
        withAnimation(Self.springAnimation) {
            notchDisplayMode = (notchDisplayMode == .always) ? .offWhenIdle : .always
        }
    }

    public func setNotchDisplayMode(_ mode: NotchDisplayMode) {
        withAnimation(Self.springAnimation) {
            notchDisplayMode = mode
        }
    }

    public func toggleCompactWingsMode() {
        withAnimation(Self.springAnimation) {
            isCompactWingsEnabled.toggle()
            if isCompactWingsEnabled && notchDisplayMode != .always {
                notchDisplayMode = .always
            }
        }
    }

    public func toggleMenuBarIcon() {
        isMenuBarIconEnabled.toggle()
    }

    public func selectTab(_ tab: NotchTab) {
        if selectedTab == .mirror && tab != .mirror {
            cameraService.stopSession()
        } else if tab == .mirror {
            cameraService.startSession()
        }
        selectedTab = tab
    }

    public func showBanner(_ banner: NotchBanner, duration: TimeInterval = 3.5) {
        bannerDismissTask?.cancel()
        withAnimation(Self.springAnimation) {
            self.activeBanner = banner
            if self.expansionState == .collapsed {
                self.expansionState = .compactWings
            }
        }
        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            withAnimation(Self.springAnimation) {
                self.activeBanner = nil
                if self.expansionState != .expanded {
                    self.expansionState = self.restingState
                }
            }
        }
    }

    public func expandImmediately(to tab: NotchTab? = nil) {
        if notchDisplayMode == .completelyOff {
            notchDisplayMode = .offWhenIdle
        }
        cancelHoverExpansion()
        cancelCollapseTimer()
        withAnimation(Self.springAnimation) {
            if let tab {
                selectTab(tab)
            }
            expansionState = .expanded
        }
    }

    public func collapseImmediately() {
        cancelHoverExpansion()
        cancelCollapseTimer()
        if selectedTab == .mirror {
            cameraService.stopSession()
        }
        withAnimation(Self.springAnimation) {
            expansionState = restingState
        }
    }

    private func scheduleHoverExpansion() {
        guard notchDisplayMode != .completelyOff, expansionState != .expanded else { return }
        hoverExpandTask?.cancel()
        hoverExpandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self, self.isHoveringNotch, self.notchDisplayMode != .completelyOff else { return }
            withAnimation(Self.springAnimation) {
                self.expansionState = .expanded
            }
        }
    }

    private func cancelHoverExpansion() {
        hoverExpandTask?.cancel()
        hoverExpandTask = nil
    }

    private func scheduleExitCollapse() {
        guard expansionState == .expanded, !isDraggingOverScreenTop else { return }
        exitCollapseTask?.cancel()
        exitCollapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self, !self.isHoveringNotch, !self.isDraggingOverScreenTop else { return }
            withAnimation(Self.springAnimation) {
                if self.selectedTab == .mirror {
                    self.cameraService.stopSession()
                }
                self.expansionState = self.restingState
            }
        }
    }

    private func cancelCollapseTimer() {
        exitCollapseTask?.cancel()
        exitCollapseTask = nil
    }
}
