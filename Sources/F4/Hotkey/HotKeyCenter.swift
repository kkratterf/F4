import AppKit
import Carbon.HIToolbox
import F4Core

/// A global keyboard shortcut: a virtual key code (`kVK_*`) plus Carbon
/// modifier flags (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`).
struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// The F4 key alone, the default shortcut that shows and hides the panel.
    /// On a Mac keyboard F4 is a media key (Spotlight or Launchpad) unless the
    /// user holds fn or uses F1, F2, etc. as standard function keys: Carbon
    /// only sees the press as F4 then. Settings says so under the recorder.
    static let toggleDefault = HotKeyCombo(keyCode: ShortcutRules.f4KeyCode, modifiers: 0)

    init(keyCode: Int, modifiers: UInt32) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = modifiers
    }

    /// The combo of a key press, or nil when it cannot be a global shortcut:
    /// a key without ⌘, ⌥ or ⌃ would steal normal typing, except a function
    /// key (F1 to F20), which types nothing. fn is not part of the combo.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        let keyCode = Int(event.keyCode)
        guard ShortcutRules.canRecord(keyCode: keyCode, hasCommandOptionOrControl: modifiers != 0) else { return nil }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    /// A function key with no modifier, like the default F4. On a Mac
    /// keyboard it may need fn (see `toggleDefault`).
    var isBareFunctionKey: Bool {
        modifiers == 0 && ShortcutRules.isFunctionKey(Int(keyCode))
    }

    /// Human readable form in the macOS order, e.g. "⌃⌥⌘P".
    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + HotKeyCombo.keyName(Int(keyCode))
    }

    private static func keyName(_ keyCode: Int) -> String {
        let letters: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
            kVK_Return: "↩", kVK_Space: String(localized: "Space"), kVK_Tab: "⇥",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
            kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
            kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
            kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Minus: "-",
            kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        ]
        return letters[keyCode] ?? "#\(keyCode)"
    }
}

/// Registers system-wide hot keys with Carbon `RegisterEventHotKey`.
///
/// Unlike `NSEvent.addGlobalMonitorForEvents`, this needs no Accessibility
/// or Input Monitoring permission. Every registration has a string id, so
/// independent features can each own their shortcuts:
///
///     HotKeyCenter.shared.register(id: "togglePanel", combo: combo) { ... }
///     HotKeyCenter.shared.unregister(id: "togglePanel")
///
/// Registering an id again replaces its previous combo and action.
/// Use it from the main thread only; actions run on the main thread.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// Four-char code that marks our hot keys ("F4HK"), so events for hot
    /// keys registered by other code are passed on untouched.
    fileprivate static let signature: OSType = 0x4634_484B

    private struct Registration {
        let numericID: UInt32
        let ref: EventHotKeyRef
        let combo: HotKeyCombo
        let action: () -> Void
    }

    private var registrations: [String: Registration] = [:]
    private var nextNumericID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// The combo currently registered for `id`, if any.
    func combo(for id: String) -> HotKeyCombo? {
        registrations[id]?.combo
    }

    /// Registers `combo` under `id`. Returns false when macOS refuses it,
    /// usually because another app already owns the same combination.
    @discardableResult
    func register(id: String, combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        unregister(id: id)
        guard installEventHandlerIfNeeded() else { return false }

        let numericID = nextNumericID
        nextNumericID += 1
        let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: numericID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[id] = Registration(numericID: numericID, ref: ref, combo: combo, action: action)
        return true
    }

    func unregister(id: String) {
        guard let registration = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(registration.ref)
    }

    func unregisterAll() {
        for id in Array(registrations.keys) {
            unregister(id: id)
        }
    }

    /// Called by the Carbon handler. Returns true when the hot key is ours.
    fileprivate func handle(numericID: UInt32) -> Bool {
        guard let registration = registrations.values.first(where: { $0.numericID == numericID }) else {
            return false
        }
        registration.action()
        return true
    }

    private func installEventHandlerIfNeeded() -> Bool {
        if eventHandler != nil { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            nil,
            &handler
        )
        guard status == noErr, let handler else { return false }
        eventHandler = handler
        return true
    }
}

/// Carbon callback for `kEventHotKeyPressed`. A plain function, because a C
/// function pointer cannot capture context.
private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
        return OSStatus(eventNotHandledErr)
    }
    return HotKeyCenter.shared.handle(numericID: hotKeyID.id) ? noErr : OSStatus(eventNotHandledErr)
}
