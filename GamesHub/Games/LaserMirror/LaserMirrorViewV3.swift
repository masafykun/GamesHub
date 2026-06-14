import SwiftUI

// MARK: - LCG Seeded RNG

struct LMrLCG {
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

enum LMrV3CellType: Int {
    case empty = 0
    case mirrorForward = 1  // /
    case mirrorBackward = 2 // \
}

struct LMrV3Pos: Hashable { let row: Int; let col: Int }

struct LMrV3Puzzle {
    let starRow: Int
    let starCol: Int
    let lockedMirrors: [(row: Int, col: Int, type: LMrV3CellType)]
}

// MARK: - Laser Trace

func computeV3LaserPath(cells: [[LMrV3CellType]], puzzle: LMrV3Puzzle) -> Set<LMrV3Pos> {
    var visited = Set<LMrV3Pos>()
    var row = 3; var col = 0
    var dr = 0; var dc = 1
    var steps = 0
    while col >= 0 && col < 7 && row >= 0 && row < 7 && steps < 100 {
        let pos = LMrV3Pos(row: row, col: col)
        if visited.contains(pos) { break }
        visited.insert(pos); steps += 1
        let cell = cells[row][col]
        if cell == .mirrorForward { let t = -dc; dc = -dr; dr = t }
        else if cell == .mirrorBackward { let t = dc; dc = dr; dr = t }
        row += dr; col += dc
    }
    return visited
}

// MARK: - Puzzle Generator

func generateV3Puzzle(rng: inout LMrLCG) -> LMrV3Puzzle {
    // Pick a star position not in the laser row (row 3 start)
    var starRow: Int
    var starCol: Int
    repeat {
        starRow = rng.nextInt(7)
        starCol = 1 + rng.nextInt(6)
    } while starRow == 3 && starCol == 0

    // Place 2-3 locked mirrors randomly
    let mirrorCount = 2 + rng.nextInt(2)
    var locked: [(row: Int, col: Int, type: LMrV3CellType)] = []
    var usedPositions = Set<LMrV3Pos>([LMrV3Pos(row: starRow, col: starCol)])
    for _ in 0..<mirrorCount {
        var r: Int; var c: Int
        var attempts = 0
        repeat {
            r = rng.nextInt(7); c = rng.nextInt(7); attempts += 1
        } while (usedPositions.contains(LMrV3Pos(row: r, col: c)) || (r == 3 && c == 0)) && attempts < 20
        if attempts < 20 {
            usedPositions.insert(LMrV3Pos(row: r, col: c))
            let mtype: LMrV3CellType = rng.nextInt(2) == 0 ? .mirrorForward : .mirrorBackward
            locked.append((row: r, col: c, type: mtype))
        }
    }
    return LMrV3Puzzle(starRow: starRow, starCol: starCol, lockedMirrors: locked)
}

// MARK: - Main View

struct LaserMirrorViewV3: View {
    @State private var phase: LMrV3Phase = .start
    @State private var cells = Array(repeating: Array(repeating: LMrV3CellType.empty, count: 7), count: 7)
    @State private var puzzle: LMrV3Puzzle = LMrV3Puzzle(starRow: 2, starCol: 5, lockedMirrors: [])
    @State private var solved = false
    @State private var moveCount = 0
    @State private var seedInt: Int = 1
    @State private var totalSolved = 0

    enum LMrV3Phase { case start, game, solved }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .game: gameScreen
            case .solved: solvedScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 4) {
                Text("LASER").font(.system(size: 48, weight: .black)).foregroundColor(.primary)
                Text("MIRROR").font(.system(size: 48, weight: .black)).foregroundColor(.blue)
            }
            Text("Place mirrors to reflect\nthe laser onto the star!").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("PLAY") { newGame() }
                .font(.headline.bold()).foregroundColor(.white).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.blue).clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(.horizontal, 32)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEED: #\(seedInt)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                    Text("Solved: \(totalSolved)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("Moves: \(moveCount)").font(.headline.bold()).foregroundColor(.primary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .neumorphicCard(radius: 12)
            .padding(.horizontal)

            gridView
                .padding(16)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("NEW PUZZLE") { newGame() }
                    .font(.subheadline.bold()).foregroundColor(.blue).padding(.horizontal, 20).padding(.vertical, 10)
                    .neumorphicCard(radius: 10)
                Button("RESTART") { restartPuzzle() }
                    .font(.subheadline.bold()).foregroundColor(.secondary).padding(.horizontal, 20).padding(.vertical, 10)
                    .neumorphicCard(radius: 10)
            }
        }.padding(.vertical)
    }

    var solvedScreen: some View {
        VStack(spacing: 24) {
            Text("SOLVED!").font(.system(size: 44, weight: .black)).foregroundColor(.yellow)
            Text("Seed #\(seedInt) complete").font(.headline).foregroundColor(.secondary)
                .font(.system(size: 11, design: .monospaced))
            Text("Moves used: \(moveCount)").font(.title3).foregroundColor(.primary)
            Text("Total solved: \(totalSolved)").font(.subheadline).foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("NEXT PUZZLE") { newGame() }
                    .font(.headline.bold()).foregroundColor(.white).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.blue).clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.4), radius: 6, y: 3)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(.horizontal, 32)
    }

    // MARK: - Grid

    var gridView: some View {
        let laserPath = computeV3LaserPath(cells: cells, puzzle: puzzle)
        return VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 3) {
                    ZStack {
                        if row == 3 {
                            Image(systemName: "arrow.right").font(.caption2).foregroundColor(.red)
                        }
                    }.frame(width: 16)
                    ForEach(0..<7, id: \.self) { col in
                        cellView(row: row, col: col, laserPath: laserPath)
                    }
                }
            }
        }
    }

    func cellView(row: Int, col: Int, laserPath: Set<LMrV3Pos>) -> some View {
        let isLocked = puzzle.lockedMirrors.contains { $0.row == row && $0.col == col }
        let isStar = puzzle.starRow == row && puzzle.starCol == col
        let isLit = laserPath.contains(LMrV3Pos(row: row, col: col))
        let cell = cells[row][col]

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isLit ? Color.red.opacity(0.15) : Color(.systemGray6))
                .shadow(color: isLit ? .red.opacity(0.3) : .black.opacity(0.12), radius: isLit ? 4 : 2, x: isLit ? 0 : 2, y: isLit ? 0 : 2)
                .shadow(color: isLit ? .clear : .white.opacity(0.8), radius: 2, x: -2, y: -2)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isLit ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1))

            if isStar {
                Text("★").font(.system(size: 20)).foregroundColor(isLit ? .yellow : Color(.systemGray3))
            } else if cell == .mirrorForward {
                Text("/").font(.system(size: 20, weight: .bold)).foregroundColor(isLocked ? .blue : .primary)
            } else if cell == .mirrorBackward {
                Text("\\").font(.system(size: 20, weight: .bold)).foregroundColor(isLocked ? .blue : .primary)
            }
        }
        .frame(width: 42, height: 42)
        .onTapGesture { tapCell(row: row, col: col, isLocked: isLocked, isStar: isStar) }
    }

    // MARK: - Helpers

    func tapCell(row: Int, col: Int, isLocked: Bool, isStar: Bool) {
        guard !isLocked, !isStar, phase == .game else { return }
        let current = cells[row][col]
        cells[row][col] = current == .empty ? .mirrorForward : current == .mirrorForward ? .mirrorBackward : .empty
        moveCount += 1
        let path = computeV3LaserPath(cells: cells, puzzle: puzzle)
        if path.contains(LMrV3Pos(row: puzzle.starRow, col: puzzle.starCol)) {
            totalSolved += 1
            withAnimation { phase = .solved }
        }
    }

    func newGame() {
        seedInt += 1
        var rng = LMrLCG(seed: seedInt)
        puzzle = generateV3Puzzle(rng: &rng)
        cells = Array(repeating: Array(repeating: .empty, count: 7), count: 7)
        for m in puzzle.lockedMirrors { cells[m.row][m.col] = m.type }
        moveCount = 0
        solved = false
        phase = .game
    }

    func restartPuzzle() {
        cells = Array(repeating: Array(repeating: .empty, count: 7), count: 7)
        for m in puzzle.lockedMirrors { cells[m.row][m.col] = m.type }
        moveCount = 0
        solved = false
        phase = .game
    }
}

#Preview { LaserMirrorViewV3() }
