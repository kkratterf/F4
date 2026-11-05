import XCTest
@testable import F4Core

final class StickerArchiveTests: XCTestCase {
    func testRecognisesPackFiles() {
        XCTAssertTrue(StickerArchive.isArchive(URL(fileURLWithPath: "/d/Boris.wastickers")))
        XCTAssertTrue(StickerArchive.isArchive(URL(fileURLWithPath: "/d/pack.ZIP")))
        XCTAssertFalse(StickerArchive.isArchive(URL(fileURLWithPath: "/d/a.webp")))
    }

    func testFolderNameComesFromTheTitle() {
        let archive = URL(fileURLWithPath: "/d/pack-123.wastickers")
        XCTAssertEqual(StickerArchive.folderName(title: "  Boris / Stagione 1 \nRenè", archive: archive), "Boris Stagione 1")
        XCTAssertEqual(StickerArchive.folderName(title: nil, archive: archive), "pack-123")
        XCTAssertEqual(StickerArchive.folderName(title: "   ", archive: archive), "pack-123")
    }

    func testKeepsTheStickersAndDropsTheTrayIcon() {
        let files = [
            "title.txt", "author.txt", "tray.png", "10.webp", "2.webp", "1.webp",
            "__MACOSX/._1.webp", ".DS_Store", "cover.png",
        ]
        XCTAssertEqual(StickerArchive.stickers(in: files), ["1.webp", "2.webp", "10.webp"])
    }

    func testKeepsPNGStickersWhenThereIsNoWebP() {
        XCTAssertEqual(StickerArchive.stickers(in: ["tray_icon.png", "b.png", "a.png", "x.gif"]), ["a.png", "b.png", "x.gif"])
    }
}
