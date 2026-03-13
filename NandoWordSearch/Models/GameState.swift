import Foundation

struct GameState: Equatable, Sendable {
    var theme: String
    var grid: Grid
    var words: [Word]
    var selection: GridSelection
    var phase: GamePhase
    var provider: WordGenerationProvider?
    var startedAt: Date?
    var completedAt: Date?

    init(
        theme: String = "",
        grid: Grid = Grid(),
        words: [Word] = [],
        selection: GridSelection = .idle,
        phase: GamePhase = .themeSelection,
        provider: WordGenerationProvider? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.theme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        self.grid = grid
        self.words = words
        self.selection = selection
        self.phase = phase
        self.provider = provider
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    var foundWords: [Word] {
        words.filter(\.isFound)
    }

    var remainingWords: [Word] {
        words.filter { !$0.isFound }
    }

    var hasWon: Bool {
        !words.isEmpty && remainingWords.isEmpty
    }
}

enum GamePhase: String, Codable, Sendable {
    case themeSelection
    case generatingWords
    case ready
    case playing
    case completed
    case failed
}

struct GridSelection: Equatable, Sendable {
    var coordinates: [GridCoordinate]
    var isActive: Bool

    static let idle = GridSelection()

    init(
        coordinates: [GridCoordinate] = [],
        isActive: Bool = false
    ) {
        self.coordinates = coordinates
        self.isActive = isActive
    }

    var start: GridCoordinate? {
        coordinates.first
    }

    var end: GridCoordinate? {
        coordinates.last
    }
}
