import Combine
import Foundation
import FoundationModels

@MainActor
final class GameViewModel: ObservableObject {
    @Published var selectedCells: [GridPosition]
    @Published var foundWords: [FoundWord]
    @Published var allWordsFound: Bool
    @Published var isGenerating: Bool
    @Published var generationError: WordGenerationError?
    @Published var isPuzzleReady: Bool

    private(set) var gameState: GameState

    private var selectionStart: GridPosition?
    private var selectionDirection: GridDirection?
    private let onWordFound: () -> Void
    private let settingsStore: SettingsStore
    private let statsStore: StatsStore
    private let availabilityProvider: @MainActor () -> SystemLanguageModel.Availability
    private let appleServiceFactory: @MainActor () -> any WordGenerationService
    private let claudeServiceFactory: @MainActor () -> any WordGenerationService
    private var lastWordFoundAt: Date?
    private(set) var wordTimes: [WordTime] = []
    private(set) var lastGameStats: GameStats?

    convenience init(onWordFound: @escaping () -> Void = {}) {
        self.init(
            gameState: GameState(),
            onWordFound: onWordFound,
            settingsStore: SettingsStore(),
            statsStore: StatsStore(),
            availabilityProvider: {
                SystemLanguageModel.default.availability
            },
            appleServiceFactory: {
                AppleIntelligenceWordService()
            },
            claudeServiceFactory: {
                ClaudeAPIWordService()
            }
        )
    }

    convenience init(
        gameState: GameState,
        onWordFound: @escaping () -> Void = {}
    ) {
        self.init(
            gameState: gameState,
            onWordFound: onWordFound,
            settingsStore: SettingsStore(),
            statsStore: StatsStore(),
            availabilityProvider: {
                SystemLanguageModel.default.availability
            },
            appleServiceFactory: {
                AppleIntelligenceWordService()
            },
            claudeServiceFactory: {
                ClaudeAPIWordService()
            }
        )
    }

    init(
        gameState: GameState,
        onWordFound: @escaping () -> Void = {},
        settingsStore: SettingsStore,
        statsStore: StatsStore = StatsStore(),
        availabilityProvider: @escaping @MainActor () -> SystemLanguageModel.Availability = {
            SystemLanguageModel.default.availability
        },
        appleServiceFactory: @escaping @MainActor () -> any WordGenerationService = {
            AppleIntelligenceWordService()
        },
        claudeServiceFactory: @escaping @MainActor () -> any WordGenerationService = {
            ClaudeAPIWordService()
        }
    ) {
        self.gameState = gameState
        self.onWordFound = onWordFound
        self.settingsStore = settingsStore
        self.statsStore = statsStore
        self.availabilityProvider = availabilityProvider
        self.appleServiceFactory = appleServiceFactory
        self.claudeServiceFactory = claudeServiceFactory
        self.selectedCells = gameState.selection.coordinates
        self.foundWords = gameState.words.compactMap { word in
            guard word.isFound, let placement = word.placement else {
                return nil
            }

            return FoundWord(
                id: word.id,
                value: word.value,
                cells: placement.coordinates,
                highlightStyle: word.highlightStyle
            )
        }
        self.allWordsFound = !gameState.words.isEmpty && gameState.words.allSatisfy(\.isFound)
        self.isGenerating = gameState.phase == .generatingWords
        self.generationError = nil
        self.isPuzzleReady = gameState.phase == .playing || gameState.phase == .completed
    }

    func generatePuzzle(theme: String) async {
        await runGeneration(
            theme: theme,
            resetPresentationAtStart: true
        )
    }

    func playAgain() async {
        await runGeneration(
            theme: gameState.theme,
            resetPresentationAtStart: false
        )
    }

    func returnToThemeSelection() {
        isPuzzleReady = false
        isGenerating = false
        generationError = nil
        gameState.phase = .themeSelection
        clearSelection()
    }

    var elapsedTime: TimeInterval {
        guard let startedAt = gameState.startedAt else {
            return 0
        }

        let endDate = gameState.completedAt ?? gameState.pausedAt ?? Date()
        return max(0, endDate.timeIntervalSince(startedAt) - gameState.accumulatedPausedDuration)
    }

    var configuredProvider: WordGenerationProvider {
        if settingsStore.useClaudeGeneration, settingsStore.hasClaudeAPIKey {
            return .claudeAPI
        }

        return .appleIntelligence
    }

    var configuredProviderSummary: String {
        if settingsStore.useClaudeGeneration, settingsStore.hasClaudeAPIKey {
            return "Using Claude Haiku 4.5"
        }

        if settingsStore.useClaudeGeneration, !settingsStore.hasClaudeAPIKey {
            return "Using Apple Intelligence because no Claude API key is saved"
        }

        return "Using Apple Intelligence"
    }

    var activeProvider: WordGenerationProvider? {
        gameState.provider
    }

    func pauseGameplay() {
        guard gameState.phase == .playing, gameState.pausedAt == nil else {
            return
        }

        gameState.pausedAt = Date()
        clearSelection()
    }

    func resumeGameplay() {
        guard gameState.phase == .playing, let pausedAt = gameState.pausedAt else {
            return
        }

        gameState.accumulatedPausedDuration += Date().timeIntervalSince(pausedAt)
        gameState.pausedAt = nil
    }

    private func runGeneration(
        theme: String,
        resetPresentationAtStart: Bool
    ) async {
        let normalizedTheme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTheme.isEmpty, !isGenerating else {
            return
        }

        let previousPhase = gameState.phase
        isGenerating = true
        generationError = nil
        if resetPresentationAtStart {
            isPuzzleReady = false
        }
        gameState.phase = .generatingWords

        do {
            let previousWords = settingsStore.usedWords(for: normalizedTheme)
            let generationResult = try await generateWords(
                for: normalizedTheme,
                excluding: previousWords
            )
            let nextGameState = try makeGameState(
                theme: normalizedTheme,
                generatedWords: generationResult.words,
                provider: generationResult.provider
            )

            settingsStore.appendUsedWords(generationResult.words, for: normalizedTheme)
            gameState = nextGameState
            resetInteractionState()
            isPuzzleReady = true
        } catch let error as WordGenerationError {
            generationError = error
            gameState.phase = previousPhase == .themeSelection ? .failed : previousPhase
        } catch {
            generationError = .generationFailed(error.localizedDescription)
            gameState.phase = previousPhase == .themeSelection ? .failed : previousPhase
        }

        isGenerating = false
    }

    private func generateWords(
        for theme: String,
        excluding previouslyUsedWords: [String]
    ) async throws -> (words: [String], provider: WordGenerationProvider) {
        let primaryService = makeWordGenerationService()
        let primaryProvider = primaryService.provider

        do {
            let words = try await primaryService.generateWords(
                for: theme,
                excluding: previouslyUsedWords
            )
            return (words, primaryProvider)
        } catch let error as WordGenerationError {
            guard
                shouldFallbackToClaude(after: error, from: primaryProvider)
            else {
                throw error
            }

            let fallbackService = claudeServiceFactory()
            let fallbackProvider = fallbackService.provider
            let words = try await fallbackService.generateWords(
                for: theme,
                excluding: previouslyUsedWords
            )
            return (words, fallbackProvider)
        }
    }

    func beginSelection(at position: GridPosition) {
        guard gameState.grid.contains(position) else {
            clearSelection()
            return
        }

        selectionStart = position
        selectionDirection = nil
        selectedCells = [position]
        syncSelectionState(isActive: true)
    }

    func updateSelection(to position: GridPosition) {
        guard gameState.grid.contains(position) else {
            return
        }

        guard let selectionStart else {
            beginSelection(at: position)
            return
        }

        guard position != selectionStart else {
            selectedCells = [selectionStart]
            selectionDirection = nil
            syncSelectionState(isActive: true)
            return
        }

        let snapped = snapToLine(from: selectionStart, to: position)

        guard
            let candidateDirection = direction(from: selectionStart, to: snapped),
            let candidatePath = path(
                from: selectionStart,
                to: snapped,
                direction: candidateDirection
            )
        else {
            return
        }

        if let selectionDirection, selectionDirection != candidateDirection {
            return
        }

        self.selectionDirection = candidateDirection
        selectedCells = candidatePath
        syncSelectionState(isActive: true)
    }

    func updateSelection(at position: GridPosition) {
        updateSelection(to: position)
    }

    func endSelection() {
        defer {
            clearSelection()
        }

        guard !selectedCells.isEmpty else {
            return
        }

        let selectedWord = String(selectedCells.compactMap { cell in
            gameState.grid[cell]?.letter
        })

        guard selectedWord.count == selectedCells.count else {
            return
        }

        let reversedWord = String(selectedWord.reversed())
        guard let wordIndex = gameState.words.firstIndex(where: { word in
            !word.isFound && (word.value == selectedWord || word.value == reversedWord)
        }) else {
            return
        }

        gameState.words[wordIndex].status = .found

        let matchedWord = gameState.words[wordIndex]
        foundWords.append(
            FoundWord(
                id: matchedWord.id,
                value: matchedWord.value,
                cells: selectedCells,
                highlightStyle: matchedWord.highlightStyle
            )
        )

        let now = Date()
        let referenceTime = lastWordFoundAt ?? gameState.startedAt ?? now
        let wordDuration = now.timeIntervalSince(referenceTime)
        lastWordFoundAt = now
        wordTimes.append(
            WordTime(
                word: matchedWord.value,
                duration: wordDuration,
                orderFound: wordTimes.count + 1
            )
        )

        allWordsFound = !gameState.words.isEmpty && gameState.words.allSatisfy(\.isFound)
        if allWordsFound {
            gameState.phase = .completed
            gameState.completedAt = now
            saveGameStats()
        }

        onWordFound()
    }

    func commitSelection() {
        endSelection()
    }

    private func makeWordGenerationService() -> any WordGenerationService {
        if settingsStore.useClaudeGeneration, settingsStore.hasClaudeAPIKey {
            return claudeServiceFactory()
        }

        return appleServiceFactory()
    }

    private func shouldFallbackToClaude(
        after error: WordGenerationError,
        from provider: WordGenerationProvider
    ) -> Bool {
        guard
            provider == .appleIntelligence,
            settingsStore.useClaudeGeneration,
            settingsStore.hasClaudeAPIKey
        else {
            return false
        }

        switch error {
        case .unavailable,
             .invalidResponse,
             .invalidJSONResponse,
             .invalidWordCount,
             .invalidWordFormat,
             .generationFailed,
             .unsupportedLanguageModel:
            return true
        case .invalidTheme,
             .missingAPIKey:
            return false
        }
    }

    private func makeGameState(
        theme: String,
        generatedWords: [String],
        provider: WordGenerationProvider
    ) throws -> GameState {
        guard let placement = makeBestPlayablePlacement(from: generatedWords) else {
            throw WordGenerationError.generationFailed(
                "The generated words could not be placed in the grid."
            )
        }

        var placementsByWord = Dictionary(grouping: placement.grid.placements, by: \.word)
        let highlightStyles = WordHighlightStyle.allCases
        let words = placement.words.enumerated().map { index, value in
            let placement = placementsByWord[value]?.first
            placementsByWord[value] = placementsByWord[value]?.dropFirst().map { $0 }

            return Word(
                value: value,
                highlightStyle: highlightStyles[index % highlightStyles.count],
                placement: placement
            )
        }

        return GameState(
            theme: theme,
            grid: placement.grid,
            words: words,
            phase: .playing,
            provider: provider,
            background: .random,
            startedAt: Date(),
            pausedAt: nil,
            accumulatedPausedDuration: 0
        )
    }

    private func makeBestPlayablePlacement(
        from generatedWords: [String]
    ) -> (grid: Grid, words: [String])? {
        for count in stride(from: generatedWords.count, through: 1, by: -1) {
            var grid = Grid(size: 10)
            let candidateWords = Array(generatedWords.prefix(count))
            if grid.place(words: candidateWords) {
                return (grid, candidateWords)
            }
        }

        return nil
    }

    private func saveGameStats() {
        let stats = GameStats(
            theme: gameState.theme,
            totalTime: elapsedTime,
            wordCount: gameState.words.count,
            wordTimes: wordTimes,
            completedAt: gameState.completedAt ?? Date()
        )
        statsStore.save(stats)
        lastGameStats = stats
    }

    var isPersonalBest: Bool {
        guard let stats = lastGameStats else { return false }
        return statsStore.isPersonalBestTime(stats.totalTime)
    }

    private func resetInteractionState() {
        selectionStart = nil
        selectionDirection = nil
        selectedCells = []
        foundWords = []
        allWordsFound = false
        lastWordFoundAt = nil
        wordTimes = []
        lastGameStats = nil
        syncSelectionState(isActive: false)
    }

    private func restartSelection(at position: GridPosition) {
        guard gameState.grid.contains(position) else {
            clearSelection()
            return
        }

        selectionStart = position
        selectionDirection = nil
        selectedCells = [position]
        syncSelectionState(isActive: true)
    }

    private func clearSelection() {
        selectionStart = nil
        selectionDirection = nil
        selectedCells = []
        syncSelectionState(isActive: false)
    }

    private func syncSelectionState(isActive: Bool) {
        gameState.selection = GridSelection(
            coordinates: selectedCells,
            isActive: isActive && !selectedCells.isEmpty
        )
    }

    private func snapToLine(
        from start: GridPosition,
        to end: GridPosition
    ) -> GridPosition {
        let dr = end.row - start.row
        let dc = end.column - start.column

        guard dr != 0 || dc != 0 else {
            return end
        }

        let absDr = abs(dr)
        let absDc = abs(dc)

        if selectionDirection != nil {
            let dist = max(absDr, absDc)
            return GridPosition(
                row: start.row + selectionDirection!.rowStep * dist,
                column: start.column + selectionDirection!.columnStep * dist
            )
        }

        let angle = atan2(Double(dr), Double(dc))
        let sector = (angle / (.pi / 4)).rounded()

        let snappedRow: Int
        let snappedColumn: Int

        switch Int(sector) {
        case 0:
            snappedRow = start.row
            snappedColumn = start.column + absDc
        case 1:
            let dist = max(absDr, absDc)
            snappedRow = start.row + dist
            snappedColumn = start.column + dist
        case 2, -2:
            snappedRow = start.row + (dr > 0 ? absDr : -absDr)
            snappedColumn = start.column
        case 3, -3:
            let dist = max(absDr, absDc)
            snappedRow = start.row + (dr > 0 ? dist : -dist)
            snappedColumn = start.column - dist
        case 4, -4:
            snappedRow = start.row
            snappedColumn = start.column - absDc
        case -1:
            let dist = max(absDr, absDc)
            snappedRow = start.row - dist
            snappedColumn = start.column + dist
        default:
            snappedRow = end.row
            snappedColumn = end.column
        }

        let gridSize = gameState.grid.size
        return GridPosition(
            row: max(0, min(gridSize - 1, snappedRow)),
            column: max(0, min(gridSize - 1, snappedColumn))
        )
    }

    private func direction(
        from start: GridPosition,
        to end: GridPosition
    ) -> GridDirection? {
        let rowDelta = end.row - start.row
        let columnDelta = end.column - start.column

        guard rowDelta != 0 || columnDelta != 0 else {
            return nil
        }

        let absoluteRowDelta = abs(rowDelta)
        let absoluteColumnDelta = abs(columnDelta)
        let isStraight = rowDelta == 0 || columnDelta == 0
        let isDiagonal = absoluteRowDelta == absoluteColumnDelta

        guard isStraight || isDiagonal else {
            return nil
        }

        let normalizedRow = rowDelta.signum()
        let normalizedColumn = columnDelta.signum()

        switch (normalizedRow, normalizedColumn) {
        case (-1, 0):
            return .north
        case (-1, 1):
            return .northEast
        case (0, 1):
            return .east
        case (1, 1):
            return .southEast
        case (1, 0):
            return .south
        case (1, -1):
            return .southWest
        case (0, -1):
            return .west
        case (-1, -1):
            return .northWest
        default:
            return nil
        }
    }

    private func path(
        from start: GridPosition,
        to end: GridPosition,
        direction: GridDirection
    ) -> [GridPosition]? {
        let rowDistance = abs(end.row - start.row)
        let columnDistance = abs(end.column - start.column)
        let stepCount = max(rowDistance, columnDistance)

        let positions = (0 ... stepCount).map { step in
            GridPosition(
                row: start.row + (direction.rowStep * step),
                column: start.column + (direction.columnStep * step)
            )
        }

        guard positions.last == end else {
            return nil
        }

        guard positions.allSatisfy({ gameState.grid.contains($0) }) else {
            return nil
        }

        return positions
    }
}
