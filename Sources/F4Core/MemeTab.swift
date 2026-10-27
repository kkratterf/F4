import Foundation

/// The tabs of the panel: everything, GIFs only, stickers only.
public enum MemeTab: String, CaseIterable, Sendable {
    case all
    case gifs
    case stickers

    /// The folder new GIFs and stickers go into, and the top-level folder
    /// that makes anything inside it a sticker.
    public static let stickersFolder = "Stickers"
    public static let gifsFolder = "GIFs"

    /// Whether `meme` shows in this tab.
    ///
    /// A sticker is anything inside a top-level `Stickers` folder, or any PNG
    /// or WebP file: stickers are transparent PNG or WebP in practice
    /// (WhatsApp and Telegram save WebP). A GIF is any GIF outside `Stickers`.
    /// JPEG memes only show in All.
    public func contains(_ meme: Meme) -> Bool {
        switch self {
        case .all: return true
        case .gifs: return meme.kind == .gif && !Self.isInStickersFolder(meme)
        case .stickers: return Self.isInStickersFolder(meme) || meme.kind == .png || meme.kind == .webp
        }
    }

    /// The memes of `memes` that show in this tab, in the same order.
    public func filter(_ memes: [Meme]) -> [Meme] {
        self == .all ? memes : memes.filter(contains)
    }

    /// The tab after (or before) this one, wrapping around: Tab and ⇧Tab.
    public func next(backwards: Bool = false) -> MemeTab {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        let step = backwards ? all.count - 1 : 1
        return all[(index + step) % all.count]
    }

    private static func isInStickersFolder(_ meme: Meme) -> Bool {
        guard let top = meme.category?.split(separator: "/").first else { return false }
        return top.caseInsensitiveCompare(stickersFolder) == .orderedSame
    }
}
