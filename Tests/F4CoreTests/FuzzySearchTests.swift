import XCTest
@testable import F4Core

final class FuzzySearchTests: XCTestCase {
    private func search(_ names: [String], _ query: String) -> [String] {
        FuzzySearch.filter(names, query: query, name: { $0 })
    }

    func testEmptyQueryKeepsEverythingInOrder() {
        XCTAssertEqual(search(["b", "a"], ""), ["b", "a"])
        XCTAssertEqual(search(["b", "a"], "   "), ["b", "a"])
    }

    func testCharactersMustAppearInOrder() {
        XCTAssertNotNil(FuzzySearch.score("tif", in: "this is fine"))
        XCTAssertNil(FuzzySearch.score("fit", in: "this is fine dog"))
        XCTAssertNil(FuzzySearch.score("xyz", in: "this is fine"))
    }

    func testIgnoresCaseAccentsAndSeparators() {
        XCTAssertNotNil(FuzzySearch.score("PERCHE", in: "perché no"))
        XCTAssertNotNil(FuzzySearch.score("this is", in: "this_is-fine"))
        XCTAssertNotNil(FuzzySearch.score("fine", in: "THIS.IS.FINE"))
    }

    func testEveryWordMustMatch() {
        XCTAssertEqual(search(["dog fire", "dog water", "cat fire"], "fire dog"), ["dog fire"])
    }

    func testConsecutiveAndWordStartMatchesRankFirst() {
        let names = ["confused math lady", "facepalm", "a person facing a palm tree"]
        XCTAssertEqual(search(names, "facepalm").first, "facepalm")
        XCTAssertEqual(search(["blink guy", "the drake blink"], "blink"), ["blink guy", "the drake blink"])
        XCTAssertEqual(search(["xdrake", "drake"], "drake"), ["drake", "xdrake"])
    }

    func testPrefersWordStartsOverScatteredLetters() {
        // "sb" should prefer "success baby" (two word starts) to "subway".
        XCTAssertEqual(search(["subway", "success baby"], "sb").first, "success baby")
    }

    func testTiesKeepOriginalOrder() {
        XCTAssertEqual(search(["cat 2", "cat 1"], "cat"), ["cat 2", "cat 1"])
    }

    func testFiltersMemesByName() {
        let memes = ["this is fine.gif", "distracted boyfriend.jpg"].map {
            Meme(url: URL(fileURLWithPath: "/m/\($0)"), kind: MemeKind(url: URL(fileURLWithPath: $0))!, modificationDate: .distantPast)
        }
        XCTAssertEqual(FuzzySearch.filter(memes, query: "boy").map(\.name), ["distracted boyfriend"])
        // The extension is not part of the name.
        XCTAssertTrue(FuzzySearch.filter(memes, query: "jpg").isEmpty)
    }

    func testIsFastEnoughForThousandsOfMemes() {
        let names = (0..<5000).map { "some long meme name number \($0) with words" }
        measure {
            _ = search(names, "lmw")
        }
    }
}
