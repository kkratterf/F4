/// The F4 key of a Mac keyboard when it is a media key.
///
/// Unless "Use F1, F2, etc. keys as standard function keys" is on, the key in
/// the F4 position does not send F4 (`kVK_F4`): it opens Spotlight on Apple
/// keyboards since 2021, Launchpad on older ones, Dashboard on the oldest.
/// A Carbon hot key never sees those presses, so the optional "F4 without fn"
/// setting catches them with an event tap, which needs Accessibility. These
/// are the rules the tap follows; the tap itself lives in the app.
public enum MediaF4Key {
    /// Virtual key codes the F4 position sends without fn: Spotlight (0xB1),
    /// Launchpad (0x83) and Dashboard (0x82). macOS has no `kVK_` names for them.
    public static let keyCodes: Set<Int> = [0xB1, 0x83, 0x82]

    /// `NX_KEYTYPE_LAUNCH_PANEL`: some keyboards send Launchpad as a
    /// system-defined media key event instead of a key code.
    public static let launchpadMediaKey = 13

    /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`, the subtype of system-defined media key events.
    public static let mediaKeySubtype = 8

    public static func isMediaF4(keyCode: Int) -> Bool {
        keyCodes.contains(keyCode)
    }

    /// A media key press, decoded from `data1` of a system-defined event of
    /// subtype `mediaKeySubtype`: the key in the high 16 bits, then the
    /// state (0xA down, 0xB up) and a repeat bit.
    public struct MediaKeyPress: Equatable {
        public let key: Int
        public let isDown: Bool
        public let isRepeat: Bool

        public init(data1: Int) {
            key = (data1 & 0xFFFF_0000) >> 16
            isDown = (data1 & 0xFF00) >> 8 == 0xA
            isRepeat = data1 & 0x1 != 0
        }
    }

    /// Whether F4 should catch the media F4 key: the user turned the setting
    /// on, the shortcut is F4 alone, and the top row sends media keys (with
    /// standard function keys the plain F4 key already reaches the hot key).
    public static func shouldCatch(settingIsOn: Bool, shortcutKeyCode: Int, shortcutModifiers: Int, functionKeysAreStandard: Bool) -> Bool {
        settingIsOn
            && shortcutKeyCode == ShortcutRules.f4KeyCode
            && shortcutModifiers == 0
            && !functionKeysAreStandard
    }
}
