import SwiftUI

// MARK: - Models
enum NumberMergeGamePhase { case start, playing, gameOver }

struct NumberMergeBoard {
    var cells: [[Int]] = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    var score: Int = 0

    mutating func addRandom(extraFours: Bool = false) {
        var empty: [(Int,Int)] = []
        for r in 0..<5 { for c in 0..<5 { if cells[r][c] == 0 { empty.append((r,c)) } } }
        guard !empty.isEmpty else { return }
        let pick = empty[Int.random(in: 0..<empty.count)]
        let threshold = extraFours ? 1 : 3
        cells[pick.0][pick.1] = Int.random(in: 0...threshold) == 0 ? 4 : 2
    }

    mutating func slideLeft() -> Bool {
        var moved = false
        for r in 0..<5 {
            var row = cells[r].filter { $0 != 0 }
            var merged: [Int] = []
            var i = 0
            while i < row.count {
                if i + 1 < row.count && row[i] == row[i+1] {
                    let v = row[i] * 2; merged.append(v); score += v; i += 2
                } else { merged.append(row[i]); i += 1 }
            }
            while merged.count < 5 { merged.append(0) }
            if merged != cells[r] { moved = true }
            cells[r] = merged
        }
        return moved
    }

    mutating func rotate90() {
        var rotated = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        for r in 0..<5 { for c in 0..<5 { rotated[c][4-r] = cells[r][c] } }
        cells = rotated
    }

    mutating func swipe(_ dir: NumberMergeDirection) -> Bool {
        switch dir {
        case .left: return slideLeft()
        case .right: rotate90(); rotate90(); let m = slideLeft(); rotate90(); rotate90(); return m
        case .up: rotate90(); rotate90(); rotate90(); let m = slideLeft(); rotate90(); return m
        case .down: rotate90(); let m = slideLeft(); rotate90(); rotate90(); rotate90(); return m
        }
    }

    var hasValidMoves: Bool {
        for r in 0..<5 { for c in 0..<5 {
            if cells[r][c] == 0 { return true }
            let v = cells[r][c]
            if r+1 < 5 && cells[r+1][c] == v { return true }
            if c+1 < 5 && cells[r][c+1] == v { return true }
        }}
        return false
    }
}

enum NumberMergeDirection { case left, right, up, down }

func nmrgTileColor(_ value: Int) -> Color {
    switch value {
    case 2: return .white.opacity(0.5)
    case 4: return Color.yellow.opacity(0.3)
    case 8: return Color.orange.opacity(0.4)
    case 16: return Color.orange.opacity(0.6)
    case 32: return Color.red.opacity(0.4)
    case 64: return Color.red.opacity(0.6)
    case 128: return Color.purple.opacity(0.4)
    case 256: return Color.purple.opacity(0.6)
    case 512: return Color.blue.opacity(0.5)
    default: return value > 512 ? Color.cyan.opacity(0.5) : Color.white.opacity(0.2)
    }
}

// MARK: - Main View
struct NumberMergeView: View {
    @State private var board = NumberMergeBoard()
    @State private var phase: NumberMergeGamePhase = .start
    @State private var reached512 = false
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0

    var spawnExtraFours: Bool { difficulty > 1.3 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.20, green: 0.10, blue: 0.40), Color(red: 0.05, green: 0.30, blue: 0.50)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Number Merge").font(.largeTitle).bold().foregroundColor(.white)
            Text("Swipe to merge equal tiles\nReach 512 to win!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
            difficultyBadge
            startButton("Start Game", action: startGame)
        }.padding(24)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    var difficultyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer").foregroundColor(.yellow)
            Text("Difficulty: \(String(format: "%.1f", difficulty))x").foregroundColor(.white.opacity(0.9)).font(.caption)
        }.padding(.horizontal, 12).padding(.vertical, 6)
        .background(.ultraThinMaterial).clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2).foregroundColor(.white.opacity(0.6))
                    Text("\(board.score)").font(.title).bold().foregroundColor(.white)
                }
                Spacer()
                difficultyBadge
            }.padding(.horizontal)

            glassGrid
                .gesture(DragGesture(minimumDistance: 20).onEnded { handleSwipe($0) })

            Text("Swipe to move tiles").font(.caption2).foregroundColor(.white.opacity(0.5))
        }.padding()
    }

    var glassGrid: some View {
        VStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { c in
                        let val = board.cells[r][c]
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(val == 0 ? Color.white.opacity(0.05) : nmrgTileColor(val))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(val == 0 ? 0.1 : 0.4), lineWidth: 1))
                            if val != 0 {
                                Text("\(val)").font(val >= 1000 ? .caption : val >= 100 ? .callout : .title3)
                                    .bold().foregroundColor(.white)
                            }
                        }.frame(width: 58, height: 58)
                    }
                }
            }
        }.padding(8)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text(reached512 ? "You Win!" : "Game Over").font(.largeTitle).bold().foregroundColor(reached512 ? .yellow : .white)
            Text("Score: \(board.score)").font(.title2).foregroundColor(.white.opacity(0.8))
            if reached512 { Text("512 reached!").foregroundColor(.yellow) }
            Text("Wins in last \(recentResults.count) games: \(recentResults.filter { $0 }.count)").font(.caption).foregroundColor(.white.opacity(0.6))
            startButton("Play Again", action: startGame)
        }.padding(28)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    func startButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).bold().padding(.horizontal, 40).padding(.vertical, 14).foregroundColor(.white)
                .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1))
        }
    }

    func startGame() {
        board = NumberMergeBoard()
        board.addRandom(extraFours: spawnExtraFours)
        board.addRandom(extraFours: spawnExtraFours)
        reached512 = false
        phase = .playing
    }

    func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        let dir: NumberMergeDirection = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
        let moved = board.swipe(dir)
        if moved {
            board.addRandom(extraFours: spawnExtraFours)
            if board.cells.flatMap({ $0 }).contains(512) { reached512 = true }
            let isOver = !board.hasValidMoves || reached512
            if isOver {
                recentResults.append(reached512)
                if recentResults.count > 10 { recentResults.removeFirst() }
                let last5 = Array(recentResults.suffix(5))
                if last5.count == 5 && last5.filter({ $0 }).count > 4 {
                    difficulty = min(difficulty * 1.2, 3.0)
                }
                phase = .gameOver
            }
        }
    }
}

#Preview { NumberMergeView() }
