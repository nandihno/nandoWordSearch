import Foundation
import FoundationModels

struct AppleIntelligenceWordService: WordGenerationService {
    private static let varietyModifiers = [
        "obscure yet real",
        "unexpected and creative",
        "unusual but genuine",
        "surprising and uncommon",
        "inventive and authentic",
    ]

    private static let avoidInstructions = [
        "Think beyond the first words that come to mind.",
        "Avoid the most predictable choices.",
        "Skip the obvious — dig for hidden gems.",
        "Challenge yourself to go deeper into the theme.",
        "Bypass common associations for this theme.",
    ]

    let provider: WordGenerationProvider = .appleIntelligence

    private let availabilityProvider: @Sendable () -> SystemLanguageModel.Availability
    private let responseGeneratorOverride: (@Sendable (String) async throws -> String)?
    private let saltGenerator: @Sendable () -> Int
    private let varietyPicker: @Sendable ([String]) -> String
    private let avoidPicker: @Sendable ([String]) -> String

    @MainActor
    private final class LanguageModelResponder {
        func respondWords(to prompt: String) async throws -> [String] {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: [String].self,
                includeSchemaInPrompt: true
            )
            return response.content
        }

        func respondText(to prompt: String) async throws -> String {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
    }

    init() {
        self.availabilityProvider = {
            SystemLanguageModel.default.availability
        }
        self.responseGeneratorOverride = nil
        self.saltGenerator = {
            Int.random(in: 1000 ... 9999)
        }
        self.varietyPicker = { options in
            options.randomElement() ?? options[0]
        }
        self.avoidPicker = { options in
            options.randomElement() ?? options[0]
        }
    }

    init(
        availabilityProvider: @escaping @Sendable () -> SystemLanguageModel.Availability,
        responseGenerator: @escaping @Sendable (String) async throws -> String,
        saltGenerator: @escaping @Sendable () -> Int,
        varietyPicker: @escaping @Sendable ([String]) -> String,
        avoidPicker: @escaping @Sendable ([String]) -> String
    ) {
        self.availabilityProvider = availabilityProvider
        self.responseGeneratorOverride = responseGenerator
        self.saltGenerator = saltGenerator
        self.varietyPicker = varietyPicker
        self.avoidPicker = avoidPicker
    }

    func generateWords(
        for theme: String,
        excluding previouslyUsedWords: [String]
    ) async throws -> [String] {
        let normalizedTheme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTheme.isEmpty else {
            throw WordGenerationError.invalidTheme
        }

        switch availabilityProvider() {
        case .available:
            break
        case .unavailable(let reason):
            throw WordGenerationError.unavailable(reason: String(describing: reason))
        }

        var lastError: WordGenerationError = .invalidResponse
        var excludedWords = previouslyUsedWords

        for _ in 0 ..< 2 {
            let prompt = makePrompt(
                theme: normalizedTheme,
                usedWords: excludedWords
            )

            do {
                if let responseGeneratorOverride {
                    let response = try await responseGeneratorOverride(prompt)
                    do {
                        return try parseAndValidate(response)
                    } catch let error as WordGenerationError {
                        excludedWords.append(contentsOf: WordGenerationValidator.recoverCandidateWords(from: response))
                        throw error
                    }
                }

                do {
                    let generatedWords = try await generateWordsWithSchema(for: prompt)
                    do {
                        return try WordGenerationValidator.validateWords(generatedWords)
                    } catch let error as WordGenerationError {
                        excludedWords.append(contentsOf: generatedWords)

                        switch error {
                        case .invalidWordCount, .invalidWordFormat:
                            let textResponse = try await generateTextResponse(for: prompt)
                            do {
                                return try parseAndValidate(textResponse)
                            } catch let textError as WordGenerationError {
                                excludedWords.append(contentsOf: WordGenerationValidator.recoverCandidateWords(from: textResponse))
                                throw textError
                            }
                        default:
                            throw error
                        }
                    }
                } catch let error as WordGenerationError {
                    throw error
                }
            } catch let error as WordGenerationError {
                lastError = error
            } catch {
                lastError = .generationFailed(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func makePrompt(theme: String, usedWords: [String]) -> String {
        let varietyModifier = varietyPicker(Self.varietyModifiers)
        let avoidInstruction = avoidPicker(Self.avoidInstructions)
        let salt = saltGenerator()
        let cappedUsedWords = Array(
            usedWords
                .map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                }
                .filter { !$0.isEmpty }
                .suffix(30)
        )

        var prompt = """
        Generate exactly 10 words for a word search puzzle with theme: \(theme).
        Choose words that are \(varietyModifier).
        \(avoidInstruction)
        Salt: \(salt)

        Rules:
        - Exactly 10 words
        - Each word must be 4-9 letters
        - Never include words with 10 or more letters
        - If a candidate word is too long, replace it with a different valid word
        - Uppercase only
        - No spaces
        - Real words only
        - All ages appropriate
        - Return ONLY a JSON array of exactly 10 uppercase strings
        """

        if !cappedUsedWords.isEmpty {
            prompt += "\nExclude these previously used words: \(cappedUsedWords)"
        }

        return prompt
    }

    private func parseAndValidate(_ response: String) throws -> [String] {
        try WordGenerationValidator.parseAndValidateLooseWords(from: response)
    }

    private func generateWordsWithSchema(for prompt: String) async throws -> [String] {
        do {
            let responder = await MainActor.run {
                LanguageModelResponder()
            }
            return try await responder.respondWords(to: prompt)
        } catch let error as LanguageModelSession.GenerationError {
            throw mapGenerationError(error)
        } catch {
            throw error
        }
    }

    private func generateTextResponse(for prompt: String) async throws -> String {
        do {
            let responder = await MainActor.run {
                LanguageModelResponder()
            }
            return try await responder.respondText(to: prompt)
        } catch let error as LanguageModelSession.GenerationError {
            throw mapGenerationError(error)
        } catch {
            throw error
        }
    }

    private func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> WordGenerationError {
        if let description = error.errorDescription, !description.isEmpty {
            return .generationFailed(description)
        }

        return .generationFailed(String(describing: error))
    }
}
