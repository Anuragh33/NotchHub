import AppKit
import Combine

@MainActor
public final class NotchEventMonitor {
    public var onMouseMoved: ((CGPoint) -> Void)?
    public var onOutsideMouseDown: ((CGPoint) -> Void)?
    public var onDragNearTop: ((CGPoint) -> Void)?
    public var onDragEnded: (() -> Void)?

    nonisolated(unsafe) private var globalMouseMoveMonitor: Any?
    nonisolated(unsafe) private var localMouseMoveMonitor: Any?
    nonisolated(unsafe) private var globalMouseDownMonitor: Any?
    nonisolated(unsafe) private var globalMouseDragMonitor: Any?
    nonisolated(unsafe) private var globalMouseUpMonitor: Any?

    private var lastObservedDragPasteboardCount: Int = NSPasteboard(name: .drag).changeCount
    private var isSystemDragActive: Bool = false

    public init() {}

    public func startMonitoring() {
        stopMonitoring()

        lastObservedDragPasteboardCount = NSPasteboard(name: .drag).changeCount

        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.onMouseMoved?(point)
            }
        }

        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            let point = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.onMouseMoved?(point)
            }
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.lastObservedDragPasteboardCount = NSPasteboard(name: .drag).changeCount
                self?.onOutsideMouseDown?(point)
            }
        }

        globalMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self else { return }
                let dragPasteboard = NSPasteboard(name: .drag)
                let hasDragItems = dragPasteboard.changeCount != self.lastObservedDragPasteboardCount ||
                    !(dragPasteboard.types?.isEmpty ?? true)

                if hasDragItems {
                    self.isSystemDragActive = true
                    self.onDragNearTop?(point)
                }
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isSystemDragActive {
                    self.isSystemDragActive = false
                    self.lastObservedDragPasteboardCount = NSPasteboard(name: .drag).changeCount
                    self.onDragEnded?()
                }
            }
        }
    }

    public func stopMonitoring() {
        if let monitor = globalMouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMoveMonitor = nil
        }
        if let monitor = localMouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMoveMonitor = nil
        }
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let monitor = globalMouseDragMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDragMonitor = nil
        }
        if let monitor = globalMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseUpMonitor = nil
        }
    }

    deinit {
        if let m1 = globalMouseMoveMonitor { NSEvent.removeMonitor(m1) }
        if let m2 = localMouseMoveMonitor { NSEvent.removeMonitor(m2) }
        if let m3 = globalMouseDownMonitor { NSEvent.removeMonitor(m3) }
        if let m4 = globalMouseDragMonitor { NSEvent.removeMonitor(m4) }
        if let m5 = globalMouseUpMonitor { NSEvent.removeMonitor(m5) }
    }
}
