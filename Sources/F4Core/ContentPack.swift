import Foundation

/// A pack of stickers F4 can download into the library in one click
/// ("Boris", "The Office"...). The app ships only the list of GIPHY links
/// (`Resources/Packs/packs.json`), never the files: the stickers belong to
/// their owners. The files are downloaded only when the user turns the
/// pack on, and from then on they are local, ordinary stickers in a folder
/// named after the pack.
public struct ContentPack: Codable, Equatable, Sendable {
    /// Stable id, kept in the user's defaults once downloaded ("boris").
    public let id: String
    /// Shown in the menu, and the folder name in the library ("Boris").
    public let name: String
    /// GIPHY page links ("https://giphy.com/stickers/boris-basito-AbC123";
    /// a `gifs/` link works too, as an animated sticker).
    public let stickers: [String]

    public init(id: String, name: String, stickers: [String]) {
        self.id = id
        self.name = name
        self.stickers = stickers
    }

    /// One file to download: where it comes from and where it goes.
    public struct Item: Equatable, Sendable {
        public let source: URL
        /// Category in the library: the pack's folder ("Boris").
        public let category: String
        /// File name without extension, from the link's words.
        public let name: String
    }

    /// The library folder the pack fills ("Boris"): what turning it off
    /// moves to the Trash.
    public var category: String { LibraryFolders.folderName(name) ?? id }

    /// The pack's files. Links that are not GIPHY page links are skipped.
    public var items: [Item] {
        stickers.compactMap { link in
            guard let url = URL(string: link), let media = MemeImport.giphyMedia(for: url) else { return nil }
            return Item(source: media.url, category: category, name: media.name)
        }
    }

    /// The packs in `packs.json`: `{"packs": [{"id", "name", "stickers"}]}`.
    /// A pack with no usable link is left out.
    public static func packs(from data: Data) throws -> [ContentPack] {
        struct File: Decodable { let packs: [ContentPack] }
        return try JSONDecoder().decode(File.self, from: data).packs.filter { !$0.items.isEmpty }
    }
}
