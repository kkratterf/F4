import Foundation

/// One image file in the meme folder.
public struct Meme: Identifiable, Hashable, Sendable {
    public let url: URL
    public let kind: MemeKind
    /// File name without the extension: what the grid shows.
    public let name: String
    /// The subfolder the meme is in, relative to the meme folder (e.g.
    /// "reactions/dogs"), or nil at the top level. Search matches it too.
    public let category: String?
    /// Part of the thumbnail cache key, so an edited file gets a new thumbnail.
    public let modificationDate: Date
    /// The file's Finder tags ("gatto", "reazione"): set from the panel with
    /// ⌘T, or by F4 when a pasted picture shows something. Search matches them.
    public let tags: [String]
    /// `searchText` as search compares it (folded case and accents),
    /// worked out once here, off the main thread when the folder is scanned,
    /// rather than for every meme on every key typed.
    let searchKey: [Character]

    public var id: URL { url }

    public init(url: URL, kind: MemeKind, modificationDate: Date, category: String? = nil, tags: [String] = []) {
        self.url = url
        self.kind = kind
        self.name = url.deletingPathExtension().lastPathComponent
        self.category = category.flatMap { $0.isEmpty ? nil : $0 }
        self.modificationDate = modificationDate
        self.tags = tags
        self.searchKey = FuzzySearch.normalized(Self.searchText(category: self.category, name: self.name, tags: tags))
    }

    // `searchKey` follows from the other fields, so it is left out.
    public static func == (lhs: Meme, rhs: Meme) -> Bool {
        lhs.url == rhs.url && lhs.kind == rhs.kind && lhs.modificationDate == rhs.modificationDate
            && lhs.category == rhs.category && lhs.tags == rhs.tags
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(modificationDate)
    }

    /// What search matches: the subfolders, the name, then the tags
    /// ("dogs this is fine meme").
    public var searchText: String {
        Self.searchText(category: category, name: name, tags: tags)
    }

    private static func searchText(category: String?, name: String, tags: [String]) -> String {
        let parts = [category?.replacingOccurrences(of: "/", with: " ")].compactMap { $0 } + [name] + tags
        return parts.joined(separator: " ")
    }
}
