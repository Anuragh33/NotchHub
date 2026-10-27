import AppKit
import Combine
import SwiftUI

public enum NotchExpansionState: String, Equatable, Sendable {
    case collapsed
    case compactWings
    case expanded
}

public enum NotchTab: String, CaseIterable, Identifiable, Sendable {
    case aiUsage = "AI Usage"
    case timer = "Pomodoro Timer"
    case shelf = "Drop Shelf"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .aiUsage: return "sparkles"
        case .timer: return "timer"
        case .shelf: return "tray.and.arrow.down.fill"
        }
    }
}

@MainActor
public final class NotchViewModel: ObservableObject {
    private static let menuBarIconStorageKey = "com.notchhub.menubar.enabled"
    private static let compactWingsStorageKey = "com.notchhub.compactwings.enabled"

    @Published public private(set) var expansionState: NotchExpansionState = .compactWings
    @Published public var selectedTab: NotchTab = .aiUsage
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

    public static let springAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.78)

    public let geometryManager: ScreenGeometryManager
    public let aiUsageViewModel: AIUsageViewModel
    public let shelfViewModel: ShelfViewModel
    public let utilitiesViewModel: UtilitiesViewModel

    private var hoverExpandTask: Task<Void, Never>?
    private var exitCollapseTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(
        geometryManager: ScreenGeometryManager = ScreenGeometryManager(),
        aiUsageViewModel: AIUsageViewModel = AIUsageViewModel(),
        shelfViewModel: ShelfViewModel = ShelfViewModel(),
        utilitiesViewModel: UtilitiesViewModel = UtilitiesViewModel()
    ) {
        self.geometryManager = geometryManager
        self.aiUsageViewModel = aiUsageViewModel
        self.shelfViewModel = shelfViewModel
        self.utilitiesViewModel = utilitiesViewModel

        let savedWings = UserDefaults.standard.object(forKey: Self.compactWingsStorageKey) as? Bool ?? true
        let savedMenuBar = UserDefaults.standard.object(forKey: Self.menuBarIconStorageKey) as? Bool ?? true
        self.isCompactWingsEnabled = savedWings
        self.isMenuBarIconEnabled = savedMenuBar
        self.expansionState = savedWings ? .compactWings : .collapsed

        geometryManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var restingState: NotchExpansionState {
        isCompactWingsEnabled ? .compactWings : .collapsed
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
            let wingsExtraWidth: CGFloat = 148.0
            return CGSize(
                width: base.width + wingsExtraWidth + (topEarRadius * 2.0),
                height: max(base.height, 34.0)
            )
        case .expanded:
            return CGSize(
                width: max(540.0, base.width + 340.0) + (topEarRadius * 2.0),
                height: 256.0
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

    public func toggleCompactWingsMode() {
        withAnimation(Self.springAnimation) {
            isCompactWingsEnabled.toggle()
        }
    }

    public func toggleMenuBarIcon() {
        isMenuBarIconEnabled.toggle()
    }

    public func expandImmediately(to tab: NotchTab? = nil) {
        cancelHoverExpansion()
        cancelCollapseTimer()
        withAnimation(Self.springAnimation) {
            if let tab {
                selectedTab = tab
            }
            expansionState = .expanded
        }
    }

    public func collapseImmediately() {
        cancelHoverExpansion()
        cancelCollapseTimer()
        withAnimation(Self.springAnimation) {
            expansionState = restingState
        }
    }

    private func scheduleHoverExpansion() {
        guard expansionState != .expanded else { return }
        hoverExpandTask?.cancel()
        hoverExpandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self, self.isHoveringNotch else { return }
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
                self.expansionState = self.restingState
            }
        }
    }

    private func cancelCollapseTimer() {
        exitCollapseTask?.cancel()
        exitCollapseTask = nil
    }
}
