import SwiftUI

extension WordHighlightStyle {
    var displayColor: Color {
        switch self {
        case .coral:
            Color(red: 0.93, green: 0.42, blue: 0.36)
        case .sky:
            Color(red: 0.20, green: 0.60, blue: 0.94)
        case .mint:
            Color(red: 0.23, green: 0.74, blue: 0.57)
        case .amber:
            Color(red: 0.95, green: 0.67, blue: 0.20)
        case .rose:
            Color(red: 0.87, green: 0.34, blue: 0.55)
        case .indigo:
            Color(red: 0.39, green: 0.42, blue: 0.90)
        }
    }
}
