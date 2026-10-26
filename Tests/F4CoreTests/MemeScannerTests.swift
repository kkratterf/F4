import XCTest
@testable import F4Core

final class MemeScannerTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemeScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func touch(_ name: String) throws {
        try Data([0x47, 0x49, 0x46]).write(to: folder.appendingPathComponent(name))
    }

    func testKeepsOnlySupportedImages() throws {
        for name in ["a.gif", "b.PNG", "c.jpg", "d.jpeg", "e.webp", "f.mp4", "notes.txt", ".hidden.gif"] {
            try touch(name)
        }
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("folder.gif", isDirectory: true),
            withIntermediateDirectories: true
        )
        let memes = try MemeScanner.scan(folder: folder)
        XCTAssertEqual(memes.map(\.url.lastPathComponent), ["a.gif", "b.PNG", "c.jpg", "d.jpeg", "e.webp"])
        XCTAssertEqual(memes.map(\.kind), [.gif, .png, .jpeg, .jpeg, .webp])
    }

    func testSortsLikeFinder() throws {
        for name in ["meme 10.gif", "meme 2.gif", "Banana.png", "apple.png"] {
            try touch(name)
        }
        let memes = try MemeScanner.scan(folder: folder)
        XCTAssertEqual(memes.map(\.name), ["apple", "Banana", "meme 2", "meme 10"])
    }

    private func touch(_ name: String, in subfolder: String) throws {
        let sub = folder.appendingPathComponent(subfolder, isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data([0x47]).write(to: sub.appendingPathComponent(name))
    }

    func testSubfoldersBecomeCategories() throws {
        try touch("top.gif")
        try touch("fine.gif", in: "dogs")
        try touch("blink.png", in: "reactions/guys")
        let memes = try MemeScanner.scan(folder: folder)
        XCTAssertEqual(memes.map(\.name), ["top", "fine", "blink"])
        XCTAssertEqual(memes.map(\.category), [nil, "dogs", "reactions/guys"])
        XCTAssertEqual(memes[2].searchText, "reactions guys blink")
        XCTAssertEqual(memes[0].searchText, "top")
    }

    func testSkipsHiddenFoldersAndTooDeepOnes() throws {
        try touch("secret.gif", in: ".hidden")
        try touch("deep.gif", in: "a/b/c/d/e")
        try touch("ok.gif", in: "a/b/c/d")
        XCTAssertEqual(try MemeScanner.scan(folder: folder).map(\.name), ["ok"])
    }

    func testMissingFolderThrows() {
        XCTAssertThrowsError(try MemeScanner.scan(folder: folder.appendingPathComponent("nope")))
    }

    func testNameDropsTheExtension() {
        let meme = Meme(url: URL(fileURLWithPath: "/m/this is fine.gif"), kind: .gif, modificationDate: .distantPast)
        XCTAssertEqual(meme.name, "this is fine")
        XCTAssertEqual(meme.id, meme.url)
    }
}
