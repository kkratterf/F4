import XCTest
@testable import F4Core

final class EasterEggsTests: XCTestCase {
    func testBasito() {
        XCTAssertEqual(EasterEggs.match("F4")?.effect, .basito)
        XCTAssertEqual(EasterEggs.match("basito")?.banner, "F4. Basito.")
        XCTAssertEqual(EasterEggs.match("f4")?.showsAllMemes, false)
    }

    func testIgnoresCasePunctuationAndAccents() {
        XCTAssertEqual(EasterEggs.match("Dai, dai, DAI!")?.effect, .randomPick)
        XCTAssertEqual(EasterEggs.match("  smarmella ")?.effect, .smarmella)
        XCTAssertNotNil(EasterEggs.match("La qualità"))
        XCTAssertNotNil(EasterEggs.match("That's what she said"))
    }

    func testEffects() {
        XCTAssertEqual(EasterEggs.match("occhi del cuore")?.effect, .favouritesOnly)
        XCTAssertEqual(EasterEggs.match("do a barrel roll")?.effect, .barrelRoll)
        XCTAssertEqual(EasterEggs.match("parkour")?.effect, .parkour)
        XCTAssertEqual(EasterEggs.match("a cazzo di cane")?.effect, .shuffle)
    }

    func testOrdinarySearchesAreNotEggs() {
        XCTAssertNil(EasterEggs.match(""))
        XCTAssertNil(EasterEggs.match("drake"))
        XCTAssertNil(EasterEggs.match("dai"))
        XCTAssertNil(EasterEggs.match("f"))
    }

    func testKonamiCode() {
        var code = KonamiCode()
        let keys: [KonamiCode.Key] = [.up, .up, .down, .down, .left, .right, .left, .right, .b]
        for key in keys { XCTAssertFalse(code.feed(key)) }
        XCTAssertTrue(code.feed(.a))
        // It resets after completing.
        XCTAssertFalse(code.feed(.a))
    }

    func testKonamiCodeRecoversFromAWrongKey() {
        var code = KonamiCode()
        for key: KonamiCode.Key in [.up, .up, .other, .up, .up, .down, .down, .left, .right, .left, .right, .b] {
            XCTAssertFalse(code.feed(key))
        }
        XCTAssertTrue(code.feed(.a))
    }

    func testKonamiCodeWithThreeUps() {
        var code = KonamiCode()
        for key: KonamiCode.Key in [.up, .up, .up, .down, .down, .left, .right, .left, .right, .b] {
            XCTAssertFalse(code.feed(key))
        }
        XCTAssertTrue(code.feed(.a))
    }
}
