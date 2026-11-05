import XCTest
@testable import F4Core

final class MemeTagsTests: XCTestCase {
    func testTypedTagsAreSplitOnCommas() {
        XCTAssertEqual(MemeTags.parse("gatto, reazione,  lunedì   mattina ,"), ["gatto", "reazione", "lunedì mattina"])
        XCTAssertEqual(MemeTags.parse(""), [])
        XCTAssertEqual(MemeTags.parse(" , ,"), [])
    }

    func testDuplicatesAreDroppedIgnoringCaseAndAccents() {
        XCTAssertEqual(MemeTags.parse("Gatto, gatto, perché, perche"), ["Gatto", "perché"])
    }

    func testALongTagIsCut() {
        XCTAssertEqual(MemeTags.parse(String(repeating: "a", count: 60)).first?.count, 40)
    }

    func testTagsReadBackAsTyped() {
        let tags = ["gatto", "reazione"]
        XCTAssertEqual(MemeTags.parse(MemeTags.text(tags)), tags)
    }

    func testWhatAPictureShowsBecomesItsTags() {
        let labels = [
            StickerNaming.Label(identifier: "animal", confidence: 0.95),
            StickerNaming.Label(identifier: "cat", confidence: 0.9),
            StickerNaming.Label(identifier: "domestic_cat", confidence: 0.8),
            StickerNaming.Label(identifier: "kitten", confidence: 0.5),
            StickerNaming.Label(identifier: "whiskers", confidence: 0.4),
            StickerNaming.Label(identifier: "dog", confidence: 0.1),
        ]
        XCTAssertEqual(StickerNaming.tags(labels), ["cat", "domestic cat", "kitten"])
        XCTAssertEqual(StickerNaming.tags([]), [])
    }
}
