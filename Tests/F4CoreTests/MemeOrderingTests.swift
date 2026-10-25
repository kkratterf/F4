import XCTest
@testable import F4Core

final class MemeOrderingTests: XCTestCase {
    private func meme(_ name: String) -> Meme {
        Meme(url: URL(fileURLWithPath: "/m/\(name).gif"), kind: .gif, modificationDate: .distantPast)
    }

    private lazy var memes = ["a", "b", "c", "d", "e"].map(meme)
    private func url(_ name: String) -> URL { meme(name).url }

    func testNothingRecordedKeepsFolderOrder() {
        XCTAssertEqual(MemeOrdering.arrange(memes, favourites: [], recents: []).map(\.name), ["a", "b", "c", "d", "e"])
    }

    func testRecentsComeFirstMostRecentFirst() {
        let arranged = MemeOrdering.arrange(memes, favourites: [], recents: [url("d"), url("b")])
        XCTAssertEqual(arranged.map(\.name), ["d", "b", "a", "c", "e"])
    }

    func testFavouritesComeBeforeRecents() {
        let arranged = MemeOrdering.arrange(
            memes,
            favourites: [url("e"), url("c")],
            recents: [url("d"), url("e")]
        )
        // e is a favourite used recently, c a favourite never used.
        XCTAssertEqual(arranged.map(\.name), ["e", "c", "d", "a", "b"])
    }

    func testIgnoresFilesThatAreGone() {
        let arranged = MemeOrdering.arrange(memes, favourites: [url("zzz")], recents: [url("gone"), url("c")])
        XCTAssertEqual(arranged.map(\.name), ["c", "a", "b", "d", "e"])
    }

    func testRecordingMovesToTheFrontAndCaps() {
        let recents = MemeOrdering.recording(url("b"), in: [url("a"), url("b"), url("c")], limit: 3)
        XCTAssertEqual(recents, [url("b"), url("a"), url("c")])
        let capped = MemeOrdering.recording(url("d"), in: recents, limit: 3)
        XCTAssertEqual(capped, [url("d"), url("b"), url("a")])
    }
}
