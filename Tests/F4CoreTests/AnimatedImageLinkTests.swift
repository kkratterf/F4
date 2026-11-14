import XCTest
@testable import F4Core

final class AnimatedImageLinkTests: XCTestCase {
    func testAGifURLBesideTheCopiedImage() {
        XCTAssertEqual(
            MemeImport.animatedImageLink(urls: ["https://example.com/a/cat.gif"], html: nil),
            URL(string: "https://example.com/a/cat.gif")
        )
    }

    func testTheImgSourceOfCopiedHTML() {
        let html = #"<meta charset='utf-8'><img src="https://media.example.com/x/dance.webp?w=200&amp;h=200" alt="dance">"#
        XCTAssertEqual(
            MemeImport.animatedImageLink(urls: [], html: html),
            URL(string: "https://media.example.com/x/dance.webp?w=200&h=200")
        )
    }

    func testSingleQuotesAndOtherAttributesFirst() {
        let html = "<IMG class='big' SRC='https://example.com/wow.GIF'>"
        XCTAssertEqual(MemeImport.animatedImageLink(urls: [], html: html), URL(string: "https://example.com/wow.GIF"))
    }

    func testStillImagesAndOtherSchemesDoNotCount() {
        XCTAssertNil(MemeImport.animatedImageLink(urls: ["https://example.com/cat.png"], html: "<img src=\"https://example.com/cat.jpg\">"))
        XCTAssertNil(MemeImport.animatedImageLink(urls: ["file:///tmp/cat.gif"], html: "<img src=\"data:image/gif;base64,R0lGOD\">"))
        XCTAssertNil(MemeImport.animatedImageLink(urls: [], html: nil))
    }

    func testTheURLComesBeforeTheHTML() {
        XCTAssertEqual(
            MemeImport.animatedImageLink(urls: ["https://a.example/one.gif"], html: "<img src=\"https://b.example/two.gif\">"),
            URL(string: "https://a.example/one.gif")
        )
    }
}
