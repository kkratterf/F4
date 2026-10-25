import Foundation

/// The order of the grid when the search field is empty.
public enum MemeOrdering {
    /// Favourites first, then recently copied memes, then everything else.
    ///
    /// Favourites keep the order of their last use (most recent first, then
    /// never-used ones in folder order); recents are most recent first; the
    /// rest keeps the order of `memes`. Entries of `favourites` and `recents`
    /// that are no longer in the folder are ignored.
    public static func arrange(_ memes: [Meme], favourites: Set<URL>, recents: [URL]) -> [Meme] {
        guard !favourites.isEmpty || !recents.isEmpty else { return memes }
        let recentRank = Dictionary(recents.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var favouriteMemes: [(index: Int, meme: Meme)] = []
        var recentMemes: [(rank: Int, meme: Meme)] = []
        var rest: [Meme] = []
        for (index, meme) in memes.enumerated() {
            if favourites.contains(meme.url) {
                favouriteMemes.append((index, meme))
            } else if let rank = recentRank[meme.url] {
                recentMemes.append((rank, meme))
            } else {
                rest.append(meme)
            }
        }
        favouriteMemes.sort { lhs, rhs in
            switch (recentRank[lhs.meme.url], recentRank[rhs.meme.url]) {
            case let (l?, r?): return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.index < rhs.index
            }
        }
        recentMemes.sort { $0.rank < $1.rank }
        return favouriteMemes.map(\.meme) + recentMemes.map(\.meme) + rest
    }

    /// `recents` after copying `url`: moved to the front, capped at `limit`.
    public static func recording(_ url: URL, in recents: [URL], limit: Int = 30) -> [URL] {
        Array(([url] + recents.filter { $0 != url }).prefix(limit))
    }
}
