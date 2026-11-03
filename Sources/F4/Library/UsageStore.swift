import F4Core
import Foundation

/// Favourite and recently copied memes, stored in `UserDefaults` as file paths.
@MainActor
final class UsageStore: ObservableObject {
    private enum Key {
        static let favourites = "favouriteMemes"
        static let recents = "recentMemes"
        static let savedWebMemes = "savedGiphyMemes"
    }

    @Published private(set) var favourites: Set<URL>
    @Published private(set) var recents: [URL]
    /// GIPHY results already saved in the meme folder, by `Giphy.Result`
    /// catalogue and id ("gifs-abc123"), so copying one again reuses the file.
    private var savedWebMemes: [String: String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let urls = { (key: String) in
            (defaults.stringArray(forKey: key) ?? []).map { URL(fileURLWithPath: $0) }
        }
        favourites = Set(urls(Key.favourites))
        recents = urls(Key.recents)
        savedWebMemes = defaults.dictionary(forKey: Key.savedWebMemes) as? [String: String] ?? [:]
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

    /// Marks the file at `url` as a favourite (a GIPHY result just pinned).
    func addFavourite(_ url: URL) {
        favourites.insert(url)
        defaults.set(favourites.map(\.path).sorted(), forKey: Key.favourites)
    }

    /// The file a GIPHY result was saved as, if it is still there.
    func savedFile(forWebMeme key: String) -> URL? {
        guard let path = savedWebMemes[key], FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Remembers that the GIPHY result `key` was saved at `url`.
    func recordSave(ofWebMeme key: String, at url: URL) {
        savedWebMemes[key] = url.path
        defaults.set(savedWebMemes, forKey: Key.savedWebMemes)
    }

    func recordCopy(_ meme: Meme) {
        recents = MemeOrdering.recording(meme.url, in: recents)
        defaults.set(recents.map(\.path), forKey: Key.recents)
    }
}
