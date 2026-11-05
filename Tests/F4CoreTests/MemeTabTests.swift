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

    func testFavouritesShowsOnlyFavourites() {
        let memes = [meme("a.gif"), meme("b.png"), meme("c.jpg", in: "old")]
        let favourites: Set<URL> = [memes[0].url, memes[2].url]
        XCTAssertEqual(MemeTab.favourites.filter(memes, favourites: favourites).map(\.name), ["a", "c"])
        XCTAssertTrue(MemeTab.favourites.filter(memes).isEmpty)
        XCTAssertEqual(MemeTab.all.filter(memes, favourites: favourites), memes)
    }

    func testNextWrapsAround() {
        let tabs = MemeTab.tabs(folders: ["Boris"])
        XCTAssertEqual(MemeTab.all.next(in: tabs), .favourites)
        XCTAssertEqual(MemeTab.favourites.next(in: tabs), .folder("Boris"))
        XCTAssertEqual(MemeTab.folder("Boris").next(in: tabs), .all)
        XCTAssertEqual(MemeTab.all.next(in: tabs, backwards: true), .folder("Boris"))
        XCTAssertEqual(MemeTab.folder("Gone").next(in: tabs), .all)
    }

    func testOneTabPerTopLevelFolder() {
        XCTAssertEqual(
            MemeTab.tabs(folders: ["Boris", "Boris/René", "Emoji", "Reactions/dogs"]),
            [.all, .favourites, .folder("Boris"), .folder("Emoji"), .folder("Reactions")]
        )
        XCTAssertEqual(MemeTab.tabs(folders: []), [.all, .favourites])
    }

    func testAFolderTabShowsItsStickersAndSubfolders() {
        let memes = [meme("a.png"), meme("b.png", in: "Boris"), meme("c.png", in: "Boris/René"), meme("d.png", in: "Borisone")]
        XCTAssertEqual(MemeTab.folder("Boris").filter(memes).map(\.name), ["b", "c"])
        XCTAssertEqual(MemeTab.folder("Boris").folder, "Boris")
        XCTAssertNil(MemeTab.all.folder)
    }

    func testRawValueRoundTrips() {
        for tab in [MemeTab.all, .favourites, .folder("Reazioni")] {
            XCTAssertEqual(MemeTab(rawValue: tab.rawValue), tab)
        }
        XCTAssertNil(MemeTab(rawValue: "folder:"))
        XCTAssertNil(MemeTab(rawValue: "gifs"))
    }
}
