import XCTest
@testable import F4Core

final class StickerPackLinkTests: XCTestCase {
    private func url(_ string: String) -> URL { URL(string: string)! }

    func testReadsThePackPage() {
        XCTAssertEqual(StickerPackLink.slug(from: url("https://getstickerpack.com/stickers/memes-19")), "memes-19")
        XCTAssertEqual(StickerPackLink.slug(from: url("https://www.getstickerpack.com/stickers/memes-19!y3r631/launch-app")), "memes-19")
        XCTAssertNil(StickerPackLink.slug(from: url("https://getstickerpack.com/stickers/")))
        XCTAssertNil(StickerPackLink.slug(from: url("https://getstickerpack.com/about")))
    }

    func testReadsTheAppLink() {
        let link = url("https://preview.page.link/loadstickerpack.page.link?link=https://getstickerpack.com/stickers/memes-19!y3r631/launch-app&apn=com.marsvard.stickermakerforwhatsapp&st=memes+gatos&si=https://s3.getstickerpack.com/storage/uploads/sticker-pack/memes-19/tray_large.png")
        XCTAssertEqual(StickerPackLink.slug(from: link), "memes-19")
        XCTAssertEqual(StickerPackLink.title(from: link), "memes gatos")
        XCTAssertEqual(StickerPackLink.folderName(slug: "memes-19", title: StickerPackLink.title(from: link)), "memes gatos")
    }

    func testReadsAStickerFile() {
        let file = url("https://s3.getstickerpack.com/storage/uploads/sticker-pack/memes-19/sticker_12.png?2dd6a28508e2ac5a6ae3884cf858cac8")
        XCTAssertEqual(StickerPackLink.slug(from: file), "memes-19")
    }

    func testIgnoresOtherLinks() {
        XCTAssertNil(StickerPackLink.slug(from: url("https://example.com/stickers/memes-19")))
        XCTAssertNil(StickerPackLink.slug(from: url("https://preview.page.link/x?link=https://example.com/a")))
        XCTAssertNil(StickerPackLink.slug(from: url("https://getstickerpack.com/stickers/..")))
    }

    func testBuildsTheStickerLinks() {
        XCTAssertEqual(StickerPackLink.stickerURLs(slug: "memes-19", index: 3).map(\.absoluteString), [
            "https://s3.getstickerpack.com/storage/uploads/sticker-pack/memes-19/sticker_3.png",
            "https://s3.getstickerpack.com/storage/uploads/sticker-pack/memes-19/sticker_3.webp",
        ])
        XCTAssertEqual(StickerPackLink.folderName(slug: "memes-19", title: nil), "memes-19")
    }
}
