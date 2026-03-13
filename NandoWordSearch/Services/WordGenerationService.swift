import Foundation

protocol WordGenerationService: Sendable {
    var provider: WordGenerationProvider { get }

    func generateWords(
        for theme: String,
        excluding previouslyUsedWords: [String]
    ) async throws -> [String]
}

extension WordGenerationService {
    func generateWords(for theme: String) async throws -> [String] {
        try await generateWords(for: theme, excluding: [])
    }
}

enum WordGenerationProvider: String, CaseIterable, Codable, Sendable {
    case appleIntelligence
    case claudeAPI
}

enum WordGenerationServiceError: Error, Equatable, Sendable {
    case invalidTheme
    case invalidResponse
    case invalidWordCount(expected: Int, actual: Int)
    case unsupportedLanguageModel
    case missingAPIKey
}
