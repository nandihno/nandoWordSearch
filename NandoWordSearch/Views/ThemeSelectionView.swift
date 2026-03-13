import SwiftUI

struct ThemeSelectionView: View {
    private let suggestedThemes = [
        "Space",
        "Music",
        "Ocean",
        "Animals",
        "Sport",
        "Food",
        "Nature",
        "Science",
        "History",
        "Travel",
    ]

    @StateObject private var viewModel: GameViewModel
    @State private var themeText = ""
    @State private var isShowingSettings = false

    init(viewModel: GameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: GameViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("Word Search")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "text.magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Pick a theme and generate a fresh puzzle with AI-powered word selection.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        providerBadge(
                            title: viewModel.configuredProvider.displayName,
                            subtitle: viewModel.configuredProviderSummary,
                            symbolName: viewModel.configuredProvider.symbolName
                        )
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Theme")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            TextField("Enter a theme...", text: $themeText)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .font(.body)

                            if !themeText.isEmpty {
                                Button(action: clearThemeText) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Clear theme")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(uiColor: .separator), lineWidth: 1)
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestedThemes, id: \.self) { theme in
                                    Button(theme, action: {
                                        selectSuggestedTheme(theme)
                                    })
                                    .buttonStyle(.borderedProminent)
                                    .frame(minHeight: 44)
                                    .tint(themeText == theme ? .accentColor : Color(uiColor: .tertiarySystemFill))
                                    .foregroundStyle(themeText == theme ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        Button("Surprise Me", systemImage: "dice.fill", action: surpriseMe)
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
                    )

                    Button(action: generatePuzzle) {
                        HStack(spacing: 12) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .font(.headline)
                            }

                            Text(viewModel.isGenerating ? "Generating..." : "Generate Puzzle")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(themeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating ? Color.gray.opacity(0.45) : Color.accentColor)
                    )
                    .disabled(themeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape", action: openSettings)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .navigationDestination(isPresented: $viewModel.isPuzzleReady) {
                GameView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert(
                "Puzzle Generation Failed",
                isPresented: Binding(
                    get: { viewModel.generationError != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.generationError = nil
                        }
                    }
                )
            ) {
                Button("Retry", action: retryGeneration)
                Button("Dismiss", role: .cancel) {
                    viewModel.generationError = nil
                }
            } message: {
                Text(viewModel.generationError?.localizedDescription ?? "Something went wrong.")
            }
        }
    }

    private func clearThemeText() {
        themeText = ""
    }

    private func selectSuggestedTheme(_ theme: String) {
        themeText = theme
    }

    private func surpriseMe() {
        themeText = suggestedThemes.randomElement() ?? themeText
    }

    private func generatePuzzle() {
        Task {
            await viewModel.generatePuzzle(theme: themeText)
        }
    }

    private func retryGeneration() {
        generatePuzzle()
    }

    private func openSettings() {
        isShowingSettings = true
    }

    private func providerBadge(
        title: String,
        subtitle: String,
        symbolName: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbolName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}
