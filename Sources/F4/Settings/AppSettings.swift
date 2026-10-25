import F4Core
import Foundation

/// User preferences, stored in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let memeFolder = "memeFolderPath"
    }

    private let defaults: UserDefaults

    /// The folder F4 reads memes from. `~/Pictures/Memes` until the user picks another.
    @Published var memeFolder: URL {
        didSet { defaults.set(memeFolder.path(percentEncoded: false), forKey: Key.memeFolder) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let path = defaults.string(forKey: Key.memeFolder), !path.isEmpty {
            memeFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            memeFolder = MemeScanner.defaultFolder
        }
    }

    var isUsingDefaultFolder: Bool {
        memeFolder.standardizedFileURL == MemeScanner.defaultFolder.standardizedFileURL
    }
}
