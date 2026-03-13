import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var useClaudeGeneration: Bool
    @State private var apiKey: String

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        _useClaudeGeneration = State(initialValue: settingsStore.useClaudeGeneration)
        _apiKey = State(initialValue: settingsStore.anthropicAPIKey)
    }

    @MainActor
    init() {
        let settingsStore = SettingsStore()
        self.init(settingsStore: settingsStore)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Generation Provider") {
                    Toggle("Use Claude", isOn: $useClaudeGeneration)

                    if useClaudeGeneration {
                        SecureField("Claude API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)

                        Text(providerStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Apple Intelligence will be used when available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss.callAsFunction)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onChange(of: useClaudeGeneration, initial: false) { _, newValue in
                settingsStore.useClaudeGeneration = newValue
            }
            .onChange(of: apiKey, initial: false) { _, newValue in
                settingsStore.anthropicAPIKey = newValue
            }
        }
    }

    private var providerStatusText: String {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No Claude API key saved. Word generation will fall back to Apple Intelligence."
        }

        return "Claude will be used for word generation while this toggle is enabled."
    }
}
