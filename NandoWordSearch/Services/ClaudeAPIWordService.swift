import Foundation

struct ClaudeAPIWordService: WordGenerationService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let modelName = "claude-haiku-4-5"
    private static let apiVersion = "2023-06-01"
    private static let requestTimeout: TimeInterval = 15
    private static let systemPrompt = """
    You are a word puzzle assistant. Always respond with valid JSON only. No markdown, no explanation, no preamble.
    """

    let provider: WordGenerationProvider = .claudeAPI

    private let apiKeyProviderOverride: (@Sendable () -> String?)?
    private let transportOverride: (@Sendable (URLRequest) async throws -> (Data, URLResponse))?

    init() {
        self.apiKeyProviderOverride = nil
        self.transportOverride = nil
    }

    init(
        apiKeyProvider: @escaping @Sendable () -> String?,
        transport: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) {
        self.apiKeyProviderOverride = apiKeyProvider
        self.transportOverride = transport
    }

    func generateWords(
        for theme: String,
        excluding previouslyUsedWords: [String]
    ) async throws -> [String] {
        let normalizedTheme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTheme.isEmpty else {
            throw WordGenerationError.invalidTheme
        }

        guard
            let apiKey = currentAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw WordGenerationError.missingAPIKey
        }

        var lastError: WordGenerationError = .invalidResponse

        for _ in 0 ..< 2 {
            do {
                let request = try buildRequest(theme: normalizedTheme, apiKey: apiKey)
                let (data, response) = try await performTransport(for: request)
                let responseText = try parseResponseText(data: data, response: response)
                let parsedWords = try WordGenerationValidator.parseJSONArray(from: responseText)
                return try WordGenerationValidator.validateWords(parsedWords)
            } catch let error as WordGenerationError {
                lastError = error
            } catch {
                lastError = .generationFailed(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func currentAPIKey() -> String? {
        if let apiKeyProviderOverride {
            return apiKeyProviderOverride()
        }

        return SettingsStore().anthropicAPIKey
    }

    private func performTransport(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let transportOverride {
            return try await transportOverride(request)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.requestTimeout
        let session = URLSession(configuration: configuration)
        return try await session.data(for: request)
    }

    private func buildRequest(theme: String, apiKey: String) throws -> URLRequest {
        let userPrompt = """
        Generate exactly 10 words for a word search puzzle with theme: \(theme).
        Rules:
        - 4 to 9 letters
        - Uppercase
        - No spaces or hyphens
        - Real English words only
        - All ages appropriate
        - Be creative and varied in your choices
        Return ONLY a JSON array:
        [\"WORD1\",\"WORD2\",...]
        """

        let body = ClaudeMessagesRequest(
            model: Self.modelName,
            maxTokens: 256,
            system: Self.systemPrompt,
            messages: [
                ClaudeMessage(role: "user", content: userPrompt),
            ]
        )

        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        return request
    }

    private func parseResponseText(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordGenerationError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unreadable response body."
            throw WordGenerationError.generationFailed(
                "Anthropic API returned HTTP \(httpResponse.statusCode): \(body)"
            )
        }

        let decodedResponse: ClaudeMessagesResponse
        do {
            decodedResponse = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)
        } catch {
            throw WordGenerationError.invalidResponse
        }

        let textBlocks = decodedResponse.content.compactMap { block -> String? in
            guard block.type == "text" else {
                return nil
            }

            return block.text
        }

        let text = textBlocks
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw WordGenerationError.invalidResponse
        }

        return text
    }
}

private struct ClaudeMessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

private struct ClaudeMessagesResponse: Decodable {
    let content: [ClaudeContentBlock]
}

private struct ClaudeContentBlock: Decodable {
    let type: String
    let text: String?
}
