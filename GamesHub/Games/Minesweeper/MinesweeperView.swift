import SwiftUI

// MARK: - Models

enum MinesweeperCellState {
    case hidden
    case revealed
    case flagged
}

struct MinesweeperCell {
    var isMine: Bool = false
    var state: MinesweeperCellState = .hidden
    var adjacentMines: Int = 0
}

enum MinesweeperGameState {
    case idle
    case playing
    case won
    case lost
}

// MARK: - ViewModel

class MinesweeperGame: ObservableObject {
    static let rows = 8
    static let cols = 8
    static let totalMines = 10

    @Published var cells: [[MinesweeperCell]]
    @Published var gameState: MinesweeperGameState = .idle
    @Published var flagCount: Int = 0
    @Published var elapsedTime: Int = 0

    private var timer: Foundation.Timer?
    private var minesPlaced: Bool = false

    init() {
        cells = Array(
            repeating: Array(repeating: MinesweeperCell(), count: MinesweeperGame.cols),
            count: MinesweeperGame.rows
        )
    }

    func reset() {
        cells = Array(
            repeating: Array(repeating: MinesweeperCell(), count: MinesweeperGame.cols),
            count: MinesweeperGame.rows
        )
        gameState = .idle
        flagCount = 0
        elapsedTime = 0
        minesPlaced = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func placeMines(avoiding firstRow: Int, firstCol: Int) {
        var placed = 0
        while placed < MinesweeperGame.totalMines {
            let r = Int.random(in: 0..<MinesweeperGame.rows)
            let c = Int.random(in: 0..<MinesweeperGame.cols)
            if cells[r][c].isMine { continue }
            // Avoid first tap cell and its neighbors
            let dr = abs(r - firstRow)
            let dc = abs(c - firstCol)
            if dr <= 1 && dc <= 1 { continue }
            cells[r][c].isMine = true
            placed += 1
        }
        // Calculate adjacency counts
        for r in 0..<MinesweeperGame.rows {
            for c in 0..<MinesweeperGame.cols {
                if cells[r][c].isMine { continue }
                cells[r][c].adjacentMines = countAdjacentMines(row: r, col: c)
            }
        }
        minesPlaced = true
    }

    private func countAdjacentMines(row: Int, col: Int) -> Int {
        var count = 0
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0 && nr < MinesweeperGame.rows && nc >= 0 && nc < MinesweeperGame.cols {
                    if cells[nr][nc].isMine { count += 1 }
                }
            }
        }
        return count
    }

    func reveal(row: Int, col: Int) {
        guard gameState == .idle || gameState == .playing else { return }
        guard cells[row][col].state == .hidden else { return }

        if gameState == .idle {
            gameState = .playing
            placeMines(avoiding: row, firstCol: col)
            startTimer()
        }

        if cells[row][col].isMine {
            cells[row][col].state = .revealed
            gameState = .lost
            stopTimer()
            revealAllMines()
            return
        }

        floodReveal(row: row, col: col)
        checkWin()
    }

    private func floodReveal(row: Int, col: Int) {
        guard row >= 0 && row < MinesweeperGame.rows else { return }
        guard col >= 0 && col < MinesweeperGame.cols else { return }
        guard cells[row][col].state == .hidden else { return }
        guard !cells[row][col].isMine else { return }

        cells[row][col].state = .revealed

        if cells[row][col].adjacentMines == 0 {
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    floodReveal(row: row + dr, col: col + dc)
                }
            }
        }
    }

    private func revealAllMines() {
        for r in 0..<MinesweeperGame.rows {
            for c in 0..<MinesweeperGame.cols {
                if cells[r][c].isMine {
                    cells[r][c].state = .revealed
                }
            }
        }
    }

    func toggleFlag(row: Int, col: Int) {
        guard gameState == .playing || gameState == .idle else { return }
        let cell = cells[row][col]
        if cell.state == .hidden {
            cells[row][col].state = .flagged
            flagCount += 1
        } else if cell.state == .flagged {
            cells[row][col].state = .hidden
            flagCount -= 1
        }
    }

    private func checkWin() {
        for r in 0..<MinesweeperGame.rows {
            for c in 0..<MinesweeperGame.cols {
                let cell = cells[r][c]
                if !cell.isMine && cell.state != .revealed {
                    return
                }
            }
        }
        gameState = .won
        stopTimer()
    }

    var minesRemaining: Int {
        MinesweeperGame.totalMines - flagCount
    }
}

// MARK: - Cell View

struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let isGameOver: Bool

    private func numberColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.0, green: 0.0, blue: 0.9)
        case 2: return Color(red: 0.0, green: 0.55, blue: 0.0)
        case 3: return Color(red: 0.9, green: 0.0, blue: 0.0)
        case 4: return Color(red: 0.0, green: 0.0, blue: 0.55)
        case 5: return Color(red: 0.55, green: 0.0, blue: 0.0)
        case 6: return Color(red: 0.0, green: 0.55, blue: 0.55)
        case 7: return Color(red: 0.3, green: 0.0, blue: 0.3)
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            if cell.state == .revealed {
                if cell.isMine {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.8))
                    Text("💣")
                        .font(.system(size: 16))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.systemGray5))
                    if cell.adjacentMines > 0 {
                        Text("\(cell.adjacentMines)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(numberColor(cell.adjacentMines))
                    }
                }
            } else if cell.state == .flagged {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray3))
                    .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                Text("🚩")
                    .font(.system(size: 16))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray3))
                    .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                if isGameOver && cell.isMine {
                    Text("💣")
                        .font(.system(size: 16))
                        .opacity(0.4)
                }
            }
        }
        .frame(width: 38, height: 38)
    }
}

// MARK: - Main View

struct MinesweeperView: View {
    @StateObject private var game = MinesweeperGame()
    @State private var longPressLocation: (Int, Int)? = nil

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                // Mine counter
                HStack(spacing: 4) {
                    Text("💣")
                        .font(.title2)
                    Text("\(game.minesRemaining)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(game.minesRemaining < 0 ? .red : .primary)
                }
                .frame(minWidth: 70, alignment: .leading)

                Spacer()

                // Reset button
                Button(action: { game.reset() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemGray4))
                            .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                        Text(statusEmoji)
                            .font(.title2)
                    }
                    .frame(width: 48, height: 40)
                }

                Spacer()

                // Timer
                HStack(spacing: 4) {
                    Text(formattedTime(game.elapsedTime))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                    Text("⏱")
                        .font(.title2)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }
            .padding(.horizontal, 16)

            // Game status banner
            if game.gameState == .won || game.gameState == .lost {
                Text(game.gameState == .won ? "You Win!" : "Game Over!")
                    .font(.title2.bold())
                    .foregroundColor(game.gameState == .won ? .green : .red)
                    .transition(.scale)
            }

            // Grid
            VStack(spacing: 3) {
                ForEach(0..<MinesweeperGame.rows, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<MinesweeperGame.cols, id: \.self) { col in
                            MinesweeperCellView(
                                cell: game.cells[row][col],
                                isGameOver: game.gameState == .lost
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                LongPressGesture(minimumDuration: 0.4)
                                    .onEnded { _ in
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                        game.toggleFlag(row: row, col: col)
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        guard game.cells[row][col].state == .hidden else { return }
                                        game.reveal(row: row, col: col)
                                    }
                            )
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal, 8)

            // Instructions
            VStack(spacing: 4) {
                Text("Tap to reveal  •  Long press to flag")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
    }

    private var statusEmoji: String {
        switch game.gameState {
        case .idle: return "🙂"
        case .playing: return "😊"
        case .won: return "😎"
        case .lost: return "😵"
        }
    }
}

// MARK: - Preview

#Preview {
    MinesweeperView()
}
