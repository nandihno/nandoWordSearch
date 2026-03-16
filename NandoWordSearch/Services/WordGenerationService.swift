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
    case contacts

    var displayName: String {
        switch self {
        case .appleIntelligence:
            return "Apple Intelligence"
        case .claudeAPI:
            return "Claude Haiku 4.5"
        case .contacts:
            return "Your Contacts"
        }
    }

    var symbolName: String {
        switch self {
        case .appleIntelligence:
            return "apple.intelligence"
        case .claudeAPI:
            return "bubble.left.and.bubble.right"
        case .contacts:
            return "person.2.fill"
        }
    }
}

enum WordGenerationError: Error, Equatable, Sendable {
    case invalidTheme
    case unavailable(reason: String)
    case invalidResponse
    case invalidJSONResponse
    case invalidWordCount(expected: Int, actual: Int)
    case invalidWordFormat(String)
    case generationFailed(String)
    case unsupportedLanguageModel
    case missingAPIKey
}

typealias WordGenerationServiceError = WordGenerationError

extension WordGenerationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidTheme:
            "A non-empty theme is required."
        case .unavailable(let reason):
            "Word generation is unavailable: \(reason)"
        case .invalidResponse:
            "The model returned an invalid response."
        case .invalidJSONResponse:
            "The model did not return a valid JSON array of strings."
        case .invalidWordCount(let expected, let actual):
            "Expected \(expected) words but received \(actual)."
        case .invalidWordFormat(let word):
            "The generated word '\(word)' does not meet the format rules."
        case .generationFailed(let message):
            "Word generation failed: \(message)"
        case .unsupportedLanguageModel:
            "The selected language model is unsupported."
        case .missingAPIKey:
            "A required API key is missing."
        }
    }
}

enum WordGenerationValidator {
    private static let validWordPattern = /^[A-Z]{4,9}$/
    private static let recoverableWordPattern = /[A-Z]{4,9}/

    static func parseJSONArray(from responseText: String) throws -> [String] {
        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [
            trimmedResponse,
            stripMarkdownCodeFence(from: trimmedResponse),
            extractJSONArraySubstring(from: trimmedResponse),
        ]

        for candidate in candidates {
            guard let candidate, !candidate.isEmpty else {
                continue
            }

            guard let data = candidate.data(using: .utf8) else {
                continue
            }

            if let words = try? JSONDecoder().decode([String].self, from: data) {
                return words
            }

            if
                let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let words = payload["words"] as? [String]
            {
                return words
            }
        }

        throw WordGenerationError.invalidJSONResponse
    }

    static func validateWords(_ words: [String]) throws -> [String] {
        let normalizedWords = normalizeWords(words)

        guard normalizedWords.count == 10 else {
            throw WordGenerationError.invalidWordCount(expected: 10, actual: normalizedWords.count)
        }

        for word in normalizedWords {
            guard word.wholeMatch(of: validWordPattern) != nil else {
                throw WordGenerationError.invalidWordFormat(word)
            }
        }

        return normalizedWords
    }

    static func parseAndValidateLooseWords(from responseText: String) throws -> [String] {
        do {
            return try validateWords(parseJSONArray(from: responseText))
        } catch let error as WordGenerationError {
            guard error == .invalidJSONResponse else {
                throw error
            }

            return try validateWords([responseText])
        }
    }

    static func recoverCandidateWords(from responseText: String) -> [String] {
        if let parsedWords = try? parseJSONArray(from: responseText) {
            return normalizeWords(parsedWords)
        }

        return normalizeWords([responseText])
    }

    private static func stripMarkdownCodeFence(from text: String) -> String? {
        guard text.hasPrefix("```") else {
            return nil
        }

        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 3 else {
            return nil
        }

        let bodyLines = lines.dropFirst().dropLast()
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private static func extractJSONArraySubstring(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "[") else {
            return nil
        }

        var currentIndex = startIndex
        var depth = 0
        var isInsideString = false
        var isEscaping = false

        while currentIndex < text.endIndex {
            let character = text[currentIndex]

            if isEscaping {
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "\"" {
                isInsideString.toggle()
            } else if !isInsideString {
                if character == "[" {
                    depth += 1
                } else if character == "]" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[startIndex ... currentIndex])
                    }
                }
            }

            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }

    private static func normalizeWords(_ words: [String]) -> [String] {
        let trimmedWords = words
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            .filter { !$0.isEmpty }

        guard trimmedWords.count != 10 else {
            return trimmedWords
        }

        let recoveredWords = trimmedWords
            .joined(separator: "\n")
            .matches(of: recoverableWordPattern)
            .map { String($0.output) }

        guard recoveredWords.count == 10 else {
            return trimmedWords
        }

        return recoveredWords
    }
}
