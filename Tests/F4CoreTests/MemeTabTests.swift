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
        XCTAssertEqual(MemeTab.all.next(), .favourites)
        XCTAssertEqual(MemeTab.favourites.next(), .all)
        XCTAssertEqual(MemeTab.all.next(backwards: true), .favourites)
        XCTAssertEqual(MemeTab.favourites.next(backwards: true), .all)
    }
}
