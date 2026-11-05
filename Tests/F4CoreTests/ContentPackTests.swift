import XCTest
@testable import F4Core

final class ContentPackTests: XCTestCase {
    func testItemsGoInThePacksFolder() {
        let pack = ContentPack(
            id: "boris",
            name: "Boris",
            stickers: [
                "https://giphy.com/stickers/dai-dai-dai-XyZ789",
                "https://example.com/not-giphy.gif",
                "https://giphy.com/gifs/boris-basito-AbC123",
            ]
        )
        XCTAssertEqual(pack.items, [
            ContentPack.Item(
                source: URL(string: "https://media.giphy.com/media/XyZ789/giphy.gif")!,
                category: "Boris",
                name: "dai dai dai"
            ),
            ContentPack.Item(
                source: URL(string: "https://media.giphy.com/media/AbC123/giphy.gif")!,
                category: "Boris",
                name: "boris basito"
            ),
        ])
        XCTAssertEqual(pack.category, "Boris")
    }

    func testCategoryIsACleanFolderName() {
        XCTAssertEqual(ContentPack(id: "office", name: "The Office / US", stickers: []).category, "The Office US")
        XCTAssertEqual(ContentPack(id: "dots", name: "...", stickers: []).category, "dots")
    }

    func testParsesThePacksFileAndSkipsEmptyPacks() throws {
        let json = """
        {"packs": [
          {"id": "boris", "name": "Boris", "stickers": ["https://giphy.com/stickers/basito-AbC123"]},
          {"id": "empty", "name": "Empty", "stickers": []}
        ]}
        """
        let packs = try ContentPack.packs(from: Data(json.utf8))
        XCTAssertEqual(packs.map(\.id), ["boris"])
    }

    /// The file build-app.sh puts in F4.app must always parse.
    func testTheShippedPacksFileParses() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Packs/packs.json")
        XCTAssertNoThrow(try ContentPack.packs(from: Data(contentsOf: file)))
    }
}
