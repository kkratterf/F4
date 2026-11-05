import Foundation
import F4Core

/// Downloads a `ContentPack` (the Boris pack...) into the meme folder, when
/// the user turns it on in the menu bar's Packs submenu: never on its own.
/// Turning it off moves its folders to the Trash (`LibraryOrganizer`).
///
/// Each sticker comes straight from the link in the pack. Files already in
/// the pack's folder are skipped, so downloading again only fetches what is
/// missing; nothing is ever overwritten.
@MainActor
final class PackDownloader: ObservableObject {
    /// The packs listed in the app bundle (`Packs.json`, from
    /// `Resources/Packs/packs.json`). Empty outside the bundle.
    let packs: [ContentPack]
    /// The pack being downloaded, if any.
    @Published private(set) var downloading: String?
    /// Packs downloaded at least once (`downloadedPacks` default).
    @Published private(set) var downloaded: Set<String>

    private let library: MemeLibrary
    private let defaults: UserDefaults
    private static let downloadedKey = "downloadedPacks"
    /// Largest file a pack may bring.
    private static let maxBytes = 30 * 1024 * 1024

    init(library: MemeLibrary, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        downloaded = Set(defaults.stringArray(forKey: Self.downloadedKey) ?? [])
        packs = Bundle.main.url(forResource: "Packs", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? ContentPack.packs(from: $0) } ?? []
    }

    /// Downloads `pack` in the background; `done` gets how many files were
    /// added and how many failed.
    func download(_ pack: ContentPack, done: @escaping (_ added: Int, _ failed: Int) -> Void) {
        guard downloading == nil else { return }
        downloading = pack.id
        let folder = library.folder
        let items = pack.items
        Task {
            let (added, failed) = await Task.detached(priority: .utility) {
                await Self.fetch(items, into: folder)
            }.value
            downloading = nil
            if failed < items.count {
                downloaded.insert(pack.id)
                defaults.set(downloaded.sorted(), forKey: Self.downloadedKey)
            }
            library.reload()
            done(added, failed)
        }
    }

    /// Marks `pack` as off, once its folders went to the Trash.
    func forget(_ pack: ContentPack) {
        downloaded.remove(pack.id)
        defaults.set(downloaded.sorted(), forKey: Self.downloadedKey)
    }

    /// Four downloads at a time, each written next to its siblings.
    nonisolated private static func fetch(_ items: [ContentPack.Item], into folder: URL) async -> (Int, Int) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var added = 0
        var failed = 0
        for batch in stride(from: 0, to: items.count, by: 4).map({ Array(items[$0..<min($0 + 4, items.count)]) }) {
            await withTaskGroup(of: Bool?.self) { group in
                for item in batch {
                    group.addTask { await save(item, into: folder, session: session) }
                }
                for await result in group {
                    switch result {
                    case .some(true): added += 1
                    case .some(false): failed += 1
                    case .none: break
                    }
                }
            }
        }
        return (added, failed)
    }

    /// True when saved, false when it failed, nil when it was already there.
    nonisolated private static func save(_ item: ContentPack.Item, into folder: URL, session: URLSession) async -> Bool? {
        let target = LibraryFolders.url(of: item.category, in: folder)
        let base = MemeImport.baseName(item.name)
        let fileManager = FileManager.default
        let existing = (try? fileManager.contentsOfDirectory(atPath: target.path)) ?? []
        if existing.contains(where: { ($0 as NSString).deletingPathExtension == base }) { return nil }
        do {
            let (data, response) = try await session.data(from: item.source)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return false }
            guard data.count <= maxBytes, let kind = MemeImport.kind(sniffing: data) else { return false }
            try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            let url = MemeImport.uniqueURL(name: base, kind: kind, in: target)
            try data.write(to: url, options: .withoutOverwriting)
            return true
        } catch {
            NSLog("F4: could not download %@: %@", item.source.absoluteString, error.localizedDescription)
            return false
        }
    }
}
