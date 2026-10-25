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
        for name in ["a.gif", "b.PNG", "c.jpg", "d.jpeg", "e.mp4", "notes.txt", ".hidden.gif"] {
            try touch(name)
        }
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("folder.gif", isDirectory: true),
            withIntermediateDirectories: true
        )
        let memes = try MemeScanner.scan(folder: folder)
        XCTAssertEqual(memes.map(\.url.lastPathComponent), ["a.gif", "b.PNG", "c.jpg", "d.jpeg"])
        XCTAssertEqual(memes.map(\.kind), [.gif, .png, .jpeg, .jpeg])
    }

    func testSortsLikeFinder() throws {
        for name in ["meme 10.gif", "meme 2.gif", "Banana.png", "apple.png"] {
            try touch(name)
        }
        let memes = try MemeScanner.scan(folder: folder)
        XCTAssertEqual(memes.map(\.name), ["apple", "Banana", "meme 2", "meme 10"])
    }

    func testSkipsSubfolders() throws {
        let sub = folder.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data().write(to: sub.appendingPathComponent("deep.gif"))
        try touch("top.gif")
        XCTAssertEqual(try MemeScanner.scan(folder: folder).map(\.name), ["top"])
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
