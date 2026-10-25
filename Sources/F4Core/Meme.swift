import Foundation

/// One image file in the meme folder.
public struct Meme: Identifiable, Hashable, Sendable {
    public let url: URL
    public let kind: MemeKind
    /// File name without the extension: what search matches and the grid shows.
    public let name: String
    /// Part of the thumbnail cache key, so an edited file gets a new thumbnail.
    public let modificationDate: Date

    public var id: URL { url }

    public init(url: URL, kind: MemeKind, modificationDate: Date) {
        self.url = url
        self.kind = kind
        self.name = url.deletingPathExtension().lastPathComponent
        self.modificationDate = modificationDate
    }
}
