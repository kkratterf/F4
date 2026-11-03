import XCTest
@testable import F4Core

final class URLCommandTests: XCTestCase {
    private func command(_ string: String) -> URLCommand? {
        URL(string: string).flatMap(URLCommand.init(url:))
    }

    func testOpen() {
        XCTAssertEqual(command("f4://open"), .open)
        XCTAssertEqual(command("f4://"), .open)
        XCTAssertEqual(command("f4:open"), .open)
        XCTAssertEqual(command("F4://OPEN/"), .open)
    }

    func testSearch() {
        XCTAssertEqual(command("f4://search?q=this%20is%20fine"), .search("this is fine"))
        XCTAssertEqual(command("f4://search?query=dogs"), .search("dogs"))
        XCTAssertEqual(command("f4://search"), .search(""))
        XCTAssertEqual(command("f4://search?q=bears+beets"), .search("bears beets"))
    }

    func testCopy() {
        XCTAssertEqual(command("f4://copy?name=%20basito%20"), .copy("basito"))
        XCTAssertEqual(command("f4://copy?q=basito"), .copy("basito"))
        XCTAssertEqual(command("f4:copy?name=caf%C3%A9"), .copy("café"))
    }

    func testCopyNeedsAName() {
        XCTAssertNil(command("f4://copy"))
        XCTAssertNil(command("f4://copy?name="))
        XCTAssertNil(command("f4://copy?name=%20"))
    }

    func testReloadAndSettings() {
        XCTAssertEqual(command("f4://reload"), .reload)
        XCTAssertEqual(command("f4://rescan"), .reload)
        XCTAssertEqual(command("f4://settings"), .settings)
        XCTAssertEqual(command("f4://preferences"), .settings)
    }

    func testRejectsOtherURLs() {
        XCTAssertNil(command("f4://delete"))
        XCTAssertNil(command("https://f4.kkratter.com/open"))
        XCTAssertNil(command("file:///open"))
    }

    // MARK: Best match

    private func meme(_ name: String) -> Meme {
        Meme(url: URL(fileURLWithPath: "/m/\(name).gif"), kind: .gif, modificationDate: .distantPast)
    }

    func testBestMatchIsTheBestFuzzyMatch() {
        let memes = ["fine dining", "this is fine", "thinking"].map(meme)
        let match = URLCommand.bestMatch(for: "this is fine", in: memes, favourites: [], recents: [])
        XCTAssertEqual(match?.name, "this is fine")
    }

    func testFavouritesWinATie() {
        let memes = ["cat 1", "cat 2"].map(meme)
        let match = URLCommand.bestMatch(for: "cat", in: memes, favourites: [meme("cat 2").url], recents: [])
        XCTAssertEqual(match?.name, "cat 2")
    }

    func testNoMatch() {
        XCTAssertNil(URLCommand.bestMatch(for: "zebra", in: ["cat"].map(meme), favourites: [], recents: []))
    }
}
