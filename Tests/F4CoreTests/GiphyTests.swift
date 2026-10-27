import XCTest
@testable import F4Core

final class GiphyTests: XCTestCase {
    func testTabsMapToCatalogues() {
        XCTAssertNil(Giphy.catalogue(for: .all))
        XCTAssertEqual(Giphy.catalogue(for: .gifs), .gifs)
        XCTAssertEqual(Giphy.catalogue(for: .stickers), .stickers)
    }

    func testEmptyQueryAsksForTrending() {
        let url = Giphy.requestURL(.gifs, query: "  ", apiKey: "KEY")
        XCTAssertEqual(url.host, "api.giphy.com")
        XCTAssertEqual(url.path, "/v1/gifs/trending")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "api_key", value: "KEY")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "rating", value: "pg-13")))
        XCTAssertFalse(items.contains { $0.name == "q" })
    }

    func testSearchEncodesTheQuery() {
        let url = Giphy.requestURL(.stickers, query: "this is fine & co", apiKey: "KEY", language: "it")
        XCTAssertEqual(url.path, "/v1/stickers/search")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "q", value: "this is fine & co")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "lang", value: "it")))
        XCTAssertTrue(url.absoluteString.contains("q=this%20is%20fine%20%26%20co"))
    }

    func testDecodesResults() throws {
        let json = """
        {"data": [
          {"type": "gif", "id": "abc123", "title": "Happy Dance GIF by The Office",
           "url": "https://giphy.com/gifs/theoffice-happy-dance-abc123",
           "images": {
             "fixed_width_small": {"url": "https://media.giphy.com/media/abc123/100w.gif", "width": "100"},
             "fixed_width_small_still": {"url": "https://media.giphy.com/media/abc123/100w_s.gif"},
             "original": {"url": "https://media.giphy.com/media/abc123/giphy.gif", "size": "123"}
           }},
          {"type": "gif", "id": "broken", "title": "No images", "images": {}},
          {"type": "gif", "id": "def456", "title": "",
           "images": {
             "fixed_width": {"url": "https://media.giphy.com/media/def456/200w.gif"},
             "downsized": {"url": "https://media.giphy.com/media/def456/giphy-downsized.gif"}
           }}
        ], "pagination": {"count": 3}, "meta": {"status": 200}}
        """
        let results = try Giphy.results(from: Data(json.utf8), catalogue: .gifs)
        XCTAssertEqual(results.map(\.id), ["abc123", "def456"])
        XCTAssertEqual(results[0].previewURL.lastPathComponent, "100w.gif")
        XCTAssertEqual(results[0].stillURL?.lastPathComponent, "100w_s.gif")
        XCTAssertEqual(results[0].fileURL.lastPathComponent, "giphy.gif")
        XCTAssertEqual(results[0].pageURL?.host, "giphy.com")
        XCTAssertEqual(results[0].name, "Happy Dance")
        XCTAssertEqual(results[1].fileURL.lastPathComponent, "giphy-downsized.gif")
        XCTAssertNil(results[1].stillURL)
        XCTAssertEqual(results[1].name, "giphy def456")
    }

    func testNameDropsGiphysTail() {
        func result(_ title: String) -> Giphy.Result {
            let url = URL(string: "https://media.giphy.com/x.gif")!
            return Giphy.Result(id: "x", catalogue: .stickers, title: title, pageURL: nil, previewURL: url, stillURL: nil, fileURL: url)
        }
        XCTAssertEqual(result("Cool Cool Cool Sticker by Brooklyn Nine-Nine").name, "Cool Cool Cool")
        XCTAssertEqual(result("This Is Fine GIF").name, "This Is Fine")
        XCTAssertEqual(result("wow").name, "wow")
    }

    func testRejectsAnErrorBody() {
        XCTAssertThrowsError(try Giphy.results(from: Data(#"{"message": "Invalid authentication credentials"}"#.utf8), catalogue: .gifs))
    }
}
