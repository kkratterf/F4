import F4Core
import Foundation

/// Favourite and recently copied memes, stored in `UserDefaults` as file paths.
@MainActor
final class UsageStore: ObservableObject {
    private enum Key {
        static let favourites = "favouriteMemes"
        static let recents = "recentMemes"
    }

    @Published private(set) var favourites: Set<URL>
    @Published private(set) var recents: [URL]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let urls = { (key: String) in
            (defaults.stringArray(forKey: key) ?? []).map { URL(fileURLWithPath: $0) }
        }
        favourites = Set(urls(Key.favourites))
        recents = urls(Key.recents)
    }

    func isFavourite(_ meme: Meme) -> Bool {
        favourites.contains(meme.url)
    }

    func toggleFavourite(_ meme: Meme) {
        if favourites.contains(meme.url) {
            favourites.remove(meme.url)
        } else {
            favourites.insert(meme.url)
        }
        defaults.set(favourites.map(\.path).sorted(), forKey: Key.favourites)
    }

    /// Marks the file at `url` as a favourite (a sticker added in Favourites).
    func addFavourite(_ url: URL) {
        favourites.insert(url)
        defaults.set(favourites.map(\.path).sorted(), forKey: Key.favourites)
    }

    /// A meme or a folder was moved or renamed from `old` to `new`: the
    /// favourites and recents in it follow, so organizing loses nothing.
    func relocate(from old: URL, to new: URL) {
        update { url in
            guard let path = LibraryFolders.relocatedPath(url.path, from: old.path, to: new.path) else { return url }
            return URL(fileURLWithPath: path)
        }
    }

    /// A meme or a folder went to the Trash: drop what pointed into it.
    func forget(_ url: URL) {
        update { LibraryFolders.relocatedPath($0.path, from: url.path, to: "") == nil ? $0 : nil }
    }

    /// Maps every stored URL (nil drops it) and saves.
    private func update(_ map: (URL) -> URL?) {
        favourites = Set(favourites.compactMap(map))
        recents = recents.compactMap(map)
        defaults.set(favourites.map(\.path).sorted(), forKey: Key.favourites)
        defaults.set(recents.map(\.path), forKey: Key.recents)
    }

    func recordCopy(_ meme: Meme) {
        recents = MemeOrdering.recording(meme.url, in: recents)
        defaults.set(recents.map(\.path), forKey: Key.recents)
    }
}
