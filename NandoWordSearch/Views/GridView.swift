import SwiftUI

struct GridView: View {
    private let cellSpacing: CGFloat = 6

    @ObservedObject var viewModel: GameViewModel
    @State private var lastDraggedPosition: GridPosition?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let layout = makeLayout(for: proxy.size.width)
            let columns = Array(
                repeating: GridItem(.fixed(layout.cellSize), spacing: cellSpacing),
                count: viewModel.gameState.grid.size
            )

            LazyVGrid(columns: columns, spacing: cellSpacing) {
                ForEach(viewModel.gameState.grid.coordinates, id: \.self) { coordinate in
                    let visualState = visualState(for: coordinate)

                    Text(letter(at: coordinate))
                        .font(
                            .system(
                                size: max(16, layout.cellSize * 0.42),
                                weight: .bold,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(visualState.foregroundColor)
                        .frame(width: layout.cellSize, height: layout.cellSize)
                        .background(
                            RoundedRectangle(cornerRadius: layout.cellSize * 0.24, style: .continuous)
                                .fill(visualState.backgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cellSize * 0.24, style: .continuous)
                                .stroke(visualState.borderColor, lineWidth: visualState.borderWidth)
                        )
                        .scaleEffect(visualState.scale)
                        .contentShape(Rectangle())
                        .accessibilityElement()
                        .accessibilityLabel(accessibilityLabel(for: coordinate))
                        .animation(.snappy(duration: 0.18), value: viewModel.selectedCells)
                        .animation(.snappy(duration: 0.28), value: viewModel.foundWords)
                }
            }
            .frame(width: layout.gridDimension, height: layout.gridDimension, alignment: .topLeading)
            .contentShape(Rectangle())
            .coordinateSpace(name: "WordSearchGrid")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("WordSearchGrid"))
                    .onChanged { value in
                        handleDragChanged(value.location, layout: layout)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func makeLayout(for availableWidth: CGFloat) -> (cellSize: CGFloat, gridDimension: CGFloat) {
        let gridSize = viewModel.gameState.grid.size
        let totalSpacing = cellSpacing * CGFloat(max(0, gridSize - 1))
        let cellSize = floor((availableWidth - totalSpacing) / CGFloat(gridSize))
        let gridDimension = (cellSize * CGFloat(gridSize)) + totalSpacing
        return (cellSize, gridDimension)
    }

    private func handleDragChanged(_ location: CGPoint, layout: (cellSize: CGFloat, gridDimension: CGFloat)) {
        guard let position = position(for: location, layout: layout) else {
            return
        }

        guard position != lastDraggedPosition else {
            return
        }

        lastDraggedPosition = position
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.14)) {
            viewModel.updateSelection(at: position)
        }
    }

    private func handleDragEnded() {
        lastDraggedPosition = nil
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.2)) {
            viewModel.commitSelection()
        }
    }

    private func position(
        for location: CGPoint,
        layout: (cellSize: CGFloat, gridDimension: CGFloat)
    ) -> GridPosition? {
        guard
            location.x >= 0,
            location.y >= 0,
            location.x <= layout.gridDimension,
            location.y <= layout.gridDimension
        else {
            return nil
        }

        let step = layout.cellSize + cellSpacing
        let row = Int(location.y / step)
        let column = Int(location.x / step)
        let insetY = location.y - (CGFloat(row) * step)
        let insetX = location.x - (CGFloat(column) * step)

        guard
            row < viewModel.gameState.grid.size,
            column < viewModel.gameState.grid.size,
            insetY <= layout.cellSize,
            insetX <= layout.cellSize
        else {
            return nil
        }

        return GridPosition(row: row, column: column)
    }

    private func letter(at coordinate: GridPosition) -> String {
        String(viewModel.gameState.grid[coordinate]?.letter ?? " ")
    }

    private func visualState(for coordinate: GridPosition) -> (
        backgroundColor: Color,
        foregroundColor: Color,
        borderColor: Color,
        borderWidth: CGFloat,
        scale: CGFloat
    ) {
        if let foundWord = mostRecentFoundWord(containing: coordinate) {
            let color = foundWord.highlightStyle.displayColor
            return (
                backgroundColor: color,
                foregroundColor: .white,
                borderColor: color.opacity(0.2),
                borderWidth: 0,
                scale: 1
            )
        }

        if viewModel.selectedCells.contains(coordinate) {
            return (
                backgroundColor: .accentColor,
                foregroundColor: .white,
                borderColor: .accentColor.opacity(0.15),
                borderWidth: 0,
                scale: 1.07
            )
        }

        return (
            backgroundColor: Color(uiColor: .systemBackground),
            foregroundColor: .primary,
            borderColor: Color(uiColor: .separator).opacity(0.35),
            borderWidth: 1,
            scale: 1
        )
    }

    private func mostRecentFoundWord(containing coordinate: GridPosition) -> FoundWord? {
        viewModel.foundWords.last(where: { $0.cells.contains(coordinate) })
    }

    private func accessibilityLabel(for coordinate: GridPosition) -> String {
        let stateDescription: String
        if let foundWord = mostRecentFoundWord(containing: coordinate) {
            stateDescription = "found in \(foundWord.value.lowercased())"
        } else if viewModel.selectedCells.contains(coordinate) {
            stateDescription = "currently selected"
        } else {
            stateDescription = "not selected"
        }

        return "\(letter(at: coordinate)), row \(coordinate.row + 1), column \(coordinate.column + 1), \(stateDescription)"
    }
}
