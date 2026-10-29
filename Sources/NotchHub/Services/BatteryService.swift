import Foundation
import IOKit.ps

public struct BatteryState: Equatable, Sendable {
    public let currentCapacity: Int
    public let maxCapacity: Int
    public let percentage: Int
    public let isCharging: Bool
    public let isACConnected: Bool
    public let timeToFullCharge: Int // in minutes, -1 if unknown
    public let timeToEmpty: Int      // in minutes, -1 if unknown

    public static let `default` = BatteryState(
        currentCapacity: 100,
        maxCapacity: 100,
        percentage: 100,
        isCharging: false,
        isACConnected: true,
        timeToFullCharge: -1,
        timeToEmpty: -1
    )

    public var batterySymbol: String {
        if isCharging {
            return "bolt.badge.checkmark.fill"
        }
        switch percentage {
        case 90...100: return "battery.100percent"
        case 70..<90: return "battery.75percent"
        case 40..<70: return "battery.50percent"
        case 15..<40: return "battery.25percent"
        default: return "battery.0percent"
        }
    }
}

@MainActor
public final class BatteryService: ObservableObject {
    public static let shared = BatteryService()

    @Published public private(set) var currentState: BatteryState = .default

    public var onChargingConnected: ((Int) -> Void)?
    public var onChargingDisconnected: ((Int) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var previousACConnected: Bool = true

    public init() {
        refreshBatteryState()
        startMonitoring()
    }

    public func startMonitoring() {
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.refreshBatteryState()
            }
        }

        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(callback, unmanagedSelf)?.takeRetainedValue() {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }

    public func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    public func refreshBatteryState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let curCap = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
            let maxCap = (desc[kIOPSMaxCapacityKey] as? Int) ?? 100
            let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            let pwrState = (desc[kIOPSPowerSourceStateKey] as? String) ?? ""
            let isAC = (pwrState == kIOPSACPowerValue)

            let timeFull = (desc[kIOPSTimeToFullChargeKey] as? Int) ?? -1
            let timeEmpty = (desc[kIOPSTimeToEmptyKey] as? Int) ?? -1

            let pct = maxCap > 0 ? Int((Double(curCap) / Double(maxCap)) * 100.0) : 100

            let newState = BatteryState(
                currentCapacity: curCap,
                maxCapacity: maxCap,
                percentage: pct,
                isCharging: isCharging,
                isACConnected: isAC,
                timeToFullCharge: timeFull,
                timeToEmpty: timeEmpty
            )

            // Detect MagSafe / USB-C plug-in transition
            if isAC && !previousACConnected {
                onChargingConnected?(pct)
            } else if !isAC && previousACConnected {
                onChargingDisconnected?(pct)
            }

            self.previousACConnected = isAC
            self.currentState = newState
            break
        }
    }
}
