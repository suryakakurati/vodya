import AppKit
import Carbon.HIToolbox
import Foundation

/// System-wide hotkeys through Carbon's `RegisterEventHotKey`, which needs no
/// Accessibility or Input Monitoring permission (unlike an event tap or an
/// NSEvent global monitor).
///
/// A single event handler serves every hotkey and dispatches by id. Keeping the
/// lookup here, rather than a per-instance pointer in the Carbon user-data,
/// means nothing can go stale between registration and a key press.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private let signature = OSType(0x564F4459) // 'VODY'
    private var actions: [UInt32: () -> Void] = [:]
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handlerInstalled = false

    @discardableResult
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        unregister(id: id)

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            NSLog("Vodya: RegisterEventHotKey failed for id \(id) (status \(status))")
            return false
        }

        references[id] = reference
        actions[id] = action
        return true
    }

    func unregister(id: UInt32) {
        if let reference = references.removeValue(forKey: id) {
            UnregisterEventHotKey(reference)
        }
        actions.removeValue(forKey: id)
    }

    func unregisterAll() {
        for id in Array(references.keys) {
            unregister(id: id)
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressed
                )
                guard status == noErr else { return status }

                let id = pressed.id
                DispatchQueue.main.async {
                    NSLog("Vodya: hotkey id=\(id) fired")
                    HotKeyCenter.shared.actions[id]?()
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            nil
        )
    }
}
