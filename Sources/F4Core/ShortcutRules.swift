/// Which key presses can become the global shortcut.
public enum ShortcutRules {
    /// Virtual key codes of F1 to F20, the values of Carbon's `kVK_F1` ...
    /// `kVK_F20`, spelled out because F4Core does not import Carbon.
    public static let functionKeyCodes: Set<Int> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, // F1 ... F10
        103, 111, 105, 107, 113, 106, 64, 79, 80, 90, // F11 ... F20
    ]

    /// The virtual key code of F4 (`kVK_F4`), the default shortcut.
    public static let f4KeyCode = 118

    public static func isFunctionKey(_ keyCode: Int) -> Bool {
        functionKeyCodes.contains(keyCode)
    }

    /// Whether a key press can be recorded as the global shortcut. A letter,
    /// digit or symbol needs ⌘, ⌥ or ⌃: alone (or with only ⇧) it would steal
    /// normal typing. A function key types nothing, so it works on its own.
    public static func canRecord(keyCode: Int, hasCommandOptionOrControl: Bool) -> Bool {
        hasCommandOptionOrControl || isFunctionKey(keyCode)
    }
}
