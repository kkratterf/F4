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

    func recordCopy(_ meme: Meme) {
        recents = MemeOrdering.recording(meme.url, in: recents)
        defaults.set(recents.map(\.path), forKey: Key.recents)
    }
}
