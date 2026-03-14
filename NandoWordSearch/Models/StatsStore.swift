import Foundation

final class StatsStore {
    private static let statsKey = "game_stats_history"
    private static let maxStoredGames = 100

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var allGames: [GameStats] {
        guard let data = defaults.data(forKey: Self.statsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([GameStats].self, from: data)) ?? []
    }

    func save(_ stats: GameStats) {
        var history = allGames
        history.append(stats)
        if history.count > Self.maxStoredGames {
            history = Array(history.suffix(Self.maxStoredGames))
        }

        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Self.statsKey)
        }
    }

    func games(for theme: String) -> [GameStats] {
        let normalized = theme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allGames.filter { $0.theme.lowercased() == normalized }
    }

    var personalBests: PersonalBests {
        let games = allGames
        guard !games.isEmpty else {
            return PersonalBests()
        }

        let fastestGame = games.min(by: { $0.totalTime < $1.totalTime })
        let fastestWord = games.flatMap(\.wordTimes).min(by: { $0.duration < $1.duration })
        let bestAverage = games.min(by: { $0.averageWordTime < $1.averageWordTime })

        return PersonalBests(
            fastestGame: fastestGame,
            fastestWord: fastestWord,
            bestAverageWordTime: bestAverage
        )
    }

    func isPersonalBestTime(_ totalTime: TimeInterval) -> Bool {
        let games = allGames
        guard games.count > 1 else { return games.count == 1 }
        let previousBest = games.dropLast().min(by: { $0.totalTime < $1.totalTime })?.totalTime ?? .infinity
        return totalTime < previousBest
    }

    func clearAll() {
        defaults.removeObject(forKey: Self.statsKey)
    }
}

struct PersonalBests: Equatable {
    let fastestGame: GameStats?
    let fastestWord: WordTime?
    let bestAverageWordTime: GameStats?

    init(
        fastestGame: GameStats? = nil,
        fastestWord: WordTime? = nil,
        bestAverageWordTime: GameStats? = nil
    ) {
        self.fastestGame = fastestGame
        self.fastestWord = fastestWord
        self.bestAverageWordTime = bestAverageWordTime
    }
}
