import FoundationModels
import XCTest
@testable import NandoWordSearch

final class AppleIntelligenceWordServiceTests: XCTestCase {
    func testPromptIncludesThemeSaltPickedInstructionsAndLastThirtyUsedWords() async throws {
        var capturedPrompt = ""

        let service = AppleIntelligenceWordService(
            availabilityProvider: { .available },
            responseGenerator: { prompt in
                capturedPrompt = prompt
                return """
                ["ALPHA","BRAVO","CHARL","DELTA","EAGLE","FJORD","GHOST","HOTEL","INDIA","JOKER"]
                """
            },
            saltGenerator: { 4242 },
            varietyPicker: { _ in "inventive and authentic" },
            avoidPicker: { _ in "Bypass common associations for this theme." }
        )

        let usedWords = (1 ... 35).map { "WORD\($0)" }
        _ = try await service.generateWords(for: "Ocean", excluding: usedWords)

        XCTAssertTrue(capturedPrompt.contains("theme: Ocean"))
        XCTAssertTrue(capturedPrompt.contains("inventive and authentic"))
        XCTAssertTrue(capturedPrompt.contains("Bypass common associations for this theme."))
        XCTAssertTrue(capturedPrompt.contains("Salt: 4242"))
        XCTAssertFalse(capturedPrompt.contains("WORD1"))
        XCTAssertTrue(capturedPrompt.contains("WORD35"))
    }

    func testRetriesOnceWhenFirstResponseFailsValidation() async throws {
        var attemptCount = 0

        let service = AppleIntelligenceWordService(
            availabilityProvider: { .available },
            responseGenerator: { _ in
                attemptCount += 1
                if attemptCount == 1 {
                    return #"["lowercase","BAD"]"#
                }

                return """
                ["ALPHA","BRAVO","CHARL","DELTA","EAGLE","FJORD","GHOST","HOTEL","INDIA","JOKER"]
                """
            },
            saltGenerator: { 1111 },
            varietyPicker: { options in options[0] },
            avoidPicker: { options in options[0] }
        )

        let words = try await service.generateWords(for: "Space", excluding: [])

        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(words.count, 10)
    }

    func testThrowsUnavailableErrorWhenModelIsNotAvailable() async {
        let service = AppleIntelligenceWordService(
            availabilityProvider: { .unavailable(.modelNotReady) },
            responseGenerator: { _ in
                XCTFail("Generation should not be attempted when unavailable.")
                return "[]"
            },
            saltGenerator: { 1111 },
            varietyPicker: { options in options[0] },
            avoidPicker: { options in options[0] }
        )

        do {
            _ = try await service.generateWords(for: "Music", excluding: [])
            XCTFail("Expected unavailable error.")
        } catch let error as WordGenerationError {
            switch error {
            case .unavailable(let reason):
                XCTAssertTrue(reason.contains("modelNotReady"))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testThrowsJSONParsingErrorAfterRetryingInvalidJSON() async {
        var attemptCount = 0

        let service = AppleIntelligenceWordService(
            availabilityProvider: { .available },
            responseGenerator: { _ in
                attemptCount += 1
                return "not json"
            },
            saltGenerator: { 1111 },
            varietyPicker: { options in options[0] },
            avoidPicker: { options in options[0] }
        )

        do {
            _ = try await service.generateWords(for: "Sport", excluding: [])
            XCTFail("Expected JSON parsing failure.")
        } catch let error as WordGenerationError {
            XCTAssertEqual(error, .invalidJSONResponse)
            XCTAssertEqual(attemptCount, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
