import XCTest
@testable import F4Core

final class GridNavigationTests: XCTestCase {
    // 12 items in 5 columns:
    //  0  1  2  3  4
    //  5  6  7  8  9
    // 10 11
    private func move(_ direction: GridDirection, _ index: Int, count: Int = 12) -> Int {
        GridNavigation.move(direction, from: index, count: count, columns: 5)
    }

    func testLeftAndRightWrapBetweenRows() {
        XCTAssertEqual(move(.right, 0), 1)
        XCTAssertEqual(move(.right, 4), 5)
        XCTAssertEqual(move(.left, 5), 4)
    }

    func testLeftAndRightStopAtTheEnds() {
        XCTAssertEqual(move(.left, 0), 0)
        XCTAssertEqual(move(.right, 11), 11)
    }

    func testUpAndDownMoveByARow() {
        XCTAssertEqual(move(.down, 1), 6)
        XCTAssertEqual(move(.up, 6), 1)
        XCTAssertEqual(move(.down, 6), 11)
    }

    func testDownIntoAShorterLastRowGoesToItsLastItem() {
        XCTAssertEqual(move(.down, 8), 11)
        XCTAssertEqual(move(.down, 9), 11)
    }

    func testUpAndDownStopAtTheEdges() {
        XCTAssertEqual(move(.up, 3), 3)
        XCTAssertEqual(move(.down, 10), 10)
        XCTAssertEqual(move(.down, 11), 11)
    }

    func testEmptyAndOutOfRange() {
        XCTAssertEqual(move(.down, 0, count: 0), 0)
        XCTAssertEqual(move(.right, 99), 11)
        XCTAssertEqual(move(.left, -3), 0)
    }
}
