import AppKit
import SwiftUI

@MainActor
public protocol NotchPanelTrackingDelegate: AnyObject {
    func panelMouseDidEnter()
    func panelMouseDidExit()
    func panelMouseDidMove(at screenPoint: CGPoint)
    func panelDraggingDidEnter(_ sender: NSDraggingInfo) -> NSDragOperation
    func panelDraggingDidExit(_ sender: NSDraggingInfo?)
    func panelPerformDragOperation(_ sender: NSDraggingInfo) -> Bool
}

@MainActor
public final class NotchTrackingContainerView: NSView {
    public weak var trackingDelegate: NotchPanelTrackingDelegate?
    private var trackingArea: NSTrackingArea?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        trackingDelegate?.panelMouseDidEnter()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        trackingDelegate?.panelMouseDidExit()
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        trackingDelegate?.panelMouseDidMove(at: NSEvent.mouseLocation)
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return trackingDelegate?.panelDraggingDidEnter(sender) ?? .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        trackingDelegate?.panelDraggingDidExit(sender)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return trackingDelegate?.panelPerformDragOperation(sender) ?? false
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

@MainActor
public final class NotchPanel: NSPanel {
    public let trackingContainerView = NotchTrackingContainerView(frame: .zero)

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none

        trackingContainerView.frame = NSRect(origin: .zero, size: contentRect.size)
        trackingContainerView.autoresizingMask = [.width, .height]
        contentView = trackingContainerView
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public func installSwiftUIView<Content: View>(_ rootView: Content) {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = trackingContainerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        trackingContainerView.subviews.forEach { $0.removeFromSuperview() }
        trackingContainerView.addSubview(hostingView)
    }
}
