import Foundation

struct Word: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var value: String
    var status: WordStatus
    var highlightStyle: WordHighlightStyle
    var placement: WordPlacement?

    init(
        id: UUID = UUID(),
        value: String,
        status: WordStatus = .pending,
        highlightStyle: WordHighlightStyle = .sky,
        placement: WordPlacement? = nil
    ) {
        self.id = id
        self.value = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.status = status
        self.highlightStyle = highlightStyle
        self.placement = placement
    }

    var isFound: Bool {
        status == .found
    }

    var letters: [Character] {
        Array(value)
    }
}

enum WordStatus: String, Codable, Sendable {
    case pending
    case found
}

struct WordPlacement: Equatable, Hashable, Sendable {
    let word: String
    let start: GridCoordinate
    let direction: GridDirection

    init(word: String, start: GridCoordinate, direction: GridDirection) {
        self.word = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.start = start
        self.direction = direction
    }

    var length: Int {
        word.count
    }

    var coordinates: [GridCoordinate] {
        (0 ..< length).map { offset in
            GridCoordinate(
                row: start.row + (direction.rowStep * offset),
                column: start.column + (direction.columnStep * offset)
            )
        }
    }
}

enum WordHighlightStyle: String, CaseIterable, Codable, Sendable {
    case coral
    case sky
    case mint
    case amber
    case rose
    case indigo
}
