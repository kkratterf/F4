import XCTest
@testable import F4Core

final class ContentPackTests: XCTestCase {
    func testItemsGoInThePacksFolders() {
        let pack = ContentPack(
            id: "boris",
            name: "Boris",
            gifs: ["https://giphy.com/gifs/boris-basito-AbC123", "https://example.com/not-giphy.gif"],
            stickers: ["https://giphy.com/stickers/dai-dai-dai-XyZ789"]
        )
        XCTAssertEqual(pack.items, [
            ContentPack.Item(
                source: URL(string: "https://media.giphy.com/media/AbC123/giphy.gif")!,
                category: "GIFs/Boris",
                name: "boris basito"
            ),
            ContentPack.Item(
                source: URL(string: "https://media.giphy.com/media/XyZ789/giphy.gif")!,
                category: "Stickers/Boris",
                name: "dai dai dai"
            ),
        ])
    }

    func testParsesThePacksFileAndSkipsEmptyPacks() throws {
        let json = """
        {"packs": [
          {"id": "boris", "name": "Boris", "gifs": ["https://giphy.com/gifs/basito-AbC123"]},
          {"id": "empty", "name": "Empty", "gifs": [], "stickers": []}
        ]}
        """
        let packs = try ContentPack.packs(from: Data(json.utf8))
        XCTAssertEqual(packs.map(\.id), ["boris"])
        XCTAssertEqual(packs[0].stickers, [])
    }

    /// The file build-app.sh puts in F4.app must always parse.
    func testTheShippedPacksFileParses() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Packs/packs.json")
        XCTAssertNoThrow(try ContentPack.packs(from: Data(contentsOf: file)))
    }
}
