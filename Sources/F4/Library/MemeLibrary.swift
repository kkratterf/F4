import Foundation
import F4Core

/// The memes the panel shows, read from the meme folder in the background
/// and read again whenever the folder changes.
@MainActor
final class MemeLibrary: ObservableObject {
    @Published private(set) var memes: [Meme] = []
    /// Set when the folder cannot be read.
    @Published private(set) var error: String?

    @Published private(set) var folder: URL
    /// Whether the starter pack is listed after the user's memes.
    private(set) var showsStarterPack: Bool
    private var scanTask: Task<Void, Never>?
    private var watcher: FolderWatcher?

    init(folder: URL = MemeScanner.defaultFolder, showsStarterPack: Bool = true) {
        self.folder = folder
        self.showsStarterPack = showsStarterPack
    }

    /// The GIFs and stickers built into F4 (`Contents/Resources/Starter`,
    /// added by build-app.sh), so a new user never starts from an empty
    /// panel. Read-only and never copied into the meme folder. Nil when
    /// running outside the app bundle (`swift run`).
    static let starterFolder: URL? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Starter", isDirectory: true),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }()

    /// Whether `meme` comes from the starter pack rather than the meme folder.
    func isStarter(_ meme: Meme) -> Bool {
        guard let starter = Self.starterFolder else { return false }
        return meme.url.standardizedFileURL.path.hasPrefix(starter.standardizedFileURL.path + "/")
    }

    /// Shows or hides the starter pack (Settings).
    func setShowsStarterPack(_ shows: Bool) {
        guard shows != showsStarterPack else { return }
        showsStarterPack = shows
        reload()
    }

    /// The user's own basito face for the empty states: a hidden
    /// `.basito.png` (or `.gif`, `.jpg`, `.jpeg`) in the meme folder.
    var customBasito: URL? {
        ["png", "gif", "jpg", "jpeg"]
            .map { folder.appendingPathComponent(".basito.\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Switches to another folder: stops watching the old one and scans the new one.
    func setFolder(_ url: URL) {
        guard url.standardizedFileURL != folder.standardizedFileURL else { return }
        watcher?.stop()
        watcher = nil
        folder = url
        memes = []
        reload()
    }

    /// Rescans the folder off the main thread and publishes the result.
    /// Creates the folder on first launch, so the user has a place to drop memes.
    func reload() {
        scanTask?.cancel()
        let folder = folder
        let starter = showsStarterPack ? Self.starterFolder : nil
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[Meme], Error> in
                Result {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let own = try MemeScanner.scan(folder: folder)
                    // The user's memes first; the starter pack never fails the scan.
                    let builtIn = starter.flatMap { try? MemeScanner.scan(folder: $0) } ?? []
                    return own + builtIn
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let memes):
                self.memes = memes
                self.error = nil
                self.watchIfNeeded()
            case .failure(let error):
                self.memes = []
                self.error = error.localizedDescription
            }
        }
    }

    /// Starts the folder watcher once the folder exists (the first scan creates
    /// it), and again if the folder was deleted and has been recreated since.
    private func watchIfNeeded() {
        if let watcher {
            if !watcher.isWatching { watcher.start() }
            return
        }
        let watcher = FolderWatcher(url: folder) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        if watcher.start() {
            self.watcher = watcher
        }
    }
}
