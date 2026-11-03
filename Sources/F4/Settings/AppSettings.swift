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
        static let pasteAfterCopy = "pasteAfterCopy"
        static let showStarterPack = "showStarterPack"
        static let searchGiphy = "searchGiphy"
        static let giphyAPIKey = "giphyAPIKey"
        static let showInMenuBar = "showInMenuBar"
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

    /// Send ⌘V to the frontmost app after copying. Needs Accessibility; off by default.
    @Published var pasteAfterCopy: Bool {
        didSet { defaults.set(pasteAfterCopy, forKey: Key.pasteAfterCopy) }
    }

    /// Show the GIFs and stickers built into F4 next to the user's own. On by default.
    @Published var showStarterPack: Bool {
        didSet { defaults.set(showStarterPack, forKey: Key.showStarterPack) }
    }

    /// Show the GIPHY row in the GIFs and Stickers tabs. On by default; it
    /// only appears when the build (or the user) has a GIPHY API key.
    @Published var searchGiphy: Bool {
        didSet { defaults.set(searchGiphy, forKey: Key.searchGiphy) }
    }

    /// The user's own GIPHY API key, used instead of the built-in one. Empty for none.
    @Published var giphyAPIKey: String {
        didSet { defaults.set(giphyAPIKey, forKey: Key.giphyAPIKey) }
    }

    /// The menu bar icon. On by default; with it off, opening F4 again
    /// (Finder, Spotlight) shows Settings, so the user can always get back.
    @Published var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: Key.showInMenuBar) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showStarterPack = defaults.object(forKey: Key.showStarterPack) as? Bool ?? true
        searchGiphy = defaults.object(forKey: Key.searchGiphy) as? Bool ?? true
        giphyAPIKey = defaults.string(forKey: Key.giphyAPIKey) ?? ""
        pasteAfterCopy = defaults.bool(forKey: Key.pasteAfterCopy)
        showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? true
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
