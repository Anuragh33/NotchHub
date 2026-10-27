import AppKit
import Combine

@MainActor
public struct NotchGeometry: Equatable, Sendable {
    public let hasPhysicalNotch: Bool
    public let notchFrame: CGRect      // In screen coordinates (origin bottom-left)
    public let notchSize: CGSize       // Physical or fallback pill size
    public let screenFrame: CGRect     // Full frame of the active screen
    public let menuBarHeight: CGFloat

    public static let fallbackWidth: CGFloat = 184.0
    public static let fallbackHeight: CGFloat = 32.0
}

@MainActor
public final class ScreenGeometryManager: ObservableObject {
    @Published public private(set) var currentGeometry: NotchGeometry

    private var cancellables = Set<AnyCancellable>()

    public init() {
        let initialScreen = Self.resolveActiveScreen()
        self.currentGeometry = Self.calculateGeometry(for: initialScreen)
        setupNotificationObserver()
    }

    public func refreshGeometry(preferring screen: NSScreen? = nil) {
        let targetScreen = screen ?? Self.resolveActiveScreen()
        let updated = Self.calculateGeometry(for: targetScreen)
        if updated != currentGeometry {
            currentGeometry = updated
        }
    }

    public static func resolveActiveScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screenWithMouse
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    public static func calculateGeometry(for screen: NSScreen?) -> NotchGeometry {
        guard let screen else {
            let fallbackSize = CGSize(width: NotchGeometry.fallbackWidth, height: NotchGeometry.fallbackHeight)
            let defaultScreen = CGRect(x: 0, y: 0, width: 1512, height: 982)
            let notchFrame = CGRect(
                x: defaultScreen.midX - fallbackSize.width / 2.0,
                y: defaultScreen.maxY - fallbackSize.height,
                width: fallbackSize.width,
                height: fallbackSize.height
            )
            return NotchGeometry(
                hasPhysicalNotch: false,
                notchFrame: notchFrame,
                notchSize: fallbackSize,
                screenFrame: defaultScreen,
                menuBarHeight: fallbackSize.height
            )
        }

        let screenFrame = screen.frame
        let safeTop = screen.safeAreaInsets.top

        // Physical notch detection via safeAreaInsets + auxiliaryTopLeftArea & auxiliaryTopRightArea
        if safeTop > 0,
           let leftAux = screen.auxiliaryTopLeftArea,
           let rightAux = screen.auxiliaryTopRightArea {
            let notchLeftX = leftAux.maxX
            let notchRightX = rightAux.minX
            let calculatedWidth = max(120.0, notchRightX - notchLeftX)
            let calculatedHeight = max(28.0, safeTop)

            let notchFrame = CGRect(
                x: notchLeftX,
                y: screenFrame.maxY - calculatedHeight,
                width: calculatedWidth,
                height: calculatedHeight
            )

            return NotchGeometry(
                hasPhysicalNotch: true,
                notchFrame: notchFrame,
                notchSize: CGSize(width: calculatedWidth, height: calculatedHeight),
                screenFrame: screenFrame,
                menuBarHeight: calculatedHeight
            )
        }

        // Fallback pill geometry at top center for external displays or non-notch MacBooks
        let visibleMaxY = screen.visibleFrame.maxY
        let inferredMenuBarHeight = max(24.0, screenFrame.maxY - visibleMaxY)
        let pillWidth = NotchGeometry.fallbackWidth
        let pillHeight = min(max(inferredMenuBarHeight, 30.0), 36.0)
        let pillX = screenFrame.midX - (pillWidth / 2.0)
        let pillY = screenFrame.maxY - pillHeight

        let pillFrame = CGRect(
            x: pillX,
            y: pillY,
            width: pillWidth,
            height: pillHeight
        )

        return NotchGeometry(
            hasPhysicalNotch: false,
            notchFrame: pillFrame,
            notchSize: CGSize(width: pillWidth, height: pillHeight),
            screenFrame: screenFrame,
            menuBarHeight: inferredMenuBarHeight
        )
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshGeometry()
            }
            .store(in: &cancellables)
    }
}
