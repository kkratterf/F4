import XCTest
@testable import F4Core

final class ContentPackTests: XCTestCase {
    func testItemsGoInThePacksFolder() {
        let pack = ContentPack(
            id: "boris",
            name: "Boris",
            stickers: [
                "https://example.com/pack/sticker_1.webp",
                "https://giphy.com/stickers/dai-dai-dai-XyZ789",
                "not a link",
            ]
        )
        XCTAssertEqual(pack.category, "Boris")
        XCTAssertEqual(pack.items, [
            ContentPack.Item(source: URL(string: "https://example.com/pack/sticker_1.webp")!, category: "Boris", name: "sticker_1"),
            ContentPack.Item(source: URL(string: "https://media.giphy.com/media/XyZ789/giphy.gif")!, category: "Boris", name: "dai dai dai"),
        ])
        XCTAssertEqual(pack.stickerPacks, [])
    }

    func testGetStickerPackLinksBringTheWholePack() {
        let pack = ContentPack(id: "gatos", name: "Gatos", stickers: [
            "https://getstickerpack.com/stickers/memes-19",
            "https://s3.getstickerpack.com/storage/uploads/sticker-pack/memes-19/sticker_1.png",
        ])
        XCTAssertEqual(pack.stickerPacks, ["memes-19"])
        XCTAssertEqual(pack.items.map(\.name), ["sticker_1"])
    }

    func testParsesThePacksFileAndSkipsEmptyPacks() throws {
        let json = """
        {"packs": [
          {"id": "gatos", "name": "Gatos", "stickers": ["https://getstickerpack.com/stickers/memes-19"]},
          {"id": "empty", "name": "Empty", "stickers": []}
        ]}
        """
        XCTAssertEqual(try ContentPack.packs(from: Data(json.utf8)).map(\.id), ["gatos"])
    }

    /// The file build-app.sh puts in F4.app must always parse.
    func testTheShippedPacksFileParses() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Packs/packs.json")
        XCTAssertNoThrow(try ContentPack.packs(from: Data(contentsOf: file)))
    }
}
