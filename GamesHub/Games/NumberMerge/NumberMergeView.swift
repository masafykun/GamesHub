import SwiftUI

// MARK: - Models
enum NMrgGamePhase { case start, playing, gameOver }

struct NMrgCell: Identifiable {
    let id = UUID()
    var value: Int
}

// MARK: - Game Logic
struct NMrgBoard {
    var cells: [[Int]] = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    var score: Int = 0

    mutating func addRandom() {
        var empty: [(Int,Int)] = []
        for r in 0..<5 { for c in 0..<5 { if cells[r][c] == 0 { empty.append((r,c)) } } }
        guard !empty.isEmpty else { return }
        let pick = empty[Int.random(in: 0..<empty.count)]
        cells[pick.0][pick.1] = Int.random(in: 0...3) == 0 ? 4 : 2
    }

    mutating func slideLeft() -> Bool {
        var moved = false
        for r in 0..<5 {
            var row = cells[r].filter { $0 != 0 }
            var merged: [Int] = []
            var i = 0
            while i < row.count {
                if i + 1 < row.count && row[i] == row[i+1] {
                    let v = row[i] * 2
                    merged.append(v)
                    score += v
                    i += 2
                } else {
                    merged.append(row[i])
                    i += 1
                }
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

    mutating func rotate270() { rotate90(); rotate90(); rotate90() }

    mutating func swipe(_ dir: NMrgDirection) -> Bool {
        switch dir {
        case .left: return slideLeft()
        case .right: rotate90(); rotate90(); let m = slideLeft(); rotate90(); rotate90(); return m
        case .up: rotate270(); let m = slideLeft(); rotate90(); return m
        case .down: rotate90(); let m = slideLeft(); rotate270(); return m
        }
    }

    var isFull: Bool {
        cells.flatMap { $0 }.allSatisfy { $0 != 0 }
    }

    var hasValidMoves: Bool {
        if !isFull { return true }
        for r in 0..<5 {
            for c in 0..<5 {
                let v = cells[r][c]
                if r+1 < 5 && cells[r+1][c] == v { return true }
                if c+1 < 5 && cells[r][c+1] == v { return true }
            }
        }
        return false
    }
}

enum NMrgDirection { case left, right, up, down }

// MARK: - Tile Color
func nmrgTileColor(_ value: Int) -> Color {
    switch value {
    case 2: return Color(red: 0.93, green: 0.89, blue: 0.85)
    case 4: return Color(red: 0.93, green: 0.87, blue: 0.78)
    case 8: return Color(red: 0.95, green: 0.69, blue: 0.47)
    case 16: return Color(red: 0.96, green: 0.58, blue: 0.39)
    case 32: return Color(red: 0.96, green: 0.49, blue: 0.37)
    case 64: return Color(red: 0.96, green: 0.37, blue: 0.23)
    case 128: return Color(red: 0.93, green: 0.81, blue: 0.45)
    case 256: return Color(red: 0.93, green: 0.80, blue: 0.38)
    case 512: return Color(red: 0.93, green: 0.78, blue: 0.31)
    default: return value > 512 ? Color(red: 0.93, green: 0.75, blue: 0.20) : Color(red: 0.80, green: 0.77, blue: 0.73)
    }
}

// MARK: - Main View
struct NumberMergeView: View {
    @State private var board = NMrgBoard()
    @State private var phase: NMrgGamePhase = .start
    @State private var reached512 = false
    @State private var dragStart: CGPoint = .zero

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Number Merge").font(.largeTitle).bold().foregroundColor(Color(red: 0.46, green: 0.43, blue: 0.40))
            Text("Swipe to slide tiles.\nMatch numbers to merge them.\nReach 512 to win!").multilineTextAlignment(.center).foregroundColor(.secondary)
            Button(action: startGame) {
                Text("Start Game").bold().padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color(red: 0.96, green: 0.58, blue: 0.39)).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Score").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(board.score)").font(.title2).bold().foregroundColor(Color(red: 0.46, green: 0.43, blue: 0.40))
            }.padding(.horizontal)
            gridView
                .gesture(DragGesture(minimumDistance: 20).onEnded { handleSwipe($0) })
            Text("Swipe to move tiles").font(.caption2).foregroundColor(.secondary)
        }.padding()
    }

    var gridView: some View {
        VStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { c in
                        let val = board.cells[r][c]
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(val == 0 ? Color(red: 0.81, green: 0.77, blue: 0.73) : nmrgTileColor(val))
                            if val != 0 {
                                Text("\(val)").font(val >= 1000 ? .caption : val >= 100 ? .callout : .title3)
                                    .bold().foregroundColor(val <= 4 ? Color(red: 0.46, green: 0.43, blue: 0.40) : .white)
                            }
                        }.frame(width: 60, height: 60)
                    }
                }
            }
        }.padding(8).background(Color(red: 0.72, green: 0.67, blue: 0.63)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text(reached512 ? "You Win!" : "Game Over").font(.largeTitle).bold()
                .foregroundColor(reached512 ? Color(red: 0.93, green: 0.78, blue: 0.31) : Color(red: 0.46, green: 0.43, blue: 0.40))
            Text("Score: \(board.score)").font(.title2).foregroundColor(.secondary)
            if reached512 { Text("You reached 512!").foregroundColor(.orange) }
            Button(action: startGame) {
                Text("Play Again").bold().padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color(red: 0.96, green: 0.58, blue: 0.39)).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }.padding()
    }

    func startGame() {
        board = NMrgBoard()
        board.addRandom()
        board.addRandom()
        reached512 = false
        phase = .playing
    }

    func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        let dir: NMrgDirection = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
        let moved = board.swipe(dir)
        if moved {
            board.addRandom()
            if board.cells.flatMap({ $0 }).contains(512) { reached512 = true }
            if !board.hasValidMoves { phase = .gameOver }
            if reached512 { phase = .gameOver }
        }
    }
}

#Preview { NumberMergeView() }
