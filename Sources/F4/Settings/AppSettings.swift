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
        static let didSeedLibrary = "didSeedLibrary"
    }

    private let defaults: UserDefaults

    /// The folder F4 reads memes from: F4's own library
    /// (`~/Library/Application Support/F4/Memes`) until the user picks
    /// another, or `~/Pictures/Memes` for someone upgrading who has memes there.
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

    /// Whether the starter pack was already copied into F4's own library. It
    /// is copied once: memes the user deletes stay deleted.
    var didSeedLibrary: Bool {
        get { defaults.bool(forKey: Key.didSeedLibrary) }
        set { defaults.set(newValue, forKey: Key.didSeedLibrary) }
    }

    /// Show the stickers built into F4 after the stickers of a folder
    /// other than F4's own library (which holds a copy of them). On by default.
    @Published var showStarterPack: Bool {
        didSet { defaults.set(showStarterPack, forKey: Key.showStarterPack) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showStarterPack = defaults.object(forKey: Key.showStarterPack) as? Bool ?? true
        pasteAfterCopy = defaults.bool(forKey: Key.pasteAfterCopy)
        let initial = LibraryFolders.initialFolder(
            savedPath: defaults.string(forKey: Key.memeFolder),
            legacyHasMemes: Self.hasMemes(LibraryFolders.legacyFolder())
        )
        memeFolder = initial.url
        if defaults.object(forKey: Key.shortcutKeyCode) != nil {
            toggleShortcut = HotKeyCombo(
                keyCode: defaults.integer(forKey: Key.shortcutKeyCode),
                modifiers: UInt32(defaults.integer(forKey: Key.shortcutModifiers))
            )
        } else {
            toggleShortcut = .toggleDefault
        }
        if initial.persist {
            // Keep reading ~/Pictures/Memes even if it is emptied later.
            defaults.set(initial.url.path(percentEncoded: false), forKey: Key.memeFolder)
        }
    }

    /// Whether `folder` holds anything besides hidden files: a quick look at
    /// the top level only, done once at launch.
    private static func hasMemes(_ folder: URL) -> Bool {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return entries.contains { !$0.hasPrefix(".") }
    }

    var isUsingDefaultFolder: Bool {
        memeFolder.standardizedFileURL == MemeScanner.defaultFolder.standardizedFileURL
    }
}
