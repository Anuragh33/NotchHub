import AppKit
import Combine
import SwiftUI

@MainActor
public final class NotchWindowController: NSObject, NotchPanelTrackingDelegate {
    public let panel: NotchPanel
    public let viewModel: NotchViewModel
    private let eventMonitor: NotchEventMonitor
    private var cancellables = Set<AnyCancellable>()

    private static let canvasWidth: CGFloat = 660.0
    private static let canvasHeight: CGFloat = 310.0

    public init(
        viewModel: NotchViewModel = NotchViewModel(),
        eventMonitor: NotchEventMonitor = NotchEventMonitor()
    ) {
        self.viewModel = viewModel
        self.eventMonitor = eventMonitor

        let initialRect = Self.calculateCanvasFrame(for: viewModel.geometryManager.currentGeometry)
        self.panel = NotchPanel(contentRect: initialRect)

        super.init()

        self.panel.trackingContainerView.trackingDelegate = self
        let rootView = NotchContainerView(viewModel: viewModel)
        self.panel.installSwiftUIView(rootView)

        bindStateAndGeometry()
        setupEventMonitorCallbacks()
    }

    public func showWindow() {
        repositionPanel(for: viewModel.geometryManager.currentGeometry)
        panel.orderFrontRegardless()
        eventMonitor.startMonitoring()
    }

    private func bindStateAndGeometry() {
        viewModel.geometryManager.$currentGeometry
            .receive(on: RunLoop.main)
            .sink { [weak self] geometry in
                self?.repositionPanel(for: geometry)
            }
            .store(in: &cancellables)

        viewModel.$expansionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                // Ensure hasShadow is strictly false in collapsed state to prevent visual seams
                self.panel.hasShadow = false
                self.updateMousePassthrough(at: NSEvent.mouseLocation)
                if state == .collapsed {
                    self.panel.resignKey()
                }
            }
            .store(in: &cancellables)
    }

    private func setupEventMonitorCallbacks() {
        eventMonitor.onMouseMoved = { [weak self] point in
            guard let self else { return }
            self.updateMousePassthrough(at: point)
            self.viewModel.handleCursorMoved(at: point)
        }

        eventMonitor.onOutsideMouseDown = { [weak self] point in
            guard let self else { return }
            self.viewModel.handleOutsideClick(at: point)
        }

        eventMonitor.onDragNearTop = { [weak self] point in
            guard let self else { return }
            self.panel.ignoresMouseEvents = false
            self.viewModel.handleSystemDrag(at: point)
        }

        eventMonitor.onDragEnded = { [weak self] in
            guard let self else { return }
            self.viewModel.handleSystemDragEnded()
            self.updateMousePassthrough(at: NSEvent.mouseLocation)
        }
    }

    private func updateMousePassthrough(at screenPoint: CGPoint) {
        if viewModel.isDraggingOverScreenTop {
            if panel.ignoresMouseEvents {
                panel.ignoresMouseEvents = false
            }
            return
        }

        let interactiveRect = viewModel.activeInteractiveScreenRect().insetBy(dx: -8.0, dy: -6.0)
        let shouldCaptureMouse = NSMouseInRect(screenPoint, interactiveRect, false)
        if panel.ignoresMouseEvents == shouldCaptureMouse {
            panel.ignoresMouseEvents = !shouldCaptureMouse
        }
    }

    private func repositionPanel(for geometry: NotchGeometry) {
        let targetFrame = Self.calculateCanvasFrame(for: geometry)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private static func calculateCanvasFrame(for geometry: NotchGeometry) -> NSRect {
        let x = geometry.notchFrame.midX - (canvasWidth / 2.0)
        let y = geometry.screenFrame.maxY - canvasHeight
        return NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
    }

    // MARK: - NotchPanelTrackingDelegate

    public func panelMouseDidEnter() {
        let point = NSEvent.mouseLocation
        updateMousePassthrough(at: point)
        if !panel.ignoresMouseEvents {
            viewModel.handleMouseEnteredPanel()
        }
    }

    public func panelMouseDidExit() {
        viewModel.handleMouseExitedPanel()
        updateMousePassthrough(at: NSEvent.mouseLocation)
    }

    public func panelMouseDidMove(at screenPoint: CGPoint) {
        updateMousePassthrough(at: screenPoint)
        viewModel.handleCursorMoved(at: screenPoint)
    }

    public func panelDraggingDidEnter(_ sender: NSDraggingInfo) -> NSDragOperation {
        panel.ignoresMouseEvents = false
        viewModel.shelfViewModel.isDropTargeted = true
        viewModel.expandImmediately(to: .shelf)
        return .copy
    }

    public func panelDraggingDidExit(_ sender: NSDraggingInfo?) {
        viewModel.shelfViewModel.isDropTargeted = false
    }

    public func panelPerformDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let accepted = viewModel.shelfViewModel.handlePasteboardDrop(pasteboard)
        viewModel.shelfViewModel.isDropTargeted = false
        viewModel.expandImmediately(to: .shelf)
        return accepted
    }
}
