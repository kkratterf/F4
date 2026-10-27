import CoreGraphics
import XCTest
@testable import F4Core

final class PanelPlacementTests: XCTestCase {
    // A 1000×800 visible frame and the 720×500 panel. By default the panel
    // sits at (140, 180): centre (500, 430), while the screen's middle is y 400.
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 720, height: 500)

    func testDefaultOriginIsCentredAndAboveTheMiddle() {
        XCTAssertEqual(PanelPlacement.defaultOrigin(size: size, in: visible), CGPoint(x: 140, y: 180))
    }

    func testRelativeCentreRoundTrips() {
        let frame = CGRect(origin: CGPoint(x: 40, y: 250), size: size)
        let centre = PanelPlacement.relativeCentre(of: frame, in: visible)
        XCTAssertEqual(centre.x, 0.4, accuracy: 0.0001)
        XCTAssertEqual(centre.y, 0.625, accuracy: 0.0001)
        XCTAssertEqual(PanelPlacement.origin(relativeCentre: centre, size: size, in: visible), frame.origin)
    }

    func testRelativeCentreCarriesOverToAnotherScreen() {
        // A second display to the right, with a Dock at its bottom.
        let other = CGRect(x: 1000, y: 60, width: 2000, height: 1000)
        let origin = PanelPlacement.origin(relativeCentre: CGPoint(x: 0.25, y: 0.5), size: size, in: other)
        XCTAssertEqual(origin, CGPoint(x: 1000 + 500 - 360, y: 60 + 500 - 250))
    }

    func testOriginStaysInsideTheScreen() {
        let origin = PanelPlacement.origin(relativeCentre: CGPoint(x: 1, y: 0), size: size, in: visible)
        XCTAssertEqual(origin, CGPoint(x: 280, y: 0))
    }

    func testClampKeepsTheTopLeftOfAPanelLargerThanTheScreen() {
        let small = CGRect(x: 0, y: 0, width: 600, height: 400)
        XCTAssertEqual(PanelPlacement.clamp(CGPoint(x: 50, y: -50), size: size, in: small), CGPoint(x: 0, y: -100))
    }

    func testSnapsToTheVerticalCentreLine() {
        let snap = PanelPlacement.snap(CGPoint(x: 148, y: 600 - 500), size: size, in: visible)
        XCTAssertEqual(snap.origin.x, 140)
        XCTAssertEqual(snap.guides, [.vertical(x: 500)])
        XCTAssertFalse(snap.isDefault)
    }

    func testDoesNotSnapFromFarAway() {
        let snap = PanelPlacement.snap(CGPoint(x: 60, y: 30), size: size, in: visible)
        XCTAssertEqual(snap.origin, CGPoint(x: 60, y: 30))
        XCTAssertEqual(snap.guides, [])
    }

    func testSnapsToTheMiddleOfTheScreen() {
        // Centre y 405: 5 from the middle, 25 from the default height.
        let snap = PanelPlacement.snap(CGPoint(x: 20, y: 155), size: size, in: visible)
        XCTAssertEqual(snap.origin, CGPoint(x: 20, y: 150))
        XCTAssertEqual(snap.guides, [.horizontal(y: 400)])
    }

    func testSnapsBackToTheDefaultPosition() {
        let snap = PanelPlacement.snap(CGPoint(x: 135, y: 189), size: size, in: visible)
        XCTAssertEqual(snap.origin, CGPoint(x: 140, y: 180))
        XCTAssertEqual(snap.guides, [.vertical(x: 500), .horizontal(y: 430)])
        XCTAssertTrue(snap.isDefault)
    }

    func testSnapKeepsThePanelOnScreen() {
        let snap = PanelPlacement.snap(CGPoint(x: 900, y: -200), size: size, in: visible)
        XCTAssertEqual(snap.origin, CGPoint(x: 280, y: 0))
    }
}
