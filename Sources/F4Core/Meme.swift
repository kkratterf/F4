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

    public var id: URL { url }

    public init(url: URL, kind: MemeKind, modificationDate: Date, category: String? = nil, tags: [String] = []) {
        self.url = url
        self.kind = kind
        self.name = url.deletingPathExtension().lastPathComponent
        self.category = category.flatMap { $0.isEmpty ? nil : $0 }
        self.modificationDate = modificationDate
        self.tags = tags
    }

    /// What search matches: the subfolders, the name, then the tags
    /// ("dogs this is fine meme").
    public var searchText: String {
        let parts = [category?.replacingOccurrences(of: "/", with: " ")].compactMap { $0 } + [name] + tags
        return parts.joined(separator: " ")
    }
}
