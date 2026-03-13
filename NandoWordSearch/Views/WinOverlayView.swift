import SwiftUI

struct WinOverlayView: View {
    let timeText: String
    let isGenerating: Bool
    let onPlayAgain: () -> Void
    let onNewTheme: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.orange)

                Text("Congratulations")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("You found every word in \(timeText).")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button("Play Again", systemImage: "arrow.clockwise.circle.fill", action: onPlayAgain)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(isGenerating)

                Button("New Theme", systemImage: "sparkles", action: onNewTheme)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(isGenerating)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.92))
                    .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
            )
            .padding(24)
        }
    }
}
