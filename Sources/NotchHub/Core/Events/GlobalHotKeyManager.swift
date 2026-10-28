import AppKit
import Carbon

/// Registers a system-wide hot key (default ⌃⌥K) using Carbon's RegisterEventHotKey,
/// which works without Accessibility permissions.
@MainActor
public final class GlobalHotKeyManager {
    nonisolated(unsafe) fileprivate static var action: (@MainActor () -> Void)?

    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?

    public init() {}

    public func register(keyCode: UInt32 = UInt32(kVK_ANSI_K),
                         modifiers: UInt32 = UInt32(controlKey | optionKey),
                         action: @escaping @MainActor () -> Void) {
        unregister()
        Self.action = action

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in
                    GlobalHotKeyManager.action?()
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E544348), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    public func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = handlerRef { RemoveEventHandler(ref); handlerRef = nil }
    }
}
