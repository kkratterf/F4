import XCTest
@testable import F4Core

final class MemeImportTests: XCTestCase {
    func testSniffsTheKindFromTheFirstBytes() {
        XCTAssertEqual(MemeImport.kind(sniffing: Data("GIF89a....".utf8)), .gif)
        XCTAssertEqual(MemeImport.kind(sniffing: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])), .png)
        XCTAssertEqual(MemeImport.kind(sniffing: Data([0xFF, 0xD8, 0xFF, 0xE0])), .jpeg)
        XCTAssertEqual(MemeImport.kind(sniffing: Data("RIFF\u{0}\u{0}\u{0}\u{0}WEBPVP8 ".utf8)), .webp)
        XCTAssertNil(MemeImport.kind(sniffing: Data("RIFF\u{0}\u{0}\u{0}\u{0}WAVE".utf8)))
        XCTAssertNil(MemeImport.kind(sniffing: Data("<html>".utf8)))
        XCTAssertNil(MemeImport.kind(sniffing: Data()))
    }

    func testKindFromPasteboardType() {
        XCTAssertEqual(MemeImport.kind(typeIdentifier: "com.compuserve.gif"), .gif)
        XCTAssertEqual(MemeImport.kind(typeIdentifier: "org.webmproject.webp"), .webp)
        XCTAssertNil(MemeImport.kind(typeIdentifier: "public.tiff"))
    }

    func testFolderFollowsTheTabThenTheKind() {
        XCTAssertEqual(MemeImport.folder(for: .gif, tab: .all), "GIFs")
        XCTAssertEqual(MemeImport.folder(for: .gif, tab: .gifs), "GIFs")
        XCTAssertEqual(MemeImport.folder(for: .gif, tab: .stickers), "Stickers")
        XCTAssertEqual(MemeImport.folder(for: .webp, tab: .gifs), "Stickers")
        XCTAssertEqual(MemeImport.folder(for: .png, tab: .all), "Stickers")
        XCTAssertNil(MemeImport.folder(for: .jpeg, tab: .all))
        XCTAssertEqual(MemeImport.folder(for: .jpeg, tab: .stickers), "Stickers")
    }

    func testImportedMemesLandInTheTabTheyWereAddedFrom() {
        for tab in MemeTab.allCases {
            for kind in MemeKind.allCases {
                let folder = MemeImport.folder(for: kind, tab: tab)
                let url = URL(fileURLWithPath: "/m/\(folder.map { "\($0)/" } ?? "")x.\(kind.fileExtension)")
                let meme = Meme(url: url, kind: kind, modificationDate: .distantPast, category: folder)
                if tab != .gifs || kind == .gif {
                    XCTAssertTrue(tab.contains(meme), "\(kind) added in \(tab)")
                }
            }
        }
    }

    func testBaseNameIsASafeFileName() {
        XCTAssertEqual(MemeImport.baseName("this is fine"), "this is fine")
        XCTAssertEqual(MemeImport.baseName("a/b:c\\d"), "a b c d")
        XCTAssertEqual(MemeImport.baseName("  .hidden  "), "hidden")
        XCTAssertEqual(MemeImport.baseName("line\nbreak\ttab"), "line break tab")
        XCTAssertEqual(MemeImport.baseName("..."), "meme")
        XCTAssertEqual(MemeImport.baseName(""), "meme")
        XCTAssertEqual(MemeImport.baseName(String(repeating: "a", count: 200)).count, 80)
    }

    func testUniqueURLNeverOverwrites() {
        let folder = URL(fileURLWithPath: "/m/GIFs")
        let taken: Set<String> = ["/m/GIFs/wow.gif", "/m/GIFs/wow 2.gif"]
        let url = MemeImport.uniqueURL(name: "wow", kind: .gif, in: folder) { taken.contains($0.path) }
        XCTAssertEqual(url.path, "/m/GIFs/wow 3.gif")
        XCTAssertEqual(MemeImport.uniqueURL(name: "new", kind: .jpeg, in: folder) { _ in false }.lastPathComponent, "new.jpg")
    }

    func testWebURL() {
        XCTAssertEqual(MemeImport.webURL(in: " https://media.giphy.com/media/abc/giphy.gif \n")?.host, "media.giphy.com")
        XCTAssertNotNil(MemeImport.webURL(in: "http://example.com/a.png"))
        XCTAssertNil(MemeImport.webURL(in: "this is fine"))
        XCTAssertNil(MemeImport.webURL(in: "file:///etc/passwd"))
        XCTAssertNil(MemeImport.webURL(in: "https://example.com/a.gif and more"))
    }

    func testSuggestedName() {
        XCTAssertEqual(MemeImport.suggestedName(for: URL(string: "https://example.com/memes/this-is-fine.gif")!), "this-is-fine")
        XCTAssertEqual(MemeImport.suggestedName(for: URL(string: "https://media.giphy.com/media/abc/giphy.gif")!), "media.giphy.com")
    }
}

final class GiphyLinkTests: XCTestCase {
    func testPageLinkBecomesTheGIF() {
        let media = MemeImport.giphyMedia(for: URL(string: "https://giphy.com/gifs/theoffice-the-office-wow-5wWf7GW1AzV6pF3MaVW")!)
        XCTAssertEqual(media?.url.absoluteString, "https://media.giphy.com/media/5wWf7GW1AzV6pF3MaVW/giphy.gif")
        XCTAssertEqual(media?.name, "theoffice the office wow")
    }

    func testStickerLinkAndBareID() {
        XCTAssertEqual(MemeImport.giphyMedia(for: URL(string: "https://giphy.com/stickers/AbC123")!)?.name, "giphy AbC123")
    }

    func testOtherLinksAreLeftAlone() {
        XCTAssertNil(MemeImport.giphyMedia(for: URL(string: "https://media.giphy.com/media/abc/giphy.gif")!))
        XCTAssertNil(MemeImport.giphyMedia(for: URL(string: "https://giphy.com/explore/cats")!))
        XCTAssertNil(MemeImport.giphyMedia(for: URL(string: "https://example.com/gifs/a-b")!))
    }
}
