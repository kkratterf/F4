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

    /// The Stickers tab: the last used first, most recent first, then the
    /// ones never copied, newest added first (by the file's modification
    /// date, which is when F4 wrote it), ties in the order of `memes`.
    /// Favourites are not pinned here: they have their own tab.
    public static func byLastUse(_ memes: [Meme], recents: [URL]) -> [Meme] {
        let recentRank = Dictionary(recents.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var used: [(rank: Int, meme: Meme)] = []
        var unused: [(index: Int, meme: Meme)] = []
        for (index, meme) in memes.enumerated() {
            if let rank = recentRank[meme.url] {
                used.append((rank, meme))
            } else {
                unused.append((index, meme))
            }
        }
        used.sort { $0.rank < $1.rank }
        unused.sort { lhs, rhs in
            lhs.meme.modificationDate != rhs.meme.modificationDate
                ? lhs.meme.modificationDate > rhs.meme.modificationDate
                : lhs.index < rhs.index
        }
        return used.map(\.meme) + unused.map(\.meme)
    }

    /// How many recently copied stickers F4 remembers: enough for the
    /// Stickers tab to keep the order of everything in regular use.
    public static let recentsLimit = 500

    /// `recents` after copying `url`: moved to the front, capped at `limit`.
    public static func recording(_ url: URL, in recents: [URL], limit: Int = recentsLimit) -> [URL] {
        Array(([url] + recents.filter { $0 != url }).prefix(limit))
    }
}
