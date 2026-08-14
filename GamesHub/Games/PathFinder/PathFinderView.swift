import SwiftUI

// MARK: - Models 

enum PathFinderCellType {
    case empty, wall, start, end
}

enum PathFinderGamePhase {
    case start, playing, result
}

struct PathFinderLevel {
    let walls: Set<Int>
    let startCell: Int
    let endCell: Int

    static func level(at index: Int, difficulty: Double) -> PathFinderLevel {
        let base = PathFinderLevel.baseLevels[index % PathFinderLevel.baseLevels.count]
        if difficulty > 1.2 {
            var extraWalls = base.walls
            let extras = [7, 15, 23, 31, 32, 40, 48, 56]
            for e in extras.prefix(Int(difficulty * 2)) {
                if e != base.startCell && e != base.endCell { extraWalls.insert(e) }
            }
            return PathFinderLevel(walls: extraWalls, startCell: base.startCell, endCell: base.endCell)
        }
        return base
    }

    static let baseLevels: [PathFinderLevel] = [
        PathFinderLevel(walls: [2, 3, 10, 18, 19, 27, 35, 43, 44, 52, 53, 60, 61], startCell: 0, endCell: 63),
        PathFinderLevel(walls: [1, 9, 17, 25, 14, 22, 30, 38, 46, 54, 37, 45, 53], startCell: 8, endCell: 55),
        PathFinderLevel(walls: [4, 5, 6, 12, 20, 28, 29, 30, 38, 46, 42, 43, 51], startCell: 0, endCell: 56)
    ]
}

// MARK: -  View

struct PathFinderView: View {
    @State private var phase: PathFinderGamePhase = .start
    @State private var levelIndex: Int = 0
    @State private var path: [Int] = []
    @State private var score: Int = 100
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0

    private let gridSize = 8

    var level: PathFinderLevel { PathFinderLevel.level(at: levelIndex, difficulty: difficulty) }
    var pathLength: Int { max(0, path.count - 1) }
    var currentScore: Int { max(0, 100 - pathLength) }

    func cellType(index: Int) -> PathFinderCellType {
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
        let success = score >= 60
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 2.0)
        }
        phase = .result
    }

    func startGame() {
        path = [level.startCell]
        phase = .playing
    }

    func nextLevel() {
        levelIndex = (levelIndex + 1) % PathFinderLevel.baseLevels.count
        path = []
        phase = .start
    }

    var glassBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.3, green: 0.1, blue: 0.6), Color(red: 0.1, green: 0.4, blue: 0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var glassCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var body: some View {
        ZStack {
            glassBackground

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
            Text("PathFinder").font(.largeTitle).bold().foregroundColor(.white)
            Text("Draw a path from S to E\nShorter path = higher score")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
            if difficulty > 1.0 {
                Text("Difficulty: \(String(format: "%.1f", difficulty))x")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
            Text("Level \(levelIndex + 1)").font(.title2).foregroundColor(.cyan)
            Button("Start Game") { startGame() }
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(glassCard)
        .padding(.horizontal, 40)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(levelIndex + 1)").foregroundColor(.white).font(.headline)
                Spacer()
                Text("Length: \(pathLength)").foregroundColor(.white).font(.headline)
                Spacer()
                Text("Score: \(currentScore)").foregroundColor(.cyan).font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(glassCard)
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: gridSize), spacing: 2) {
                ForEach(0..<64, id: \.self) { index in
                    cellView(index: index)
                        .onTapGesture { tapCell(index) }
                }
            }
            .padding(8)
            .background(glassCard)
            .padding(.horizontal, 12)

            Button("Reset") { startGame() }
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
                .foregroundColor(.white)
        }
    }

    var resultScreen: some View {
        VStack(spacing: 24) {
            Text("Complete!").font(.largeTitle).bold().foregroundColor(.white)
            Text("Length: \(pathLength)").font(.title2).foregroundColor(.white.opacity(0.8))
            Text("Score: \(score)").font(.title).foregroundColor(.cyan).bold()
            if difficulty > 1.0 {
                Text("Difficulty: \(String(format: "%.1f", difficulty))x").foregroundColor(.yellow).font(.caption)
            }
            HStack(spacing: 16) {
                Button("Retry") { startGame() }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.white)
                Button("Next Level") { nextLevel() }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.cyan.opacity(0.5), lineWidth: 1))
                    .foregroundColor(.cyan)
            }
        }
        .padding(32)
        .background(glassCard)
        .padding(.horizontal, 40)
    }

    func cellColor(index: Int) -> Color {
        if path.contains(index) {
            if index == level.startCell { return .green }
            if index == level.endCell { return .red }
            return .cyan.opacity(0.7)
        }
        switch cellType(index: index) {
        case .start: return .green.opacity(0.6)
        case .end: return .red.opacity(0.6)
        case .wall: return Color(white: 0.2, opacity: 0.9)
        case .empty: return Color.white.opacity(0.15)
        }
    }

    func cellLabel(index: Int) -> String {
        if index == level.startCell { return "S" }
        if index == level.endCell { return "E" }
        return ""
    }

    func cellView(index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(cellColor(index: index))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(path.contains(index) ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .aspectRatio(1, contentMode: .fit)
            if !cellLabel(index: index).isEmpty {
                Text(cellLabel(index: index))
                    .font(.caption).bold().foregroundColor(.white)
            }
        }
    }
}

#Preview { PathFinderView() }
