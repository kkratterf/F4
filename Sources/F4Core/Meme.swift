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

    public var id: URL { url }

    public init(url: URL, kind: MemeKind, modificationDate: Date, category: String? = nil) {
        self.url = url
        self.kind = kind
        self.name = url.deletingPathExtension().lastPathComponent
        self.category = category.flatMap { $0.isEmpty ? nil : $0 }
        self.modificationDate = modificationDate
    }

    /// What search matches: the subfolders, then the name ("dogs this is fine").
    public var searchText: String {
        guard let category else { return name }
        return category.replacingOccurrences(of: "/", with: " ") + " " + name
    }
}
