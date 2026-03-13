import Foundation

final class SettingsStore {
    static let anthropicAPIKeyDefaultsKey = "anthropic_api_key"
    static let useClaudeDefaultsKey = "use_claude_generation"
    private static let usedWordsPrefix = "used_words_for_theme_"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var anthropicAPIKey: String {
        get {
            defaults.string(forKey: Self.anthropicAPIKeyDefaultsKey) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Self.anthropicAPIKeyDefaultsKey)
        }
    }

    var useClaudeGeneration: Bool {
        get {
            defaults.bool(forKey: Self.useClaudeDefaultsKey)
        }
        set {
            defaults.set(newValue, forKey: Self.useClaudeDefaultsKey)
        }
    }

    var hasClaudeAPIKey: Bool {
        !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func usedWords(for theme: String) -> [String] {
        defaults.stringArray(forKey: usedWordsKey(for: theme)) ?? []
    }

    func appendUsedWords(_ words: [String], for theme: String) {
        let normalizedWords = words
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            .filter { !$0.isEmpty }

        guard !normalizedWords.isEmpty else {
            return
        }

        var history = usedWords(for: theme)
        for word in normalizedWords {
            history.removeAll(where: { $0 == word })
            history.append(word)
        }

        defaults.set(Array(history.suffix(200)), forKey: usedWordsKey(for: theme))
    }

    private func usedWordsKey(for theme: String) -> String {
        let normalizedTheme = theme
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return Self.usedWordsPrefix + normalizedTheme
    }
}
