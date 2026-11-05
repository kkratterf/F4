import Foundation
import F4Core

/// The memes the panel shows, read from the meme folder in the background
/// and read again whenever the folder changes.
@MainActor
final class MemeLibrary: ObservableObject {
    @Published private(set) var memes: [Meme] = []
    /// Set when the folder cannot be read.
    @Published private(set) var error: String?
    /// True once the first scan has finished, so a command that needs the
    /// memes (`f4://copy` at launch) can wait for them.
    @Published private(set) var hasLoaded = false

    @Published private(set) var folder: URL
    /// The subfolders of the meme folder, empty ones included ("reactions",
    /// "reactions/dogs"): where a meme can be moved from the panel.
    @Published private(set) var folders: [String] = []
    /// Whether the starter pack is listed after the user's memes.
    private(set) var showsStarterPack: Bool
    /// Called once the starter pack has been copied into F4's own library,
    /// so it is never copied again (`AppSettings.didSeedLibrary`).
    var onSeeded: (() -> Void)?
    /// True until the starter pack has been copied into F4's own library.
    private var needsSeeding: Bool
    private var scanTask: Task<Void, Never>?
    private var watcher: FolderWatcher?

    init(folder: URL = MemeScanner.defaultFolder, showsStarterPack: Bool = true, needsSeeding: Bool = false) {
        self.folder = folder
        self.showsStarterPack = showsStarterPack
        self.needsSeeding = needsSeeding
    }

    /// Whether the folder is F4's own library (`LibraryFolders.appLibrary`).
    /// The starter pack is copied into it as ordinary files, so it is not
    /// listed from the app bundle on top of that.
    var isAppLibrary: Bool {
        folder.standardizedFileURL == LibraryFolders.appLibrary().standardizedFileURL
    }

    /// The GIFs and stickers built into F4 (`Contents/Resources/Starter`,
    /// added by build-app.sh), so a new user never starts from an empty
    /// panel. Copied once into F4's own library; listed read-only from the
    /// bundle after the memes of any other folder. Nil when running outside
    /// the app bundle (`swift run`).
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

    /// Shows or hides the starter pack (Show Starter Pack in the menu).
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
    /// Creates the folder on first launch, so the user has a place to drop
    /// memes, and the first time it is F4's own library, copies the starter
    /// pack into it before scanning.
    func reload() {
        scanTask?.cancel()
        let folder = folder
        let isAppLibrary = isAppLibrary
        let starter = showsStarterPack && !isAppLibrary ? Self.starterFolder : nil
        let seedFrom = needsSeeding && isAppLibrary ? Self.starterFolder : nil
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<([Meme], [String], Bool), Error> in
                Result {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let seeded = seedFrom.map { Self.copyStarterPack(from: $0, into: folder) } ?? false
                    let own = try MemeScanner.scan(folder: folder)
                    // The user's memes first; the starter pack never fails the scan.
                    let builtIn = starter.flatMap { try? MemeScanner.scan(folder: $0) } ?? []
                    return (own + builtIn, MemeScanner.folders(in: folder), seeded)
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            defer { if !self.hasLoaded { self.hasLoaded = true } }
            switch result {
            case .success(let (memes, folders, seeded)):
                if seeded && self.needsSeeding {
                    self.needsSeeding = false
                    self.onSeeded?()
                }
                self.memes = memes
                self.folders = folders
                self.error = nil
                self.watchIfNeeded()
            case .failure(let error):
                self.memes = []
                self.folders = []
                self.error = error.localizedDescription
            }
        }
    }

    /// Copies the starter pack (GIFs/, Stickers/) into `folder`, skipping
    /// files already there, so the memes become the user's to move or
    /// delete. True when it ran to the end. Blocking: off the main thread.
    nonisolated private static func copyStarterPack(from starter: URL, into folder: URL) -> Bool {
        let fileManager = FileManager.default
        guard let memes = try? MemeScanner.scan(folder: starter) else { return false }
        let root = starter.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        let relative = memes.map { meme -> String in
            let path = meme.url.standardizedFileURL.resolvingSymlinksInPath().path
            return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : meme.url.lastPathComponent
        }
        let existing = Set(relative.filter { fileManager.fileExists(atPath: folder.appendingPathComponent($0).path) })
        for path in LibraryFolders.starterFilesToCopy(relative, existing: existing) {
            let destination = folder.appendingPathComponent(path)
            do {
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: starter.appendingPathComponent(path), to: destination)
            } catch {
                NSLog("F4: could not copy the starter meme %@: %@", path, error.localizedDescription)
            }
        }
        return true
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
