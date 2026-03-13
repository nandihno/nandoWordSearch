import XCTest
@testable import NandoWordSearch

final class ClaudeAPIWordServiceTests: XCTestCase {
    func testBuildsAnthropicRequestWithRequiredHeadersPromptsAndTimeout() async throws {
        var capturedRequest: URLRequest?

        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                capturedRequest = request
                return (
                    Data("""
                    {"content":[{"type":"text","text":"[\\"ALPHA\\",\\"BRAVO\\",\\"CHARL\\",\\"DELTA\\",\\"EAGLE\\",\\"FJORD\\",\\"GHOST\\",\\"HOTEL\\",\\"INDIA\\",\\"JOKER\\"]"}]}
                    """.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        _ = try await service.generateWords(for: "Space", excluding: [])

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 15, accuracy: 0.001)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        let bodyData = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        XCTAssertEqual(json["model"] as? String, "claude-haiku-4-5")
        XCTAssertEqual(
            json["system"] as? String,
            "You are a word puzzle assistant. Always respond with valid JSON only. No markdown, no explanation, no preamble."
        )

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let userPrompt = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(userPrompt.contains("theme: Space"))
        XCTAssertTrue(userPrompt.contains("Be creative and varied in your choices"))
    }

    func testRetriesOnceWhenFirstClaudeResponseFailsValidation() async throws {
        var attemptCount = 0

        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                attemptCount += 1
                let text: String
                if attemptCount == 1 {
                    text = #"["BAD","lowercase"]"#
                } else {
                    text = #"["ALPHA","BRAVO","CHARL","DELTA","EAGLE","FJORD","GHOST","HOTEL","INDIA","JOKER"]"#
                }

                return (
                    Data("""
                    {"content":[{"type":"text","text":\(text.debugDescription)}]}
                    """.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let words = try await service.generateWords(for: "Ocean", excluding: [])

        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(words.count, 10)
    }

    func testThrowsMissingAPIKeyWhenKeyIsBlank() async {
        let service = ClaudeAPIWordService(
            apiKeyProvider: { "   " },
            transport: { _ in
                XCTFail("Transport should not be called without an API key.")
                throw WordGenerationError.invalidResponse
            }
        )

        do {
            _ = try await service.generateWords(for: "Music", excluding: [])
            XCTFail("Expected missing API key.")
        } catch let error as WordGenerationError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParsesJSONArrayWrappedInMarkdownFence() async throws {
        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                (
                    Data("""
                    {"content":[{"type":"text","text":"```json\\n[\\"ALPHA\\",\\"BRAVO\\",\\"CHARL\\",\\"DELTA\\",\\"EAGLE\\",\\"FJORD\\",\\"GHOST\\",\\"HOTEL\\",\\"INDIA\\",\\"JOKER\\"]\\n```"}]}
                    """.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let words = try await service.generateWords(for: "Space", excluding: [])

        XCTAssertEqual(words.count, 10)
        XCTAssertEqual(words.first, "ALPHA")
    }

    func testParsesJSONArrayWhenClaudeAddsPreambleText() async throws {
        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                (
                    Data("""
                    {"content":[{"type":"text","text":"Here is the JSON array you requested: [\\"ALPHA\\",\\"BRAVO\\",\\"CHARL\\",\\"DELTA\\",\\"EAGLE\\",\\"FJORD\\",\\"GHOST\\",\\"HOTEL\\",\\"INDIA\\",\\"JOKER\\"]"}]}
                    """.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let words = try await service.generateWords(for: "Space", excluding: [])

        XCTAssertEqual(words.count, 10)
        XCTAssertEqual(words.last, "JOKER")
    }

    func testParsesWordsArrayWrappedInObjectAcrossMultipleTextBlocks() async throws {
        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                (
                    Data("""
                    {"content":[{"type":"text","text":"{\\"words\\":"},{"type":"text","text":"[\\"ALPHA\\",\\"BRAVO\\",\\"CHARL\\",\\"DELTA\\",\\"EAGLE\\",\\"FJORD\\",\\"GHOST\\",\\"HOTEL\\",\\"INDIA\\",\\"JOKER\\"]}"}]}
                    """.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        let words = try await service.generateWords(for: "Space", excluding: [])

        XCTAssertEqual(words.count, 10)
        XCTAssertEqual(words[3], "DELTA")
    }

    func testThrowsGenerationFailedForHTTPErrorResponse() async {
        let service = ClaudeAPIWordService(
            apiKeyProvider: { "test-key" },
            transport: { request in
                (
                    Data(#"{"error":"rate_limited"}"#.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 429,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        do {
            _ = try await service.generateWords(for: "Sport", excluding: [])
            XCTFail("Expected HTTP failure.")
        } catch let error as WordGenerationError {
            switch error {
            case .generationFailed(let message):
                XCTAssertTrue(message.contains("HTTP 429"))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
