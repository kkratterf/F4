import XCTest
@testable import ReactionDeckCore

final class MemeKindTests: XCTestCase {
    func testRecognisesSupportedExtensions() {
        XCTAssertEqual(MemeKind(url: URL(fileURLWithPath: "/m/cat.gif")), .gif)
        XCTAssertEqual(MemeKind(url: URL(fileURLWithPath: "/m/cat.PNG")), .png)
        XCTAssertEqual(MemeKind(url: URL(fileURLWithPath: "/m/cat.jpg")), .jpeg)
        XCTAssertEqual(MemeKind(url: URL(fileURLWithPath: "/m/cat.JPEG")), .jpeg)
    }

    func testRejectsOtherFiles() {
        XCTAssertNil(MemeKind(url: URL(fileURLWithPath: "/m/cat.mp4")))
        XCTAssertNil(MemeKind(url: URL(fileURLWithPath: "/m/notes.txt")))
        XCTAssertNil(MemeKind(url: URL(fileURLWithPath: "/m/gif")))
    }

    func testOnlyGIFsAreAnimated() {
        XCTAssertTrue(MemeKind.gif.isAnimated)
        XCTAssertFalse(MemeKind.png.isAnimated)
        XCTAssertFalse(MemeKind.jpeg.isAnimated)
    }

    func testTypeIdentifiers() {
        XCTAssertEqual(MemeKind.gif.typeIdentifier, "com.compuserve.gif")
        XCTAssertEqual(MemeKind.png.typeIdentifier, "public.png")
        XCTAssertEqual(MemeKind.jpeg.typeIdentifier, "public.jpeg")
    }
}
