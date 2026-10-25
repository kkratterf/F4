import F4Core
import Foundation

/// User preferences, stored in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let memeFolder = "memeFolderPath"
        static let shortcutKeyCode = "toggleShortcutKeyCode"
        static let shortcutModifiers = "toggleShortcutModifiers"
    }

    private let defaults: UserDefaults

    /// The folder F4 reads memes from. `~/Pictures/Memes` until the user picks another.
    @Published var memeFolder: URL {
        didSet { defaults.set(memeFolder.path(percentEncoded: false), forKey: Key.memeFolder) }
    }

    /// The global shortcut that shows and hides the panel.
    @Published var toggleShortcut: HotKeyCombo {
        didSet {
            defaults.set(Int(toggleShortcut.keyCode), forKey: Key.shortcutKeyCode)
            defaults.set(Int(toggleShortcut.modifiers), forKey: Key.shortcutModifiers)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let path = defaults.string(forKey: Key.memeFolder), !path.isEmpty {
            memeFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            memeFolder = MemeScanner.defaultFolder
        }
        if defaults.object(forKey: Key.shortcutKeyCode) != nil {
            toggleShortcut = HotKeyCombo(
                keyCode: defaults.integer(forKey: Key.shortcutKeyCode),
                modifiers: UInt32(defaults.integer(forKey: Key.shortcutModifiers))
            )
        } else {
            toggleShortcut = .toggleDefault
        }
    }

    var isUsingDefaultFolder: Bool {
        memeFolder.standardizedFileURL == MemeScanner.defaultFolder.standardizedFileURL
    }
}
