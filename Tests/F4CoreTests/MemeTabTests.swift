import XCTest
@testable import F4Core

final class MemeTabTests: XCTestCase {
    private func meme(_ file: String, in category: String? = nil) -> Meme {
        let url = URL(fileURLWithPath: "/m/\(category.map { "\($0)/" } ?? "")\(file)")
        return Meme(url: url, kind: MemeKind(url: url)!, modificationDate: .distantPast, category: category)
    }

    func testAllShowsEverything() {
        let memes = [meme("a.gif"), meme("b.png"), meme("c.jpg"), meme("d.webp")]
        XCTAssertEqual(MemeTab.all.filter(memes), memes)
    }

    func testGIFsAreGIFsOutsideTheStickersFolder() {
        XCTAssertTrue(MemeTab.gifs.contains(meme("a.gif")))
        XCTAssertTrue(MemeTab.gifs.contains(meme("a.gif", in: "reactions")))
        XCTAssertFalse(MemeTab.gifs.contains(meme("a.gif", in: "Stickers")))
        XCTAssertFalse(MemeTab.gifs.contains(meme("b.png")))
        XCTAssertFalse(MemeTab.gifs.contains(meme("c.jpg")))
    }

    func testStickersArePNGWebPAndTheStickersFolder() {
        XCTAssertTrue(MemeTab.stickers.contains(meme("b.png")))
        XCTAssertTrue(MemeTab.stickers.contains(meme("d.webp", in: "whatsapp")))
        XCTAssertTrue(MemeTab.stickers.contains(meme("a.gif", in: "Stickers")))
        XCTAssertTrue(MemeTab.stickers.contains(meme("a.gif", in: "stickers/cats")))
        XCTAssertTrue(MemeTab.stickers.contains(meme("c.jpg", in: "Stickers")))
        XCTAssertFalse(MemeTab.stickers.contains(meme("a.gif", in: "old stickers")))
        XCTAssertFalse(MemeTab.stickers.contains(meme("c.jpg")))
    }

    func testFilterKeepsOrder() {
        let memes = [meme("z.png"), meme("a.gif"), meme("m.webp")]
        XCTAssertEqual(MemeTab.stickers.filter(memes).map(\.name), ["z", "m"])
    }

    func testNextWrapsAround() {
        XCTAssertEqual(MemeTab.all.next(), .gifs)
        XCTAssertEqual(MemeTab.stickers.next(), .all)
        XCTAssertEqual(MemeTab.all.next(backwards: true), .stickers)
        XCTAssertEqual(MemeTab.gifs.next(backwards: true), .all)
    }
}
