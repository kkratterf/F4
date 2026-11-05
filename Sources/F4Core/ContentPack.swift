import Foundation

/// A pack of GIFs and stickers F4 can download into the library in one
/// click ("Boris", "The Office"...). The app ships only the list of GIPHY
/// links (`Resources/Packs/packs.json`), never the files: the clips belong
/// to their owners. The files are downloaded only when the user asks, and
/// from then on they are local, ordinary memes.
public struct ContentPack: Codable, Equatable, Sendable {
    /// Stable id, kept in the user's defaults once downloaded ("boris").
    public let id: String
    /// Shown in the menu, and the folder name in the library ("Boris").
    public let name: String
    /// GIPHY page links ("https://giphy.com/gifs/boris-basito-AbC123").
    public let gifs: [String]
    /// GIPHY sticker page links ("https://giphy.com/stickers/...").
    public let stickers: [String]

    public init(id: String, name: String, gifs: [String] = [], stickers: [String] = []) {
        self.id = id
        self.name = name
        self.gifs = gifs
        self.stickers = stickers
    }

    private enum CodingKeys: String, CodingKey { case id, name, gifs, stickers }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gifs = try container.decodeIfPresent([String].self, forKey: .gifs) ?? []
        stickers = try container.decodeIfPresent([String].self, forKey: .stickers) ?? []
    }

    /// One file to download: where it comes from and where it goes.
    public struct Item: Equatable, Sendable {
        public let source: URL
        /// Category in the library: `GIFs/Boris` or `Stickers/Boris`, so
        /// the stickers land in the Stickers tab.
        public let category: String
        /// File name without extension, from the link's words.
        public let name: String
    }

    /// The library folders the pack fills (`GIFs/Boris`, `Stickers/Boris`):
    /// what turning it off moves to the Trash.
    public var categories: [String] {
        var seen: [String] = []
        for item in items where !seen.contains(item.category) { seen.append(item.category) }
        return seen
    }

    /// The pack's files, GIFs first. Links that are not GIPHY page links
    /// are skipped.
    public var items: [Item] {
        let folder = LibraryFolders.folderName(name) ?? id
        func items(_ links: [String], in parent: String) -> [Item] {
            links.compactMap { link in
                guard let url = URL(string: link), let media = MemeImport.giphyMedia(for: url) else { return nil }
                return Item(source: media.url, category: "\(parent)/\(folder)", name: media.name)
            }
        }
        return items(gifs, in: "GIFs") + items(stickers, in: MemeTab.stickersFolder)
    }

    /// The packs in `packs.json`: `{"packs": [{"id", "name", "gifs", "stickers"}]}`.
    /// A pack with no usable link is left out.
    public static func packs(from data: Data) throws -> [ContentPack] {
        struct File: Decodable { let packs: [ContentPack] }
        return try JSONDecoder().decode(File.self, from: data).packs.filter { !$0.items.isEmpty }
    }
}
