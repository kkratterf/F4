import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Sends ⌘V to the frontmost app, so a picked meme lands in the chat at once.
///
/// Optional and off by default: posting key events needs the Accessibility
/// permission. Without it F4 only copies, exactly as before.
enum AutoPaster {
    /// Whether macOS lets F4 post key events.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show its Accessibility prompt for F4, if not trusted yet.
    @discardableResult
    static func requestTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Pastes after a short delay, once the panel is gone and the previous
    /// app is key again. Does nothing without the permission.
    static func pasteSoon(delay: TimeInterval = 0.12) {
        guard isTrusted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyV = CGKeyCode(kVK_ANSI_V)
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
