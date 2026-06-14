import SwiftUI

// MARK: - LCG Random

struct PthFLCG {
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

enum PthFV3CellType {
    case empty, wall, start, end
}

enum PthFV3GamePhase {
    case start, playing, result
}

struct PthFV3Level {
    let walls: Set<Int>
    let startCell: Int
    let endCell: Int

    static func generate(seed: Int) -> PthFV3Level {
        var rng = PthFLCG(seed: seed)
        let gridSize = 8

        // Pick start on left column, end on right column
        let startRow = rng.nextInt(gridSize)
        let endRow = rng.nextInt(gridSize)
        let startCell = startRow * gridSize
        let endCell = endRow * gridSize + (gridSize - 1)

        // Generate ~14 walls avoiding start/end
        var walls: Set<Int> = []
        let wallCount = 12 + rng.nextInt(6)
        var attempts = 0
        while walls.count < wallCount && attempts < 200 {
            attempts += 1
            let candidate = rng.nextInt(64)
            if candidate == startCell || candidate == endCell { continue }
            // Avoid blocking start/end adjacents entirely
            let row = candidate / gridSize
            let col = candidate % gridSize
            if col == 0 || col == gridSize - 1 { continue } // Keep edges clear
            walls.insert(candidate)
        }

        // Make sure a horizontal corridor exists at startRow and endRow
        for col in 1..<(gridSize - 1) {
            walls.remove(startRow * gridSize + col)
        }

        return PthFV3Level(walls: walls, startCell: startCell, endCell: endCell)
    }
}

// MARK: - V3 View

struct PathFinderViewV3: View {
    @State private var phase: PthFV3GamePhase = .start
    @State private var path: [Int] = []
    @State private var score: Int = 100
    @State private var seedInt: Int = 1
    @State private var generatedLevel: PthFV3Level = PthFV3Level.generate(seed: 1)

    private let gridSize = 8

    var level: PthFV3Level { generatedLevel }
    var pathLength: Int { max(0, path.count - 1) }
    var currentScore: Int { max(0, 100 - pathLength) }

    func cellType(index: Int) -> PthFV3CellType {
        if index == level.startCell { return .start }
        if index == level.endCell { return .end }
        if level.walls.contains(index) { return .wall }
        return .empty
    }

    func isAdjacent(_ a: Int, _ b: Int) -> Bool {
        let ar = a / gridSize, ac = a % gridSize
        let br = b / gridSize, bc = b % gridSize
        return (ar == br && abs(ac - bc) == 1) || (ac == bc && abs(ar - br) == 1)
    }

    func tapCell(_ index: Int) {
        guard phase == .playing else { return }
        if cellType(index: index) == .wall { return }

        if path.isEmpty {
            if index == level.startCell { path = [index] }
            return
        }
        if path.contains(index) {
            if let i = path.firstIndex(of: index) {
                path = Array(path.prefix(i + 1))
            }
            if index == level.endCell { finishGame() }
            return
        }
        guard let last = path.last, isAdjacent(last, index) else { return }
        path.append(index)
        if index == level.endCell { finishGame() }
    }

    func finishGame() {
        score = currentScore
        phase = .result
    }

    func startGame() {
        generatedLevel = PthFV3Level.generate(seed: seedInt)
        path = [level.startCell]
        phase = .playing
    }

    func restartGame() {
        seedInt += 1
        generatedLevel = PthFV3Level.generate(seed: seedInt)
        path = [level.startCell]
        phase = .playing
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .result:
                resultScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("PathFinder").font(.largeTitle).bold()
            Text("Draw a path from S to E\nShorter path = higher score")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .neumorphicCard(radius: 16)
        .padding(.horizontal, 40)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Length: \(pathLength)").font(.headline)
                    Text("Score: \(currentScore)").font(.subheadline).foregroundColor(.accentColor)
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 12)
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: gridSize), spacing: 3) {
                ForEach(0..<64, id: \.self) { index in
                    cellView(index: index)
                        .onTapGesture { tapCell(index) }
                }
            }
            .padding(10)
            .neumorphicCard(radius: 16)
            .padding(.horizontal, 12)

            Button("Reset") { startGame() }
                .buttonStyle(.bordered)
        }
    }

    var resultScreen: some View {
        VStack(spacing: 24) {
            Text("Path Complete!").font(.largeTitle).bold()
            Text("Path Length: \(pathLength)").font(.title2).foregroundStyle(.secondary)
            Text("Score: \(score)").font(.title).foregroundColor(.accentColor).bold()
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(.systemGray3))
            HStack(spacing: 16) {
                Button("Retry Same") { startGame() }.buttonStyle(.bordered)
                Button("New Level") { restartGame() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 16)
        .padding(.horizontal, 36)
    }

    func cellColor(index: Int) -> Color {
        if path.contains(index) {
            if index == level.startCell { return .green }
            if index == level.endCell { return .red }
            return .blue.opacity(0.6)
        }
        switch cellType(index: index) {
        case .start: return .green.opacity(0.5)
        case .end: return .red.opacity(0.5)
        case .wall: return Color(.darkGray)
        case .empty: return Color(.systemGray5)
        }
    }

    func cellLabel(index: Int) -> String {
        if index == level.startCell { return "S" }
        if index == level.endCell { return "E" }
        return ""
    }

    func cellView(index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellColor(index: index))
                .shadow(
                    color: path.contains(index) ? .blue.opacity(0.3) : .clear,
                    radius: 3, x: 1, y: 1
                )
                .aspectRatio(1, contentMode: .fit)
            if !cellLabel(index: index).isEmpty {
                Text(cellLabel(index: index))
                    .font(.caption).bold().foregroundColor(.white)
            }
            if let pos = path.firstIndex(of: index), pos > 0, pos < path.count - 1 {
                Text("\(pos)")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#Preview { PathFinderViewV3() }
