import SwiftUI

// MARK: - Models

enum PthFCellType {
    case empty, wall, start, end
}

enum PthFGamePhase {
    case start, playing, result
}

struct PthFCell: Identifiable {
    let id: Int
    let row: Int
    let col: Int
    let type: PthFCellType
}

struct PthFLevel {
    let walls: Set<Int>
    let startCell: Int
    let endCell: Int

    static let levels: [PthFLevel] = [
        PthFLevel(
            walls: [2, 3, 10, 18, 19, 27, 35, 43, 44, 52, 53, 60, 61],
            startCell: 0,
            endCell: 63
        ),
        PthFLevel(
            walls: [1, 9, 17, 25, 14, 22, 30, 38, 46, 54, 37, 45, 53],
            startCell: 8,
            endCell: 55
        ),
        PthFLevel(
            walls: [4, 5, 6, 12, 20, 28, 29, 30, 38, 46, 42, 43, 51],
            startCell: 0,
            endCell: 56
        )
    ]
}

// MARK: - Main View

struct PathFinderView: View {
    @State private var phase: PthFGamePhase = .start
    @State private var levelIndex: Int = 0
    @State private var path: [Int] = []
    @State private var score: Int = 100

    private let gridSize = 8

    var level: PthFLevel { PthFLevel.levels[levelIndex] }

    var pathLength: Int { max(0, path.count - 1) }
    var currentScore: Int { max(0, 100 - pathLength) }

    func cellType(index: Int) -> PthFCellType {
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
        path = [level.startCell]
        phase = .playing
    }

    func nextLevel() {
        levelIndex = (levelIndex + 1) % PthFLevel.levels.count
        path = []
        phase = .start
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("PathFinder").font(.largeTitle).bold()
            Text("Draw a path from S to E\nShorter path = higher score").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Level \(levelIndex + 1)").font(.title2).foregroundColor(.accentColor)
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(levelIndex + 1)").font(.headline)
                Spacer()
                Text("Length: \(pathLength)").font(.headline)
                Spacer()
                Text("Score: \(currentScore)").font(.headline).foregroundColor(.accentColor)
            }
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: gridSize), spacing: 2) {
                ForEach(0..<64, id: \.self) { index in
                    cellView(index: index)
                        .onTapGesture { tapCell(index) }
                }
            }
            .padding(.horizontal, 8)

            Button("Reset") { startGame() }
                .buttonStyle(.bordered)
        }
    }

    var resultScreen: some View {
        VStack(spacing: 24) {
            Text("Path Complete!").font(.largeTitle).bold()
            Text("Path Length: \(pathLength)").font(.title2)
            Text("Score: \(score)").font(.title).foregroundColor(.accentColor).bold()
            HStack(spacing: 16) {
                Button("Retry") { startGame() }.buttonStyle(.bordered)
                Button("Next Level") { nextLevel() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    func cellColor(index: Int) -> Color {
        if path.contains(index) {
            if index == level.startCell { return .green }
            if index == level.endCell { return .red }
            return .blue.opacity(0.7)
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
                .aspectRatio(1, contentMode: .fit)
            if !cellLabel(index: index).isEmpty {
                Text(cellLabel(index: index))
                    .font(.caption).bold().foregroundColor(.white)
            }
            if let pos = path.firstIndex(of: index), pos > 0, pos < path.count - 1 {
                Text("\(pos)").font(.system(size: 8)).foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

#Preview { PathFinderView() }
