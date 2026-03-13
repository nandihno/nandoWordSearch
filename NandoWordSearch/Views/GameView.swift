import SwiftUI

struct GameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            let isWideLayout = horizontalSizeClass == .regular && proxy.size.width > proxy.size.height
            let gridWidth = isWideLayout
                ? min(proxy.size.width * 0.58, 860)
                : min(proxy.size.width - 40, 760)
            let gridHeight = isWideLayout
                ? proxy.size.height - 40
                : min(proxy.size.height * 0.58, gridWidth)

            ZStack {
                VStack(spacing: 20) {
                    header

                    if isWideLayout {
                        HStack(alignment: .top, spacing: 20) {
                            GridView(viewModel: viewModel)
                                .frame(width: gridWidth, height: gridHeight)

                            wordPanel
                                .frame(maxWidth: 360)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        GridView(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                            .frame(height: gridHeight)

                        wordPanel
                    }
                }
                .padding(20)
                .blur(radius: viewModel.allWordsFound ? 10 : 0)
                .animation(.snappy(duration: 0.3), value: viewModel.allWordsFound)

                if viewModel.allWordsFound {
                    WinOverlayView(
                        timeText: formattedElapsedTime,
                        isGenerating: viewModel.isGenerating,
                        onPlayAgain: playAgain,
                        onNewTheme: returnToThemeSelection
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .alert(
            "Puzzle Generation Failed",
            isPresented: Binding(
                get: { viewModel.generationError != nil && viewModel.isPuzzleReady },
                set: { isPresented in
                    if !isPresented {
                        viewModel.generationError = nil
                    }
                }
            )
        ) {
            Button("Retry", action: playAgain)
            Button("Dismiss", role: .cancel) {
                viewModel.generationError = nil
            }
        } message: {
            Text(viewModel.generationError?.localizedDescription ?? "Something went wrong.")
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.gameState.theme)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(1)

                if let provider = viewModel.activeProvider {
                    Label(provider.displayName, systemImage: provider.symbolName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label(formattedElapsedTime, systemImage: "timer")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button("New Game", systemImage: "plus.circle", action: returnToThemeSelection)
                .buttonStyle(.bordered)
                .frame(minWidth: 44, minHeight: 44)
                .controlSize(.regular)
        }
    }

    private var wordPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Words", systemImage: "text.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.gameState.foundWords.count)/\(viewModel.gameState.words.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            WordListView(words: viewModel.gameState.words)
                .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var formattedElapsedTime: String {
        formatDuration(viewModel.elapsedTime)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        return "\(minutes):" + String(format: "%02d", seconds)
    }

    private func returnToThemeSelection() {
        withAnimation(.snappy(duration: 0.25)) {
            viewModel.returnToThemeSelection()
        }
    }

    private func playAgain() {
        Task {
            await viewModel.playAgain()
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            viewModel.resumeGameplay()
        case .background, .inactive:
            viewModel.pauseGameplay()
        @unknown default:
            break
        }
    }
}
