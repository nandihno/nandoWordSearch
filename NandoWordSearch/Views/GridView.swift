import SwiftUI

struct GridView: View {
    private let cellSpacing: CGFloat = 3

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

    // MARK: - Drag handling

    private func handleDragChanged(_ location: CGPoint, layout: (cellSize: CGFloat, gridDimension: CGFloat)) {
        let step = layout.cellSize + cellSpacing

        guard let position = cellPosition(for: location, step: step) else {
            return
        }

        if lastDraggedPosition == nil {
            lastDraggedPosition = position
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.14)) {
                viewModel.beginSelection(at: position)
            }
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

    private func cellPosition(for location: CGPoint, step: CGFloat) -> GridPosition? {
        let gridSize = viewModel.gameState.grid.size
        let gridDimension = step * CGFloat(gridSize) - cellSpacing

        guard
            location.x >= -step * 0.3,
            location.y >= -step * 0.3,
            location.x <= gridDimension + step * 0.3,
            location.y <= gridDimension + step * 0.3
        else {
            return nil
        }

        let row = max(0, min(gridSize - 1, Int((location.y + step * 0.3) / step)))
        let column = max(0, min(gridSize - 1, Int((location.x + step * 0.3) / step)))

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
                backgroundColor: .white.opacity(0.85),
                foregroundColor: .black,
                borderColor: .white.opacity(0.3),
                borderWidth: 0,
                scale: 1.07
            )
        }

        return (
            backgroundColor: .white.opacity(0.12),
            foregroundColor: .white,
            borderColor: .white.opacity(0.25),
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
