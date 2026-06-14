import SwiftUI

// MARK: - Models

struct LightsOutGrid {
    static let size = 5
    var cells: [[Bool]]

    init() {
        cells = Array(repeating: Array(repeating: false, count: LightsOutGrid.size), count: LightsOutGrid.size)
    }

    var isAllOff: Bool {
        cells.allSatisfy { row in row.allSatisfy { !$0 } }
    }

    mutating func toggle(row: Int, col: Int) {
        let n = LightsOutGrid.size
        let neighbors: [(Int, Int)] = [
            (row, col),
            (row - 1, col),
            (row + 1, col),
            (row, col - 1),
            (row, col + 1)
        ]
        for (r, c) in neighbors {
            if r >= 0 && r < n && c >= 0 && c < n {
                cells[r][c].toggle()
            }
        }
    }
}

// MARK: - Game State

class LightsOutGameState: ObservableObject {
    @Published var grid: LightsOutGrid = LightsOutGrid()
    @Published var moves: Int = 0
    @Published var isWon: Bool = false

    init() {
        newPuzzle()
    }

    func newPuzzle() {
        var g = LightsOutGrid()
        // Generate a solvable puzzle by starting from all-off and applying random toggles
        let n = LightsOutGrid.size
        var attempts = 0
        repeat {
            g = LightsOutGrid()
            let numToggles = Int.random(in: 5...15)
            for _ in 0..<numToggles {
                let r = Int.random(in: 0..<n)
                let c = Int.random(in: 0..<n)
                g.toggle(row: r, col: c)
            }
            attempts += 1
        } while g.isAllOff && attempts < 100

        grid = g
        moves = 0
        isWon = false
    }

    func tap(row: Int, col: Int) {
        guard !isWon else { return }
        grid.toggle(row: row, col: col)
        moves += 1
        if grid.isAllOff {
            isWon = true
        }
    }

    func restart() {
        newPuzzle()
    }
}

// MARK: - Cell View

struct LightsOutCellView: View {
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isOn ? Color.yellow : Color(UIColor.systemGray5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn ? Color.orange : Color(UIColor.systemGray3), lineWidth: 2)
                )
                .shadow(
                    color: isOn ? Color.yellow.opacity(0.7) : Color.clear,
                    radius: isOn ? 8 : 0
                )
                .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Grid View

struct LightsOutGridView: View {
    @ObservedObject var state: LightsOutGameState

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let n = CGFloat(LightsOutGrid.size)
            let totalSpacing = spacing * (n - 1)
            let cellSize = (min(geo.size.width, geo.size.height) - totalSpacing) / n

            VStack(spacing: spacing) {
                ForEach(0..<LightsOutGrid.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<LightsOutGrid.size, id: \.self) { col in
                            LightsOutCellView(
                                isOn: state.grid.cells[row][col],
                                onTap: { state.tap(row: row, col: col) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Win Overlay

struct LightsOutWinOverlay: View {
    let moves: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("All Lights Off!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)

                Text("Solved in \(moves) move\(moves == 1 ? "" : "s")")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                Button(action: onRestart) {
                    Text("New Puzzle")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                        .shadow(color: Color.yellow.opacity(0.5), radius: 8)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemGray6).opacity(0.95))
                    .shadow(color: .black.opacity(0.4), radius: 20)
            )
            .padding(32)
        }
    }
}

// MARK: - Main View

struct LightsOutView: View {
    @StateObject private var state = LightsOutGameState()

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lights Out")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Turn all lights off")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(state.moves)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(state.moves == 0 ? .secondary : .primary)
                            .animation(.none, value: state.moves)
                        Text("moves")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Grid
                LightsOutGridView(state: state)
                    .padding(.horizontal, 24)
                    .aspectRatio(1, contentMode: .fit)

                Spacer()

                // Restart button
                Button(action: { state.restart() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("New Puzzle")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 4)
                }
                .padding(.bottom, 36)
            }

            // Win overlay
            if state.isWon {
                LightsOutWinOverlay(moves: state.moves, onRestart: { state.restart() })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isWon)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LightsOutView()
}
