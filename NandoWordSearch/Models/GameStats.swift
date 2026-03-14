import Foundation

struct GameStats: Codable, Identifiable, Equatable {
    let id: UUID
    let theme: String
    let totalTime: TimeInterval
    let wordCount: Int
    let wordTimes: [WordTime]
    let completedAt: Date

    init(
        id: UUID = UUID(),
        theme: String,
        totalTime: TimeInterval,
        wordCount: Int,
        wordTimes: [WordTime],
        completedAt: Date = Date()
    ) {
        self.id = id
        self.theme = theme
        self.totalTime = totalTime
        self.wordCount = wordCount
        self.wordTimes = wordTimes
        self.completedAt = completedAt
    }

    var fastestWord: WordTime? {
        wordTimes.min(by: { $0.duration < $1.duration })
    }

    var slowestWord: WordTime? {
        wordTimes.max(by: { $0.duration < $1.duration })
    }

    var averageWordTime: TimeInterval {
        guard !wordTimes.isEmpty else { return 0 }
        return wordTimes.reduce(0) { $0 + $1.duration } / Double(wordTimes.count)
    }
}

struct WordTime: Codable, Identifiable, Equatable {
    let id: UUID
    let word: String
    let duration: TimeInterval
    let orderFound: Int

    init(
        id: UUID = UUID(),
        word: String,
        duration: TimeInterval,
        orderFound: Int
    ) {
        self.id = id
        self.word = word
        self.duration = duration
        self.orderFound = orderFound
    }
}
