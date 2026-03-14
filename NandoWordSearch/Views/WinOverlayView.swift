import SwiftUI

struct WinOverlayView: View {
    let timeText: String
    let isGenerating: Bool
    let isPersonalBest: Bool
    let wordTimes: [WordTime]
    let onPlayAgain: () -> Void
    let onNewTheme: () -> Void

    private let wordColors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.36),
        Color(red: 0.20, green: 0.60, blue: 0.94),
        Color(red: 0.23, green: 0.74, blue: 0.57),
        Color(red: 0.95, green: 0.67, blue: 0.20),
        Color(red: 0.87, green: 0.34, blue: 0.55),
        Color(red: 0.39, green: 0.42, blue: 0.90),
    ]

    init(
        timeText: String,
        isGenerating: Bool,
        isPersonalBest: Bool = false,
        wordTimes: [WordTime] = [],
        onPlayAgain: @escaping () -> Void,
        onNewTheme: @escaping () -> Void
    ) {
        self.timeText = timeText
        self.isGenerating = isGenerating
        self.isPersonalBest = isPersonalBest
        self.wordTimes = wordTimes
        self.onPlayAgain = onPlayAgain
        self.onNewTheme = onNewTheme
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            ConfettiView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerSection
                    timeHighlight

                    if !wordTimes.isEmpty {
                        wordTimesSection
                    }

                    buttonsSection
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground).opacity(0.94))
                        .shadow(color: .black.opacity(0.18), radius: 30, y: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: isPersonalBest
                                    ? [.yellow.opacity(0.4), .orange.opacity(0.3), .yellow.opacity(0.2)]
                                    : [.white.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                if isPersonalBest {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)
                }

                Image(systemName: isPersonalBest ? "trophy.fill" : "party.popper.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        isPersonalBest
                            ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }

            Text(isPersonalBest ? "New Personal Best!" : "Congratulations")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isPersonalBest
                        ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(.primary)
                )
        }
    }

    // MARK: - Time Highlight

    private var timeHighlight: some View {
        VStack(spacing: 6) {
            Text(timeText)
                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.60, blue: 0.94), Color(red: 0.39, green: 0.42, blue: 0.90)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Total Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.20, green: 0.60, blue: 0.94).opacity(0.08))
        )
    }

    // MARK: - Word Times

    private var wordTimesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Word Times", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if wordTimes.min(by: { $0.duration < $1.duration }) != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("= fastest")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }
            }

            let sorted = wordTimes.sorted(by: { $0.orderFound < $1.orderFound })
            let fastest = wordTimes.min(by: { $0.duration < $1.duration })
            let maxDuration = sorted.map(\.duration).max() ?? 1

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, wt in
                let color = wordColors[index % wordColors.count]
                let isFastest = wt.id == fastest?.id

                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(wt.word)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        let fraction = maxDuration > 0 ? wt.duration / maxDuration : 0
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.5), color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * fraction))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 14)

                    HStack(spacing: 3) {
                        if isFastest {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }

                        Text(formatWordTime(wt.duration))
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.5))
        )
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button(action: onPlayAgain) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                    Text("Play Again")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.60, blue: 0.94), Color(red: 0.39, green: 0.42, blue: 0.90)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .frame(minHeight: 44)
            .disabled(isGenerating)

            Button(action: onNewTheme) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("New Theme")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.39, green: 0.42, blue: 0.90))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.39, green: 0.42, blue: 0.90).opacity(0.12))
            )
            .frame(minHeight: 44)
            .disabled(isGenerating)
        }
    }

    private func formatWordTime(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes):" + String(format: "%02d", seconds)
        }

        let ms = Int((duration - Double(totalSeconds)) * 10)
        return "\(seconds).\(ms)s"
    }
}
