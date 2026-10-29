import Foundation
import IOBluetooth

public struct ConnectedBluetoothDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isAudioDevice: Bool
    public let isAirPods: Bool
    public let batteryPercentage: Int?

    public var iconName: String {
        if isAirPods {
            return "airpodspro"
        } else if isAudioDevice {
            return "headphones"
        } else {
            return "wave.3.forward"
        }
    }
}

@MainActor
public final class BluetoothDeviceService: ObservableObject {
    public static let shared = BluetoothDeviceService()

    @Published public private(set) var connectedDevices: [ConnectedBluetoothDevice] = []

    public var onDeviceConnected: ((ConnectedBluetoothDevice) -> Void)?

    private var previousDeviceIDs: Set<String> = []

    public init() {
        refreshConnectedDevices()
        startMonitoring()
    }

    public func startMonitoring() {
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnectedNotification(_:device:))
        )
    }

    @objc nonisolated private func deviceConnectedNotification(_ notification: Any?, device: IOBluetoothDevice?) {
        guard let device else { return }
        let name = device.nameOrAddress
        let address = device.addressString ?? name
        let isAudio = (device.deviceClassMajor == 0x04)

        Task { @MainActor [weak self] in
            self?.refreshConnectedDevices()
            if let name {
                let isAirPods = name.localizedCaseInsensitiveContains("airpods")
                let item = ConnectedBluetoothDevice(
                    id: address ?? name,
                    name: name,
                    isAudioDevice: isAudio,
                    isAirPods: isAirPods,
                    batteryPercentage: nil
                )
                self?.onDeviceConnected?(item)
            }
        }
    }

    public func refreshConnectedDevices() {
        guard let devices = IOBluetoothDevice.recentDevices(0) as? [IOBluetoothDevice] else {
            connectedDevices = []
            return
        }

        let connected = devices.filter { $0.isConnected() }.map { dev -> ConnectedBluetoothDevice in
            let name = dev.nameOrAddress ?? "Bluetooth Device"
            let isAirPods = name.localizedCaseInsensitiveContains("airpods")
            let isAudio = (dev.deviceClassMajor == 0x04)

            return ConnectedBluetoothDevice(
                id: dev.addressString ?? name,
                name: name,
                isAudioDevice: isAudio,
                isAirPods: isAirPods,
                batteryPercentage: nil
            )
        }

        self.connectedDevices = connected
    }
}
