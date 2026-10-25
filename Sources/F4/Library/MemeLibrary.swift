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
    private var scanTask: Task<Void, Never>?
    private var watcher: FolderWatcher?

    init(folder: URL = MemeScanner.defaultFolder) {
        self.folder = folder
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
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[Meme], Error> in
                Result {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    return try MemeScanner.scan(folder: folder)
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
