import Foundation

struct FoundWord: Identifiable, Equatable, Sendable {
    let id: UUID
    let value: String
    let cells: [GridPosition]
    let highlightStyle: WordHighlightStyle
}
