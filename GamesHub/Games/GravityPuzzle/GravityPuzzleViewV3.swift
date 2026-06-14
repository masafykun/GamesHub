import SwiftUI

// MARK: - LCG Seeded Random

struct GrPzLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models V3

enum GrPzV3Direction: CaseIterable {
    case up, down, left, right
    var arrow: String {
        switch self { case .up: return "↑"; case .down: return "↓"; case .left: return "←"; case .right: return "→" }
    }
    var dx: Int {
        switch self { case .left: return -1; case .right: return 1; default: return 0 }
    }
    var dy: Int {
        switch self { case .up: return -1; case .down: return 1; default: return 0 }
    }
}

struct GrPzV3Level {
    let ballStart: (Int, Int)
    let starExit: (Int, Int)
    let walls: [(Int, Int)]
}

enum GrPzV3Phase { case start, playing, complete }

// MARK: - View V3

struct GravityPuzzleViewV3: View {
    @State private var phase: GrPzV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var currentLevel: Int = 0
    @State private var ballPos: (Int, Int) = (0, 0)
    @State private var moves: Int = 0
    @State private var gravity: GrPzV3Direction = .down
    @State private var totalMoves: Int = 0
    @State private var generatedLevels: [GrPzV3Level] = []

    let gridSize = 8
    let levelCount = 5

    var currentLevelData: GrPzV3Level? {
        guard currentLevel < generatedLevels.count else { return nil }
        return generatedLevels[currentLevel]
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("GRAVITY\nPUZZLE").font(.system(size: 44, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.label))
            Text("Slide the ball to the star!\nTap arrows to change gravity.")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Button("START") { beginGame() }
                .font(.headline).foregroundColor(Color(.label))
                .padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 22)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(currentLevel + 1)/\(levelCount)")
                        .font(.headline).foregroundColor(Color(.label))
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("Moves: \(moves)").font(.headline)
                    .foregroundColor(Color(.label))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .neumorphicCard(radius: 12)
            .padding(.horizontal)

            // Grid
            if let lvl = currentLevelData {
                VStack(spacing: 2) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                cellView(col: col, row: row, level: lvl)
                            }
                        }
                    }
                }
                .padding(8)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)
            }

            // Arrow controls
            VStack(spacing: 6) {
                arrowButton(.up)
                HStack(spacing: 20) {
                    arrowButton(.left)
                    Text(gravity.arrow)
                        .font(.system(size: 26))
                        .foregroundColor(Color(.label))
                        .frame(width: 44, height: 44)
                        .neumorphicCard(radius: 10)
                    arrowButton(.right)
                }
                arrowButton(.down)
            }
        }
        .padding(.vertical)
    }

    func cellView(col: Int, row: Int, level: GrPzV3Level) -> some View {
        let isWall = level.walls.contains(where: { $0.0 == col && $0.1 == row })
        let isBall = ballPos.0 == col && ballPos.1 == row
        let isStar = level.starExit.0 == col && level.starExit.1 == row
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isWall ? Color(.systemGray3) : Color(.systemGray6))
                .frame(width: 36, height: 36)
                .shadow(color: isWall ? .black.opacity(0.15) : .clear, radius: 2, x: 1, y: 1)
            if isBall {
                Circle()
                    .fill(Color.blue.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .shadow(color: .blue.opacity(0.4), radius: 4, x: 2, y: 2)
            }
            if isStar { Text("⭐").font(.system(size: 17)) }
        }
    }

    func arrowButton(_ dir: GrPzV3Direction) -> some View {
        Button(dir.arrow) { applyGravity(dir) }
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(gravity == dir ? .blue : Color(.label))
            .frame(width: 50, height: 50)
            .neumorphicCard(radius: 12)
    }

    var completeScreen: some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 60))
            Text("COMPLETE!").font(.system(size: 36, weight: .black))
                .foregroundColor(Color(.label))
            Text("Total Moves: \(totalMoves)").font(.title2)
                .foregroundColor(.blue)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Button("PLAY AGAIN") {
                seedInt += 1; phase = .start; currentLevel = 0; totalMoves = 0
            }
            .font(.headline).foregroundColor(Color(.label))
            .padding(.horizontal, 36).padding(.vertical, 14)
            .neumorphicCard(radius: 22)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: - Level Generation

    func generateLevels(seed: Int) -> [GrPzV3Level] {
        var rng = GrPzLCG(seed: seed)
        var result: [GrPzV3Level] = []
        for _ in 0..<levelCount {
            let ballCol = rng.nextInt(gridSize)
            let ballRow = rng.nextInt(gridSize)
            var starCol = rng.nextInt(gridSize)
            var starRow = rng.nextInt(gridSize)
            // Ensure star is not same as ball
            if starCol == ballCol && starRow == ballRow {
                starCol = (starCol + 4) % gridSize
            }
            // Generate walls (4–8 walls), none overlapping ball or star
            let wallCount = 4 + rng.nextInt(5)
            var walls: [(Int, Int)] = []
            for _ in 0..<wallCount {
                let wc = rng.nextInt(gridSize)
                let wr = rng.nextInt(gridSize)
                let notBall = !(wc == ballCol && wr == ballRow)
                let notStar = !(wc == starCol && wr == starRow)
                let notDupe = !walls.contains(where: { $0.0 == wc && $0.1 == wr })
                if notBall && notStar && notDupe { walls.append((wc, wr)) }
            }
            result.append(GrPzV3Level(
                ballStart: (ballCol, ballRow),
                starExit: (starCol, starRow),
                walls: walls
            ))
        }
        return result
    }

    // MARK: - Game Logic

    func beginGame() {
        generatedLevels = generateLevels(seed: seedInt)
        currentLevel = 0; moves = 0
        if let lvl = currentLevelData {
            ballPos = lvl.ballStart
        }
        gravity = .down; phase = .playing
    }

    func applyGravity(_ dir: GrPzV3Direction) {
        guard let lvl = currentLevelData else { return }
        gravity = dir
        var pos = ballPos
        while true {
            let next = (pos.0 + dir.dx, pos.1 + dir.dy)
            guard next.0 >= 0, next.0 < gridSize, next.1 >= 0, next.1 < gridSize else { break }
            if lvl.walls.contains(where: { $0.0 == next.0 && $0.1 == next.1 }) { break }
            pos = next
            if pos.0 == lvl.starExit.0 && pos.1 == lvl.starExit.1 { break }
        }
        ballPos = pos; moves += 1
        if ballPos.0 == lvl.starExit.0 && ballPos.1 == lvl.starExit.1 {
            totalMoves += moves
            if currentLevel < levelCount - 1 {
                currentLevel += 1; moves = 0
                if let next = currentLevelData { ballPos = next.ballStart }
                gravity = .down
            } else { phase = .complete }
        }
    }
}

#Preview { GravityPuzzleViewV3() }
