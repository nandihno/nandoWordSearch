import Foundation

struct Grid: Equatable, Sendable {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    let size: Int
    var cells: [GridCell]
    var placements: [WordPlacement]

    init(
        size: Int = 10,
        cells: [GridCell] = [],
        placements: [WordPlacement] = []
    ) {
        let normalizedSize = max(1, size)

        self.size = normalizedSize
        self.cells = Self.normalizedCells(cells, size: normalizedSize)
        self.placements = placements
    }

    var coordinates: [GridCoordinate] {
        (0 ..< size).flatMap { row in
            (0 ..< size).map { column in
                GridCoordinate(row: row, column: column)
            }
        }
    }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        (0 ..< size).contains(coordinate.row) && (0 ..< size).contains(coordinate.column)
    }

    func index(for coordinate: GridCoordinate) -> Int? {
        guard contains(coordinate) else {
            return nil
        }

        return (coordinate.row * size) + coordinate.column
    }

    func canPlace(
        word: String,
        from start: GridCoordinate,
        direction: GridDirection
    ) -> Bool {
        let normalizedWord = Self.normalizedWord(word)
        guard !normalizedWord.isEmpty, normalizedWord.count <= size else {
            return false
        }

        let placement = WordPlacement(
            word: normalizedWord,
            start: start,
            direction: direction
        )

        for (letter, coordinate) in zip(normalizedWord, placement.coordinates) {
            guard let index = index(for: coordinate) else {
                return false
            }

            let existingLetter = cells[index].letter
            if let existingLetter, existingLetter != letter {
                return false
            }
        }

        return true
    }

    @discardableResult
    mutating func place(
        word: String,
        from start: GridCoordinate,
        direction: GridDirection
    ) -> Bool {
        let normalizedWord = Self.normalizedWord(word)
        guard canPlace(word: normalizedWord, from: start, direction: direction) else {
            return false
        }

        let placement = WordPlacement(
            word: normalizedWord,
            start: start,
            direction: direction
        )

        for (letter, coordinate) in zip(normalizedWord, placement.coordinates) {
            guard let index = index(for: coordinate) else {
                return false
            }

            cells[index].letter = letter
        }

        placements.append(placement)
        return true
    }

    mutating func place(words: [String]) -> Bool {
        let normalizedWords = words
            .map { Self.normalizedWord($0) }
            .filter { !$0.isEmpty }

        var candidate = Grid(size: size)
        var generator = SystemRandomNumberGenerator()

        guard candidate.placeAll(words: normalizedWords, using: &generator) else {
            return false
        }

        self = candidate
        return true
    }

    subscript(_ coordinate: GridCoordinate) -> GridCell? {
        guard let index = index(for: coordinate) else {
            return nil
        }

        return cells[safe: index]
    }

    private mutating func placeAll<R: RandomNumberGenerator>(
        words: [String],
        using generator: inout R
    ) -> Bool {
        for word in words.shuffled(using: &generator) {
            guard placeRandomly(word: word, using: &generator) else {
                return false
            }
        }

        fillEmptyCells(using: &generator)
        return true
    }

    private mutating func placeRandomly<R: RandomNumberGenerator>(
        word: String,
        using generator: inout R
    ) -> Bool {
        guard !word.isEmpty, word.count <= size else {
            return false
        }

        let shuffledCoordinates = coordinates.shuffled(using: &generator)
        let shuffledDirections = GridDirection.allCases.shuffled(using: &generator)

        for _ in 0 ..< 100 {
            guard
                let start = shuffledCoordinates.randomElement(using: &generator),
                let direction = shuffledDirections.randomElement(using: &generator)
            else {
                return false
            }

            if place(word: word, from: start, direction: direction) {
                return true
            }
        }

        return false
    }

    private mutating func fillEmptyCells<R: RandomNumberGenerator>(using generator: inout R) {
        for index in cells.indices where cells[index].letter == nil {
            cells[index].letter = Self.alphabet.randomElement(using: &generator)
        }
    }

    private static func normalizedWord(_ word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private static func normalizedCells(_ cells: [GridCell], size: Int) -> [GridCell] {
        guard cells.count == size * size else {
            return emptyCells(size: size)
        }

        return cells
    }

    private static func emptyCells(size: Int) -> [GridCell] {
        (0 ..< size).flatMap { row in
            (0 ..< size).map { column in
                GridCell(
                    coordinate: GridCoordinate(row: row, column: column),
                    letter: nil
                )
            }
        }
    }
}

struct GridCell: Identifiable, Equatable, Hashable, Sendable {
    var id: GridCoordinate { coordinate }
    let coordinate: GridCoordinate
    var letter: Character?
}

struct GridCoordinate: Hashable, Codable, Sendable {
    let row: Int
    let column: Int
}

typealias GridPosition = GridCoordinate

enum GridDirection: String, CaseIterable, Codable, Sendable {
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
    case northWest

    var rowStep: Int {
        switch self {
        case .north, .northEast, .northWest:
            -1
        case .east, .west:
            0
        case .south, .southEast, .southWest:
            1
        }
    }

    var columnStep: Int {
        switch self {
        case .north, .south:
            0
        case .northEast, .east, .southEast:
            1
        case .northWest, .west, .southWest:
            -1
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
