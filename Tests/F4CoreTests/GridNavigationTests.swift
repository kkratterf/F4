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

final class SectionedGridNavigationTests: XCTestCase {
    // Sections of 3, 7 and 2 items in 5 columns, each on new rows:
    //  0  1  2            (favourites)
    //  3  4  5  6  7      (the rest)
    //  8  9
    // 10 11               (a third section)
    private func move(_ direction: GridDirection, _ index: Int, sections: [Int] = [3, 7, 2]) -> Int {
        GridNavigation.move(direction, from: index, sections: sections, columns: 5)
    }

    func testLeftAndRightCrossSections() {
        XCTAssertEqual(move(.right, 2), 3)
        XCTAssertEqual(move(.left, 3), 2)
        XCTAssertEqual(move(.right, 11), 11)
    }

    func testDownFromTheLastRowGoesToTheNextSection() {
        XCTAssertEqual(move(.down, 0), 3)
        XCTAssertEqual(move(.down, 2), 5)
        XCTAssertEqual(move(.down, 8), 10)
        XCTAssertEqual(move(.down, 9), 11)
    }

    func testDownIntoAShorterRowOfTheNextSectionClampsToItsEnd() {
        XCTAssertEqual(move(.down, 6), 9)
        XCTAssertEqual(move(.down, 7), 9)
    }

    func testUpFromTheFirstRowGoesToTheLastRowOfTheSectionAbove() {
        XCTAssertEqual(move(.up, 3), 0)
        XCTAssertEqual(move(.up, 6), 2)
        XCTAssertEqual(move(.up, 10), 8)
        XCTAssertEqual(move(.up, 11), 9)
    }

    func testUpAndDownStayAtTheEdges() {
        XCTAssertEqual(move(.up, 1), 1)
        XCTAssertEqual(move(.down, 11), 11)
    }

    func testEmptySectionsAreSkipped() {
        XCTAssertEqual(move(.down, 1, sections: [3, 0, 2]), 4)
        XCTAssertEqual(move(.up, 4, sections: [3, 0, 2]), 1)
        XCTAssertEqual(move(.down, 0, sections: [0, 4]), 0)
    }

    func testOneSectionMatchesThePlainGrid() {
        for index in 0..<12 {
            for direction in [GridDirection.left, .right, .up, .down] {
                XCTAssertEqual(
                    GridNavigation.move(direction, from: index, sections: [12], columns: 5),
                    GridNavigation.move(direction, from: index, count: 12, columns: 5)
                )
            }
        }
    }
}
