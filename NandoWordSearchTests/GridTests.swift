import XCTest
@testable import NandoWordSearch

final class GridTests: XCTestCase {
    func testPlacesWordsInAllEightDirections() {
        let testCases: [(direction: GridDirection, start: GridCoordinate, expected: [GridCoordinate])] = [
            (
                .north,
                GridCoordinate(row: 2, column: 2),
                [
                    GridCoordinate(row: 2, column: 2),
                    GridCoordinate(row: 1, column: 2),
                    GridCoordinate(row: 0, column: 2),
                ]
            ),
            (
                .northEast,
                GridCoordinate(row: 2, column: 0),
                [
                    GridCoordinate(row: 2, column: 0),
                    GridCoordinate(row: 1, column: 1),
                    GridCoordinate(row: 0, column: 2),
                ]
            ),
            (
                .east,
                GridCoordinate(row: 2, column: 0),
                [
                    GridCoordinate(row: 2, column: 0),
                    GridCoordinate(row: 2, column: 1),
                    GridCoordinate(row: 2, column: 2),
                ]
            ),
            (
                .southEast,
                GridCoordinate(row: 0, column: 0),
                [
                    GridCoordinate(row: 0, column: 0),
                    GridCoordinate(row: 1, column: 1),
                    GridCoordinate(row: 2, column: 2),
                ]
            ),
            (
                .south,
                GridCoordinate(row: 0, column: 2),
                [
                    GridCoordinate(row: 0, column: 2),
                    GridCoordinate(row: 1, column: 2),
                    GridCoordinate(row: 2, column: 2),
                ]
            ),
            (
                .southWest,
                GridCoordinate(row: 0, column: 2),
                [
                    GridCoordinate(row: 0, column: 2),
                    GridCoordinate(row: 1, column: 1),
                    GridCoordinate(row: 2, column: 0),
                ]
            ),
            (
                .west,
                GridCoordinate(row: 2, column: 2),
                [
                    GridCoordinate(row: 2, column: 2),
                    GridCoordinate(row: 2, column: 1),
                    GridCoordinate(row: 2, column: 0),
                ]
            ),
            (
                .northWest,
                GridCoordinate(row: 2, column: 2),
                [
                    GridCoordinate(row: 2, column: 2),
                    GridCoordinate(row: 1, column: 1),
                    GridCoordinate(row: 0, column: 0),
                ]
            ),
        ]

        for testCase in testCases {
            var grid = Grid(size: 5)

            XCTAssertTrue(
                grid.place(word: "CAT", from: testCase.start, direction: testCase.direction),
                "Expected placement to succeed for direction \(testCase.direction)"
            )

            XCTAssertEqual(grid.placements.last?.coordinates, testCase.expected)
            XCTAssertEqual(grid.placements.last?.word, "CAT")

            for (letter, coordinate) in zip("CAT", testCase.expected) {
                XCTAssertEqual(grid[coordinate]?.letter, letter)
            }
        }
    }

    func testAllowsOverlappingMatchingLetters() {
        var grid = Grid(size: 4)

        XCTAssertTrue(
            grid.place(
                word: "CAT",
                from: GridCoordinate(row: 1, column: 0),
                direction: .east
            )
        )

        XCTAssertTrue(
            grid.place(
                word: "MAP",
                from: GridCoordinate(row: 0, column: 1),
                direction: .south
            )
        )

        XCTAssertEqual(grid.placements.count, 2)
        XCTAssertEqual(grid[GridCoordinate(row: 1, column: 1)]?.letter, "A")
    }

    func testPlaceWordsFillsGridCompletelyWithLetters() {
        var grid = Grid(size: 5)

        XCTAssertTrue(grid.place(words: ["SWIFT", "CODE", "TEST"]))
        XCTAssertEqual(grid.cells.count, 25)
        XCTAssertTrue(grid.cells.allSatisfy { $0.letter != nil })
    }

    func testPlaceWordsReturnsFalseWhenWordsCannotFit() {
        var grid = Grid(size: 2)

        XCTAssertFalse(grid.place(words: ["TOOLONG"]))
        XCTAssertTrue(grid.placements.isEmpty)
        XCTAssertTrue(grid.cells.allSatisfy { $0.letter == nil })
    }
}
