import XCTest
@testable import NandoWordSearch

@MainActor
final class GameViewModelTests: XCTestCase {
    func testTracksStraightLineSelectionAcrossGrid() {
        let viewModel = makeViewModel(words: ["CAT"])

        viewModel.beginSelection(at: GridPosition(row: 0, column: 0))
        viewModel.updateSelection(to: GridPosition(row: 0, column: 2))

        XCTAssertEqual(
            viewModel.selectedCells,
            [
                GridPosition(row: 0, column: 0),
                GridPosition(row: 0, column: 1),
                GridPosition(row: 0, column: 2),
            ]
        )
    }

    func testDeviationResetsSelectionFromCurrentCell() {
        let viewModel = makeViewModel(words: ["CAT"])

        viewModel.beginSelection(at: GridPosition(row: 0, column: 0))
        viewModel.updateSelection(to: GridPosition(row: 0, column: 2))
        viewModel.updateSelection(to: GridPosition(row: 1, column: 1))

        XCTAssertEqual(viewModel.selectedCells, [GridPosition(row: 1, column: 1)])
    }

    func testMarksForwardWordAsFoundAndStoresMatchedPath() {
        var hapticTriggerCount = 0
        let viewModel = makeViewModel(
            words: ["CAT"],
            onWordFound: {
                hapticTriggerCount += 1
            }
        )

        viewModel.beginSelection(at: GridPosition(row: 0, column: 0))
        viewModel.updateSelection(to: GridPosition(row: 0, column: 2))
        viewModel.endSelection()

        XCTAssertEqual(viewModel.selectedCells, [])
        XCTAssertEqual(viewModel.foundWords.count, 1)
        XCTAssertEqual(viewModel.foundWords.first?.value, "CAT")
        XCTAssertEqual(
            viewModel.foundWords.first?.cells,
            [
                GridPosition(row: 0, column: 0),
                GridPosition(row: 0, column: 1),
                GridPosition(row: 0, column: 2),
            ]
        )
        XCTAssertEqual(hapticTriggerCount, 1)
        XCTAssertTrue(viewModel.allWordsFound)
    }

    func testMarksBackwardWordAsFound() {
        let viewModel = makeViewModel(words: ["CAT"])

        viewModel.beginSelection(at: GridPosition(row: 0, column: 2))
        viewModel.updateSelection(to: GridPosition(row: 0, column: 0))
        viewModel.endSelection()

        XCTAssertEqual(viewModel.foundWords.count, 1)
        XCTAssertEqual(viewModel.foundWords.first?.value, "CAT")
        XCTAssertTrue(viewModel.allWordsFound)
    }

    func testClearsSelectionWithoutFeedbackWhenNoWordMatches() {
        var hapticTriggerCount = 0
        let viewModel = makeViewModel(
            words: ["DOG"],
            onWordFound: {
                hapticTriggerCount += 1
            }
        )

        viewModel.beginSelection(at: GridPosition(row: 0, column: 0))
        viewModel.updateSelection(to: GridPosition(row: 0, column: 2))
        viewModel.endSelection()

        XCTAssertEqual(viewModel.selectedCells, [])
        XCTAssertTrue(viewModel.foundWords.isEmpty)
        XCTAssertFalse(viewModel.allWordsFound)
        XCTAssertEqual(hapticTriggerCount, 0)
    }

    private func makeViewModel(
        words: [String],
        onWordFound: @escaping () -> Void = {}
    ) -> GameViewModel {
        var grid = Grid(size: 3)
        XCTAssertTrue(grid.place(word: "CAT", from: GridPosition(row: 0, column: 0), direction: .east))
        XCTAssertTrue(grid.place(word: "DOG", from: GridPosition(row: 1, column: 0), direction: .east))
        XCTAssertTrue(grid.place(word: "EMU", from: GridPosition(row: 2, column: 0), direction: .east))

        let gameWords = words.enumerated().map { index, word in
            Word(
                value: word,
                highlightStyle: WordHighlightStyle.allCases[index % WordHighlightStyle.allCases.count]
            )
        }

        return GameViewModel(
            gameState: GameState(
                theme: "Animals",
                grid: grid,
                words: gameWords,
                phase: .playing
            ),
            onWordFound: onWordFound
        )
    }
}
