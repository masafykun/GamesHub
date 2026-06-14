import SwiftUI

// MARK: - Models

enum MinesweeperV3CellState {
    case hidden
    case revealed
    case flagged
}

struct MinesweeperV3Cell {
    var isMine: Bool = false
    var state: MinesweeperV3CellState = .hidden
    var adjacentMines: Int = 0
}

enum MinesweeperV3GameState {
    case idle
    case playing
    case won
    case lost
}

// MARK: - LCG Generator

struct MinesweeperV3LCG {
    private var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = UInt64(range.count)
        guard n > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % n)
    }
}

// MARK: - ViewModel

class MinesweeperV3Game: ObservableObject {
    static let rows = 8
    static let cols = 8
    static let totalMines = 10

    @Published var cells: [[MinesweeperV3Cell]]
    @Published var gameState: MinesweeperV3GameState = .idle
    @Published var flagCount: Int = 0
    @Published var elapsedTime: Int = 0

    private var timerRef: Foundation.Timer?
    private var minesPlaced: Bool = false
    private var seed: Int = 1

    init(seed: Int = 1) {
        self.seed = seed
        cells = Array(
            repeating: Array(repeating: MinesweeperV3Cell(), count: MinesweeperV3Game.cols),
            count: MinesweeperV3Game.rows
        )
    }

    func reset(seed: Int) {
        self.seed = seed
        cells = Array(
            repeating: Array(repeating: MinesweeperV3Cell(), count: MinesweeperV3Game.cols),
            count: MinesweeperV3Game.rows
        )
        gameState = .idle
        flagCount = 0
        elapsedTime = 0
        minesPlaced = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timerRef = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }

    private func stopTimer() {
        timerRef?.invalidate()
        timerRef = nil
    }

    private func placeMines(avoiding firstRow: Int, firstCol: Int) {
        var lcg = MinesweeperV3LCG(seed: seed)
        var placed = 0
        var attempts = 0
        while placed < MinesweeperV3Game.totalMines && attempts < 10000 {
            attempts += 1
            let r = lcg.nextInt(in: 0..<MinesweeperV3Game.rows)
            let c = lcg.nextInt(in: 0..<MinesweeperV3Game.cols)
            if cells[r][c].isMine { continue }
            let dr = abs(r - firstRow)
            let dc = abs(c - firstCol)
            if dr <= 1 && dc <= 1 { continue }
            cells[r][c].isMine = true
            placed += 1
        }
        // If LCG couldn't place enough mines avoiding first tap (edge case), fill remaining randomly
        if placed < MinesweeperV3Game.totalMines {
            for r in 0..<MinesweeperV3Game.rows {
                for c in 0..<MinesweeperV3Game.cols where placed < MinesweeperV3Game.totalMines {
                    if !cells[r][c].isMine && !(abs(r - firstRow) <= 1 && abs(c - firstCol) <= 1) {
                        cells[r][c].isMine = true
                        placed += 1
                    }
                }
            }
        }
        for r in 0..<MinesweeperV3Game.rows {
            for c in 0..<MinesweeperV3Game.cols {
                if !cells[r][c].isMine {
                    cells[r][c].adjacentMines = countAdjacentMines(row: r, col: c)
                }
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
                if nr >= 0 && nr < MinesweeperV3Game.rows && nc >= 0 && nc < MinesweeperV3Game.cols {
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
        guard row >= 0 && row < MinesweeperV3Game.rows else { return }
        guard col >= 0 && col < MinesweeperV3Game.cols else { return }
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
        for r in 0..<MinesweeperV3Game.rows {
            for c in 0..<MinesweeperV3Game.cols {
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
        for r in 0..<MinesweeperV3Game.rows {
            for c in 0..<MinesweeperV3Game.cols {
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
        MinesweeperV3Game.totalMines - flagCount
    }
}

// MARK: - Cell View

struct MinesweeperV3CellView: View {
    let cell: MinesweeperV3Cell
    let isLost: Bool

    private func numberColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.1, green: 0.1, blue: 0.9)
        case 2: return Color(red: 0.0, green: 0.55, blue: 0.1)
        case 3: return Color(red: 0.9, green: 0.1, blue: 0.1)
        case 4: return Color(red: 0.0, green: 0.0, blue: 0.55)
        case 5: return Color(red: 0.6, green: 0.0, blue: 0.0)
        case 6: return Color(red: 0.0, green: 0.5, blue: 0.5)
        case 7: return Color(red: 0.3, green: 0.0, blue: 0.3)
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            switch cell.state {
            case .revealed:
                if cell.isMine {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.75))
                        .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
                    Text("💣")
                        .font(.system(size: 15))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .shadow(color: Color(.systemGray3).opacity(0.6), radius: 2, x: 1, y: 1)
                    if cell.adjacentMines > 0 {
                        Text("\(cell.adjacentMines)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(numberColor(cell.adjacentMines))
                    }
                }
            case .flagged:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                    .shadow(color: Color(.systemGray4), radius: 4, x: 2, y: 2)
                Text("🚩")
                    .font(.system(size: 15))
            case .hidden:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                    .shadow(color: Color(.systemGray4), radius: 4, x: 2, y: 2)
                if isLost && cell.isMine {
                    Text("💣")
                        .font(.system(size: 15))
                        .opacity(0.35)
                }
            }
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - HUD Badge

struct MinesweeperV3Badge: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .neumorphicCard(radius: 12)
    }
}

// MARK: - Main View

struct MinesweeperViewV3: View {
    @StateObject private var game = MinesweeperV3Game(seed: 1)
    @State var seedInt: Int = 1

    // Long-press tracking via DragGesture
    @State private var pressStartTime: [String: Date] = [:]
    @State private var longPressFired: Set<String> = []

    private func cellKey(_ row: Int, _ col: Int) -> String { "\(row)-\(col)" }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var statusEmoji: String {
        switch game.gameState {
        case .idle: return "🙂"
        case .playing: return "😊"
        case .won: return "😎"
        case .lost: return "😵"
        }
    }

    private func handleRestart() {
        seedInt += 1
        game.reset(seed: seedInt)
        pressStartTime.removeAll()
        longPressFired.removeAll()
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {

                // SEED label
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)

                // HUD row
                HStack(spacing: 12) {
                    MinesweeperV3Badge(
                        label: "Mines",
                        value: "\(game.minesRemaining)",
                        valueColor: game.minesRemaining < 0 ? .red : .primary
                    )

                    Spacer()

                    // Restart button
                    Button(action: handleRestart) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 52, height: 52)
                                .shadow(color: .white.opacity(0.85), radius: 6, x: -3, y: -3)
                                .shadow(color: Color(.systemGray4), radius: 6, x: 3, y: 3)
                            Text(statusEmoji)
                                .font(.system(size: 24))
                        }
                    }

                    Spacer()

                    MinesweeperV3Badge(
                        label: "Time",
                        value: formattedTime(game.elapsedTime)
                    )
                }
                .padding(.horizontal, 20)

                // Status banner
                if game.gameState == .won || game.gameState == .lost {
                    HStack(spacing: 8) {
                        Text(game.gameState == .won ? "You Win!" : "Game Over!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(game.gameState == .won ? .green : .red)
                        Button("New Game") {
                            handleRestart()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(game.gameState == .won ? Color.green : Color.red)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 14)
                    .transition(.scale.combined(with: .opacity))
                }

                // Grid
                VStack(spacing: 0) {
                    VStack(spacing: 3) {
                        ForEach(0..<MinesweeperV3Game.rows, id: \.self) { row in
                            HStack(spacing: 3) {
                                ForEach(0..<MinesweeperV3Game.cols, id: \.self) { col in
                                    let key = cellKey(row, col)
                                    MinesweeperV3CellView(
                                        cell: game.cells[row][col],
                                        isLost: game.gameState == .lost
                                    )
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in
                                                if pressStartTime[key] == nil {
                                                    pressStartTime[key] = Date()
                                                } else {
                                                    let elapsed = Date().timeIntervalSince(pressStartTime[key]!)
                                                    if elapsed >= 0.45 && !longPressFired.contains(key) {
                                                        longPressFired.insert(key)
                                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                                        impact.impactOccurred()
                                                        game.toggleFlag(row: row, col: col)
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                let elapsed = pressStartTime[key].map { Date().timeIntervalSince($0) } ?? 1.0
                                                let wasFlagged = longPressFired.contains(key)
                                                pressStartTime.removeValue(forKey: key)
                                                longPressFired.remove(key)
                                                if !wasFlagged && elapsed < 0.45 {
                                                    guard game.cells[row][col].state == .hidden else { return }
                                                    game.reveal(row: row, col: col)
                                                }
                                            }
                                    )
                                }
                            }
                        }
                    }
                    .padding(10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .shadow(color: .white.opacity(0.8), radius: 8, x: -4, y: -4)
                        .shadow(color: Color(.systemGray4), radius: 8, x: 4, y: 4)
                )
                .padding(.horizontal, 16)

                // Instructions
                Text("Tap to reveal  •  Hold to flag")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.25), value: game.gameState)
        }
    }
}

// MARK: - Preview

#Preview {
    MinesweeperViewV3()
}
