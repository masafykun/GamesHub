import SwiftUI

// MARK: - LCG Seeded Random
struct NMrgLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models
enum NMrgV3GamePhase { case start, playing, gameOver }

struct NMrgV3Board {
    var cells: [[Int]] = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    var score: Int = 0

    mutating func addRandom(using lcg: inout NMrgLCG) {
        var empty: [(Int,Int)] = []
        for r in 0..<5 { for c in 0..<5 { if cells[r][c] == 0 { empty.append((r,c)) } } }
        guard !empty.isEmpty else { return }
        let idx = lcg.nextInt(empty.count)
        let pick = empty[idx]
        cells[pick.0][pick.1] = lcg.nextDouble() < 0.15 ? 4 : 2
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

    mutating func swipe(_ dir: NMrgV3Direction) -> Bool {
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

enum NMrgV3Direction { case left, right, up, down }

func nmrgV3TileColor(_ value: Int) -> Color {
    switch value {
    case 2: return Color(.systemGray5)
    case 4: return Color(.systemGray4)
    case 8: return Color(red: 0.98, green: 0.85, blue: 0.65)
    case 16: return Color(red: 0.98, green: 0.75, blue: 0.50)
    case 32: return Color(red: 0.98, green: 0.62, blue: 0.45)
    case 64: return Color(red: 0.98, green: 0.50, blue: 0.35)
    case 128: return Color(red: 0.94, green: 0.80, blue: 0.40)
    case 256: return Color(red: 0.94, green: 0.78, blue: 0.30)
    case 512: return Color(red: 0.94, green: 0.76, blue: 0.20)
    default: return value > 512 ? Color(red: 0.90, green: 0.72, blue: 0.10) : Color(.systemGray5)
    }
}

// MARK: - Main View
struct NumberMergeViewV3: View {
    @State private var board = NMrgV3Board()
    @State private var phase: NMrgV3GamePhase = .start
    @State private var reached512 = false
    @State private var seedInt: Int = 1
    @State private var lcg = NMrgLCG(seed: 1)

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Number Merge").font(.largeTitle).bold()
                .foregroundColor(Color(.label))
            Text("Swipe to merge tiles\nReach 512 to win!")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            seedLabel
            actionButton("Start Game", action: startGame)
        }.padding(28)
        .neumorphicCard(radius: 20)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2).foregroundColor(.secondary)
                    Text("\(board.score)").font(.title).bold()
                }
                Spacer()
                seedLabel
            }.padding(.horizontal)

            neuGrid
                .gesture(DragGesture(minimumDistance: 20).onEnded { handleSwipe($0) })

            Text("Swipe to move tiles").font(.caption2).foregroundColor(.secondary)
        }.padding()
    }

    var neuGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { c in
                        let val = board.cells[r][c]
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(val == 0 ? Color(.systemGray5) : nmrgV3TileColor(val))
                                .shadow(color: .white.opacity(0.8), radius: 2, x: -2, y: -2)
                                .shadow(color: Color(.systemGray3).opacity(0.6), radius: 2, x: 2, y: 2)
                            if val != 0 {
                                Text("\(val)").font(val >= 1000 ? .caption : val >= 100 ? .callout : .title3)
                                    .bold().foregroundColor(val <= 4 ? Color(.label) : Color(red: 0.25, green: 0.22, blue: 0.18))
                            }
                        }.frame(width: 58, height: 58)
                    }
                }
            }
        }.padding(10)
        .neumorphicCard(radius: 16)
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text(reached512 ? "You Win!" : "Game Over").font(.largeTitle).bold()
                .foregroundColor(reached512 ? Color(red: 0.85, green: 0.65, blue: 0.10) : Color(.label))
            Text("Score: \(board.score)").font(.title2).foregroundColor(.secondary)
            if reached512 { Text("You reached 512!").foregroundColor(.orange) }
            seedLabel
            actionButton("Play Again", action: startGame)
        }.padding(28)
        .neumorphicCard(radius: 20)
        .padding()
    }

    var seedLabel: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.secondary)
    }

    func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).bold().padding(.horizontal, 36).padding(.vertical, 13)
                .foregroundColor(Color(.label))
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .white.opacity(0.8), radius: 3, x: -3, y: -3)
                .shadow(color: Color(.systemGray3).opacity(0.7), radius: 3, x: 3, y: 3)
        }
    }

    func startGame() {
        seedInt += 1
        lcg = NMrgLCG(seed: seedInt)
        board = NMrgV3Board()
        board.addRandom(using: &lcg)
        board.addRandom(using: &lcg)
        reached512 = false
        phase = .playing
    }

    func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width, dy = value.translation.height
        let dir: NMrgV3Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
        let moved = board.swipe(dir)
        if moved {
            board.addRandom(using: &lcg)
            if board.cells.flatMap({ $0 }).contains(512) { reached512 = true }
            if !board.hasValidMoves || reached512 { phase = .gameOver }
        }
    }
}

#Preview { NumberMergeViewV3() }
