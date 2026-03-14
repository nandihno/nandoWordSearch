import SwiftUI

enum GameBackground: String, CaseIterable, Codable, Sendable {
    case ocean
    case sunset
    case forest
    case lavender
    case peach
    case aurora
    case berry
    case slate

    var gradientColors: [Color] {
        switch self {
        case .ocean:
            [Color(red: 0.12, green: 0.16, blue: 0.30),
             Color(red: 0.14, green: 0.30, blue: 0.52),
             Color(red: 0.18, green: 0.46, blue: 0.62)]
        case .sunset:
            [Color(red: 0.32, green: 0.14, blue: 0.22),
             Color(red: 0.52, green: 0.22, blue: 0.26),
             Color(red: 0.72, green: 0.38, blue: 0.24)]
        case .forest:
            [Color(red: 0.10, green: 0.20, blue: 0.16),
             Color(red: 0.14, green: 0.32, blue: 0.24),
             Color(red: 0.22, green: 0.44, blue: 0.30)]
        case .lavender:
            [Color(red: 0.22, green: 0.16, blue: 0.34),
             Color(red: 0.34, green: 0.24, blue: 0.50),
             Color(red: 0.46, green: 0.34, blue: 0.60)]
        case .peach:
            [Color(red: 0.36, green: 0.18, blue: 0.16),
             Color(red: 0.52, green: 0.28, blue: 0.22),
             Color(red: 0.66, green: 0.42, blue: 0.32)]
        case .aurora:
            [Color(red: 0.10, green: 0.16, blue: 0.28),
             Color(red: 0.14, green: 0.30, blue: 0.38),
             Color(red: 0.20, green: 0.48, blue: 0.44)]
        case .berry:
            [Color(red: 0.28, green: 0.12, blue: 0.28),
             Color(red: 0.42, green: 0.18, blue: 0.36),
             Color(red: 0.54, green: 0.26, blue: 0.42)]
        case .slate:
            [Color(red: 0.14, green: 0.16, blue: 0.20),
             Color(red: 0.20, green: 0.24, blue: 0.30),
             Color(red: 0.28, green: 0.32, blue: 0.38)]
        }
    }

    var cellBackgroundColor: Color {
        Color.white.opacity(0.12)
    }

    var cellBorderColor: Color {
        Color.white.opacity(0.08)
    }

    var cardBackgroundColor: Color {
        Color.white.opacity(0.10)
    }

    static var random: GameBackground {
        allCases.randomElement() ?? .ocean
    }
}
