import SwiftUI

// MARK: - Constants

private enum ColorFloodConstants {
    static let gridSize = 8
    static let colorCount = 5
    static let maxMoves = 25
}

// MARK: - Color Definitions

enum ColorFloodColor: Int, CaseIterable {
    case red = 0
    case blue = 1
    case green = 2
    case yellow = 3
    case purple = 4

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.93, green: 0.27, blue: 0.27)
        case .blue:   return Color(red: 0.25, green: 0.54, blue: 0.92)
        case .green:  return Color(red: 0.22, green: 0.75, blue: 0.44)
        case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.17)
        case .purple: return Color(red: 0.65, green: 0.31, blue: 0.87)
        }
    }
}

// MARK: - Game Model

class ColorFloodGame: ObservableObject {
    @Published var grid: [[Int]] = []
    @Published var moves: Int = 0
    @Published var gameState: ColorFloodState = .playing

    var currentColor: Int {
        grid.isEmpty ? 0 : grid[0][0]
    }

    init() {
        startNewGame()
    }

    func startNewGame() {
        let size = ColorFloodConstants.gridSize
        var newGrid = [[Int]](repeating: [Int](repeating: 0, count: size), count: size)
        for row in 0..<size {
            for col in 0..<size {
                newGrid[row][col] = Int.random(in: 0..<ColorFloodConstants.colorCount)
            }
        }
        grid = newGrid
        moves = 0
        gameState = .playing
    }

    func applyColor(_ colorIndex: Int) {
        guard gameState == .playing else { return }
        guard colorIndex != currentColor else { return }

        let oldColor = currentColor
        floodFill(row: 0, col: 0, oldColor: oldColor, newColor: colorIndex)
        moves += 1

        if isBoardSingleColor() {
            gameState = .won
        } else if moves >= ColorFloodConstants.maxMoves {
            gameState = .lost
        }
    }

    private func floodFill(row: Int, col: Int, oldColor: Int, newColor: Int) {
        let size = ColorFloodConstants.gridSize
        var visited = [[Bool]](repeating: [Bool](repeating: false, count: size), count: size)
        var queue: [(Int, Int)] = [(0, 0)]
        visited[0][0] = true

        while !queue.isEmpty {
            let (r, c) = queue.removeFirst()
            grid[r][c] = newColor

            let neighbors = [(r-1, c), (r+1, c), (r, c-1), (r, c+1)]
            for (nr, nc) in neighbors {
                guard nr >= 0, nr < size, nc >= 0, nc < size else { continue }
                guard !visited[nr][nc] else { continue }
                if grid[nr][nc] == oldColor {
                    visited[nr][nc] = true
                    queue.append((nr, nc))
                }
            }
        }
    }

    private func isBoardSingleColor() -> Bool {
        let size = ColorFloodConstants.gridSize
        let first = grid[0][0]
        for row in 0..<size {
            for col in 0..<size {
                if grid[row][col] != first { return false }
            }
        }
        return true
    }
}

// MARK: - Game State

enum ColorFloodState {
    case playing
    case won
    case lost
}

// MARK: - Main View

struct ColorFloodView: View {
    @StateObject private var game = ColorFloodGame()

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ColorFloodHeaderView(moves: game.moves, maxMoves: ColorFloodConstants.maxMoves)

                ColorFloodGridView(grid: game.grid)
                    .padding(.horizontal, 16)

                ColorFloodButtonsView(
                    currentColor: game.currentColor,
                    onColorTap: { colorIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            game.applyColor(colorIndex)
                        }
                    }
                )
                .padding(.horizontal, 24)

                Button(action: { game.startNewGame() }) {
                    Text("New Game")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 12)
                }
            }
            .padding(.top, 20)

            if game.gameState != .playing {
                ColorFloodOverlayView(
                    state: game.gameState,
                    moves: game.moves,
                    onRestart: { game.startNewGame() }
                )
            }
        }
    }
}

// MARK: - Header View

struct ColorFloodHeaderView: View {
    let moves: Int
    let maxMoves: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("Color Flood")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Text("Moves: \(moves) / \(maxMoves)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                ColorFloodProgressBar(moves: moves, maxMoves: maxMoves)
                    .frame(width: 100, height: 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .neumorphicCard(radius: 16)
        .padding(.horizontal, 24)
    }
}

// MARK: - Progress Bar

struct ColorFloodProgressBar: View {
    let moves: Int
    let maxMoves: Int

    private var fraction: CGFloat {
        CGFloat(moves) / CGFloat(maxMoves)
    }

    private var barColor: Color {
        if fraction < 0.5 { return .green }
        if fraction < 0.8 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * min(fraction, 1.0))
            }
        }
    }
}

// MARK: - Grid View

struct ColorFloodGridView: View {
    let grid: [[Int]]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / CGFloat(ColorFloodConstants.gridSize)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .shadow(color: Color(.systemGray4), radius: 6, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.8), radius: 6, x: -4, y: -4)

                VStack(spacing: 2) {
                    ForEach(0..<ColorFloodConstants.gridSize, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<ColorFloodConstants.gridSize, id: \.self) { col in
                                let colorIndex = grid[row][col]
                                let floodColor = ColorFloodColor(rawValue: colorIndex)?.color ?? .gray
                                Rectangle()
                                    .fill(floodColor)
                                    .frame(width: cellSize - 2, height: cellSize - 2)
                                    .cornerRadius(col == 0 && row == 0 ? 8 : 2)
                                    .overlay(
                                        col == 0 && row == 0 ?
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                        : nil
                                    )
                            }
                        }
                    }
                }
                .padding(4)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Color Buttons View

struct ColorFloodButtonsView: View {
    let currentColor: Int
    let onColorTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<ColorFloodConstants.colorCount, id: \.self) { index in
                ColorFloodColorButton(
                    colorIndex: index,
                    isSelected: index == currentColor,
                    onTap: { onColorTap(index) }
                )
            }
        }
    }
}

// MARK: - Individual Color Button

struct ColorFloodColorButton: View {
    let colorIndex: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    private var buttonColor: Color {
        ColorFloodColor(rawValue: colorIndex)?.color ?? .gray
    }

    var body: some View {
        Circle()
            .fill(buttonColor)
            .frame(width: isSelected ? 56 : 48, height: isSelected ? 56 : 48)
            .shadow(color: buttonColor.opacity(0.6), radius: isSelected ? 8 : 4, x: 0, y: 4)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
                onTap()
            }
    }
}

// MARK: - Overlay View

struct ColorFloodOverlayView: View {
    let state: ColorFloodState
    let moves: Int
    let onRestart: () -> Void

    private var isWin: Bool { state == .won }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isWin ? "You Win!" : "Game Over")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(isWin ? .green : .red)

                Text(isWin
                     ? "Flooded the board in \(moves) move\(moves == 1 ? "" : "s")!"
                     : "You used all \(ColorFloodConstants.maxMoves) moves.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(isWin ? Color.green : Color.blue)
                        .cornerRadius(16)
                        .shadow(color: (isWin ? Color.green : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(36)
            .background(Color(.systemGray6))
            .cornerRadius(24)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}
