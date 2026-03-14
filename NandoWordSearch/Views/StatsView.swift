import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss

    private let statsStore: StatsStore
    private let games: [GameStats]
    private let personalBests: PersonalBests

    init(statsStore: StatsStore = StatsStore()) {
        self.statsStore = statsStore
        self.games = statsStore.allGames.sorted(by: { $0.completedAt > $1.completedAt })
        self.personalBests = statsStore.personalBests
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if games.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        personalBestsSection
                        overallSection
                        recentGamesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: { dismiss() })
                        .fontWeight(.semibold)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .yellow.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("No Games Yet")
                .font(.title2.weight(.bold))

            Text("Complete a puzzle to start\ntracking your stats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Personal Bests

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Personal Bests", systemImage: "trophy.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(spacing: 12) {
                if let fastest = personalBests.fastestGame {
                    PersonalBestCard(
                        icon: "bolt.fill",
                        gradient: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.3)],
                        title: "Fastest Game",
                        value: formatDuration(fastest.totalTime),
                        detail: fastest.theme
                    )
                }

                if let fastestWord = personalBests.fastestWord {
                    PersonalBestCard(
                        icon: "hare.fill",
                        gradient: [Color(red: 0.23, green: 0.74, blue: 0.57), Color(red: 0.18, green: 0.58, blue: 0.82)],
                        title: "Fastest Word",
                        value: formatDuration(fastestWord.duration),
                        detail: fastestWord.word
                    )
                }

                if let bestAvg = personalBests.bestAverageWordTime {
                    PersonalBestCard(
                        icon: "chart.line.downtrend.xyaxis",
                        gradient: [Color(red: 0.39, green: 0.42, blue: 0.90), Color(red: 0.60, green: 0.35, blue: 0.90)],
                        title: "Best Avg Word Time",
                        value: formatDuration(bestAvg.averageWordTime),
                        detail: bestAvg.theme
                    )
                }
            }
        }
    }

    // MARK: - Overall

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Overall", systemImage: "chart.bar.fill")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                OverallStatCard(
                    icon: "gamecontroller.fill",
                    color: Color(red: 0.87, green: 0.34, blue: 0.55),
                    title: "Games",
                    value: "\(games.count)"
                )

                OverallStatCard(
                    icon: "textformat.abc",
                    color: Color(red: 0.20, green: 0.60, blue: 0.94),
                    title: "Words",
                    value: "\(games.reduce(0) { $0 + $1.wordCount })"
                )

                let themes = Set(games.map { $0.theme.lowercased() })
                OverallStatCard(
                    icon: "paintpalette.fill",
                    color: Color(red: 0.95, green: 0.67, blue: 0.20),
                    title: "Themes",
                    value: "\(themes.count)"
                )
            }
        }
    }

    // MARK: - Recent Games

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Recent Games", systemImage: "clock.fill")
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                let fastestOverall = games.min(by: { $0.totalTime < $1.totalTime })

                ForEach(Array(games.prefix(20).enumerated()), id: \.element.id) { index, game in
                    NavigationLink {
                        GameStatsDetailView(game: game)
                    } label: {
                        RecentGameRow(
                            game: game,
                            isBest: game.id == fastestOverall?.id,
                            rank: index + 1,
                            formatDuration: formatDuration
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        if minutes > 0 {
            return "\(minutes):" + String(format: "%02d", seconds)
        }

        let ms = Int((duration - Double(totalSeconds)) * 10)
        return "\(seconds).\(ms)s"
    }
}

// MARK: - Personal Best Card

private struct PersonalBestCard: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: gradient.map { $0.opacity(0.3) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Overall Stat Card

private struct OverallStatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: Circle())

            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: - Recent Game Row

private struct RecentGameRow: View {
    let game: GameStats
    let isBest: Bool
    let rank: Int
    let formatDuration: (TimeInterval) -> String

    private let rowColors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.36),
        Color(red: 0.20, green: 0.60, blue: 0.94),
        Color(red: 0.23, green: 0.74, blue: 0.57),
        Color(red: 0.95, green: 0.67, blue: 0.20),
        Color(red: 0.87, green: 0.34, blue: 0.55),
        Color(red: 0.39, green: 0.42, blue: 0.90),
    ]

    private var accentColor: Color {
        rowColors[(rank - 1) % rowColors.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(game.theme)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if isBest {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(game.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(game.totalTime))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accentColor)

                Text("\(game.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: - Game Stats Detail View

struct GameStatsDetailView: View {
    let game: GameStats

    private let barColors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.36),
        Color(red: 0.20, green: 0.60, blue: 0.94),
        Color(red: 0.23, green: 0.74, blue: 0.57),
        Color(red: 0.95, green: 0.67, blue: 0.20),
        Color(red: 0.87, green: 0.34, blue: 0.55),
        Color(red: 0.39, green: 0.42, blue: 0.90),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                wordTimesChart
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(game.theme)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryHeader: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                SummaryStatBubble(
                    icon: "timer",
                    gradient: [.orange, Color(red: 1.0, green: 0.4, blue: 0.3)],
                    label: "Total",
                    value: formatDuration(game.totalTime)
                )

                SummaryStatBubble(
                    icon: "gauge.with.needle",
                    gradient: [Color(red: 0.23, green: 0.74, blue: 0.57), Color(red: 0.18, green: 0.58, blue: 0.82)],
                    label: "Avg/Word",
                    value: formatDuration(game.averageWordTime)
                )
            }

            HStack(spacing: 16) {
                if let fastest = game.fastestWord {
                    SummaryStatBubble(
                        icon: "hare.fill",
                        gradient: [.green, .mint],
                        label: fastest.word,
                        value: formatDuration(fastest.duration)
                    )
                }

                if let slowest = game.slowestWord {
                    SummaryStatBubble(
                        icon: "tortoise.fill",
                        gradient: [Color(red: 0.87, green: 0.34, blue: 0.55), .purple],
                        label: slowest.word,
                        value: formatDuration(slowest.duration)
                    )
                }
            }
        }
    }

    private var wordTimesChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Word Times", systemImage: "chart.bar.fill")
                .font(.title3.weight(.bold))

            let sorted = game.wordTimes.sorted(by: { $0.orderFound < $1.orderFound })
            let maxDuration = sorted.map(\.duration).max() ?? 1
            let fastest = game.fastestWord

            VStack(spacing: 8) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, wt in
                    let barColor = barColors[index % barColors.count]
                    let isFastest = wt.id == fastest?.id

                    HStack(spacing: 12) {
                        Text(wt.word)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isFastest ? barColor : .primary)
                            .frame(width: 80, alignment: .trailing)
                            .lineLimit(1)

                        GeometryReader { geo in
                            let fraction = maxDuration > 0 ? wt.duration / maxDuration : 0
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [barColor.opacity(0.7), barColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * fraction))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 24)

                        HStack(spacing: 4) {
                            if isFastest {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            Text(formatWordTime(wt.duration))
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes):" + String(format: "%02d", seconds)
        }

        let ms = Int((duration - Double(totalSeconds)) * 10)
        return "\(seconds).\(ms)s"
    }

    private func formatWordTime(_ duration: TimeInterval) -> String {
        formatDuration(duration)
    }
}

// MARK: - Summary Stat Bubble

private struct SummaryStatBubble: View {
    let icon: String
    let gradient: [Color]
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )

            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: gradient.map { $0.opacity(0.2) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}
