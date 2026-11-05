import Foundation

/// The tabs of the panel: every sticker, or only the favourites.
public enum MemeTab: String, CaseIterable, Sendable {
    case all
    case favourites

    /// Whether `meme` shows in this tab. Favourites shows the stickers whose
    /// URL is in `favourites`.
    public func contains(_ meme: Meme, favourites: Set<URL> = []) -> Bool {
        switch self {
        case .all: return true
        case .favourites: return favourites.contains(meme.url)
        }
    }

    /// The memes of `memes` that show in this tab, in the same order.
    public func filter(_ memes: [Meme], favourites: Set<URL> = []) -> [Meme] {
        self == .all ? memes : memes.filter { contains($0, favourites: favourites) }
    }

    /// The tab after (or before) this one, wrapping around: Tab and ⇧Tab.
    public func next(backwards: Bool = false) -> MemeTab {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        let step = backwards ? all.count - 1 : 1
        return all[(index + step) % all.count]
    }
}
