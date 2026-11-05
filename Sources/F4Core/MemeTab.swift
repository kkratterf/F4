import Foundation

/// The tabs of the panel: every sticker, the favourites, then one tab per
/// top-level folder of the library.
public enum MemeTab: Hashable, Sendable {
    case all
    case favourites
    /// A top-level folder ("Reactions"): its stickers, subfolders included.
    case folder(String)

    /// The tabs for a library with these folders (nested ones as
    /// "reactions/dogs"): All, Favourites, then each top-level folder once,
    /// in the order given.
    public static func tabs(folders: [String]) -> [MemeTab] {
        var seen: Set<String> = []
        let topLevel = folders.compactMap { folder -> String? in
            guard let first = folder.split(separator: "/").first.map(String.init), seen.insert(first).inserted else { return nil }
            return first
        }
        return [.all, .favourites] + topLevel.map { .folder($0) }
    }

    /// Stored in the defaults: "all", "favourites" or "folder:<name>".
    public var rawValue: String {
        switch self {
        case .all: return "all"
        case .favourites: return "favourites"
        case .folder(let name): return "folder:\(name)"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "all": self = .all
        case "favourites": self = .favourites
        default:
            guard rawValue.hasPrefix("folder:") else { return nil }
            let name = String(rawValue.dropFirst("folder:".count))
            guard !name.isEmpty else { return nil }
            self = .folder(name)
        }
    }

    /// The folder new stickers go into from this tab, relative to the
    /// library: the tab's folder, else the top level.
    public var folder: String? {
        if case .folder(let name) = self { return name }
        return nil
    }

    /// Whether `meme` shows in this tab. Favourites shows the stickers whose
    /// URL is in `favourites`.
    public func contains(_ meme: Meme, favourites: Set<URL> = []) -> Bool {
        switch self {
        case .all: return true
        case .favourites: return favourites.contains(meme.url)
        case .folder(let name):
            guard let category = meme.category else { return false }
            return category == name || category.hasPrefix(name + "/")
        }
    }

    /// The memes of `memes` that show in this tab, in the same order.
    public func filter(_ memes: [Meme], favourites: Set<URL> = []) -> [Meme] {
        self == .all ? memes : memes.filter { contains($0, favourites: favourites) }
    }

    /// The tab after (or before) this one in `tabs`, wrapping around: Tab
    /// and ⇧Tab. A tab that is not in `tabs` goes to the first one.
    public func next(in tabs: [MemeTab], backwards: Bool = false) -> MemeTab {
        guard !tabs.isEmpty else { return self }
        guard let index = tabs.firstIndex(of: self) else { return tabs[0] }
        let step = backwards ? tabs.count - 1 : 1
        return tabs[(index + step) % tabs.count]
    }
}
