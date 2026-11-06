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
    /// Called after starter folders were copied into F4's own library, with
    /// every top-level starter folder copied so far, so none is copied
    /// twice (`AppSettings.seededStarterFolders`): stickers the user deleted
    /// stay deleted, and a folder added in an update still arrives.
    var onSeeded: ((Set<String>) -> Void)?
    /// The top-level starter folders already copied into F4's own library.
    private var seededStarterFolders: Set<String>
    /// Whether the Emoji and F4 starter folders of 0.6 and earlier are
    /// still to be moved to the Trash (`LibraryFolders.retiredStarterFiles`).
    private var removesRetiredStarter: Bool
    /// Called once they were, so it happens once (`AppSettings.didRemoveRetiredStarter`).
    var onRetiredStarterRemoved: (() -> Void)?
    /// Whether this launch already looked for starter folders to copy.
    private var didCheckStarter = false
    private var scanTask: Task<Void, Never>?
    private var watcher: FolderWatcher?

    init(
        folder: URL = MemeScanner.defaultFolder,
        showsStarterPack: Bool = true,
        seededStarterFolders: Set<String> = [],
        removesRetiredStarter: Bool = false
    ) {
        self.folder = folder
        self.showsStarterPack = showsStarterPack
        self.seededStarterFolders = seededStarterFolders
        self.removesRetiredStarter = removesRetiredStarter
    }

    /// Whether the folder is F4's own library (`LibraryFolders.appLibrary`).
    /// The starter pack is copied into it as ordinary files, so it is not
    /// listed from the app bundle on top of that.
    var isAppLibrary: Bool {
        folder.standardizedFileURL == LibraryFolders.appLibrary().standardizedFileURL
    }

    /// The stickers built into F4 (`Contents/Resources/Starter`,
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
    /// memes, and, once a launch when it is F4's own library, copies the
    /// starter folders it has never copied before scanning.
    func reload() {
        scanTask?.cancel()
        let folder = folder
        let isAppLibrary = isAppLibrary
        let starter = showsStarterPack && !isAppLibrary ? Self.starterFolder : nil
        let seedFrom = !didCheckStarter && isAppLibrary ? Self.starterFolder : nil
        let alreadySeeded = seededStarterFolders
        let retire = isAppLibrary && removesRetiredStarter
        if retire { removesRetiredStarter = false }
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<([Meme], [String], Set<String>?), Error> in
                Result {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    if retire { Self.trashRetiredStarter(in: folder) }
                    let seeded = seedFrom.flatMap { Self.copyStarterPack(from: $0, into: folder, seeded: alreadySeeded) }
                    let own = try MemeScanner.scan(folder: folder)
                    // The user's memes first; the starter pack never fails the scan.
                    let builtIn = starter.flatMap { try? MemeScanner.scan(folder: $0) } ?? []
                    return (own + builtIn, MemeScanner.folders(in: folder), seeded)
                }
            }.value
            guard let self else { return }
            if retire { self.onRetiredStarterRemoved?() }
            guard !Task.isCancelled else { return }
            defer { if !self.hasLoaded { self.hasLoaded = true } }
            switch result {
            case .success(let (memes, folders, seeded)):
                if let seeded {
                    self.didCheckStarter = true
                    let all = self.seededStarterFolders.union(seeded)
                    if all != self.seededStarterFolders {
                        self.seededStarterFolders = all
                        self.onSeeded?(all)
                    }
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

    /// Copies the starter folders (maramao/ today) not in `seeded`
    /// into `folder`, skipping files already there, so the memes become the
    /// user's to move or delete. Returns every top-level starter folder when
    /// it ran to the end, nil otherwise. Blocking: off the main thread.
    nonisolated private static func copyStarterPack(from starter: URL, into folder: URL, seeded: Set<String>) -> Set<String>? {
        let fileManager = FileManager.default
        guard let memes = try? MemeScanner.scan(folder: starter) else { return nil }
        let root = starter.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        let relative = memes.map { meme -> String in
            let path = meme.url.standardizedFileURL.resolvingSymlinksInPath().path
            return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : meme.url.lastPathComponent
        }
        let existing = Set(relative.filter { fileManager.fileExists(atPath: folder.appendingPathComponent($0).path) })
        for path in LibraryFolders.starterFilesToCopy(relative, existing: existing, seeded: seeded) {
            let destination = folder.appendingPathComponent(path)
            do {
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: starter.appendingPathComponent(path), to: destination)
            } catch {
                NSLog("F4: could not copy the starter meme %@: %@", path, error.localizedDescription)
            }
        }
        return Set(relative.map(LibraryFolders.topFolder(of:)))
    }

    /// Moves to the Trash the starter stickers F4 no longer ships (Emoji/
    /// and F4/, copied up to 0.6), where they still are, then each of those
    /// folders left with nothing in it. Anything the user added, renamed or
    /// moved stays. Blocking: off the main thread.
    nonisolated private static func trashRetiredStarter(in folder: URL) {
        let fileManager = FileManager.default
        for path in LibraryFolders.retiredStarterFiles {
            let url = folder.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } catch {
                NSLog("F4: could not move the old starter sticker %@ to the Trash: %@", path, error.localizedDescription)
            }
        }
        for name in LibraryFolders.retiredStarterFolders {
            let url = folder.appendingPathComponent(name, isDirectory: true)
            guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path),
                  contents.allSatisfy({ $0 == ".DS_Store" })
            else { continue }
            try? fileManager.trashItem(at: url, resultingItemURL: nil)
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
