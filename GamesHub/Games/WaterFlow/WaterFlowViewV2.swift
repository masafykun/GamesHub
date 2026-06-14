import SwiftUI

// MARK: - Types (V2)

enum WFlV2PipeType: CaseIterable {
    case straight, elbow, tJunction, cross
    var symbol: String {
        switch self {
        case .straight: return "│"
        case .elbow: return "╰"
        case .tJunction: return "┤"
        case .cross: return "┼"
        }
    }
    var openings: [Bool] {
        switch self {
        case .straight: return [true, false, true, false]
        case .elbow: return [false, true, true, false]
        case .tJunction: return [true, true, true, false]
        case .cross: return [true, true, true, true]
        }
    }
}

struct WFlV2Cell {
    var pipeType: WFlV2PipeType
    var rotation: Int
    var isSource: Bool = false
    var isDrain: Bool = false
    var isConnected: Bool = false

    var effectiveOpenings: [Bool] {
        let base = pipeType.openings
        var result = [Bool](repeating: false, count: 4)
        for i in 0..<4 { result[(i + rotation) % 4] = base[i] }
        return result
    }
}

enum WFlV2Phase { case start, playing, solved }

// MARK: - V2 View (Glassmorphism + Adaptive Difficulty)

struct WaterFlowViewV2: View {
    static let gridSize = 6
    @State private var phase: WFlV2Phase = .start
    @State private var grid: [[WFlV2Cell]] = WaterFlowViewV2.buildLevel(0)
    @State private var currentLevel = 0
    @State private var solvedCount = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var solveFlash = false

    // Adaptive difficulty: if last 5 rounds all solved, increase difficulty
    var difficultyLabel: String {
        if difficultyMultiplier >= 1.4 { return "Expert" }
        if difficultyMultiplier >= 1.2 { return "Hard" }
        return "Normal"
    }

    static func buildLevel(_ index: Int, scramble: Bool = false) -> [[WFlV2Cell]] {
        let gs = gridSize
        let pipeTypes: [WFlV2PipeType] = [.straight, .elbow, .tJunction, .cross]
        let rotations = [0,1,2,3]
        var cells = [[WFlV2Cell]]()
        let seed = index * 7 + 3
        var rng = seed
        func nextRand(_ n: Int) -> Int { rng = rng &* 1664525 &+ 1013904223; return abs(rng) % n }

        for r in 0..<gs {
            var row = [WFlV2Cell]()
            for c in 0..<gs {
                let pt = pipeTypes[nextRand(pipeTypes.count)]
                let rot = scramble ? rotations[nextRand(4)] : 0
                var cell = WFlV2Cell(pipeType: pt, rotation: rot)
                if r == gs/2 && c == 0 { cell.isSource = true; cell.pipeType = .tJunction; cell.rotation = 1 }
                if r == gs/2 && c == gs-1 { cell.isDrain = true; cell.pipeType = .tJunction; cell.rotation = 3 }
                row.append(cell)
            }
            cells.append(row)
        }
        return cells
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red:0.1, green:0.2, blue:0.5), Color(red:0.3, green:0.1, blue:0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .solved: solvedScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("WaterFlow").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Rotate pipes to connect\nSource to Drain")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button(action: { phase = .playing }) {
                Text("Start Game")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(currentLevel + 1)").font(.title2.bold()).foregroundStyle(.white)
                    Text("Difficulty: \(difficultyLabel)").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("Solved: \(solvedCount)").foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            gridView

            Text("Tap tiles to rotate").font(.caption).foregroundStyle(.white.opacity(0.6))
        }.padding()
    }

    var gridView: some View {
        VStack(spacing: 3) {
            ForEach(0..<WaterFlowViewV2.gridSize, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<WaterFlowViewV2.gridSize, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }

    func cellView(row: Int, col: Int) -> some View {
        let cell = grid[row][col]
        let tint: Color = cell.isSource ? .green : cell.isDrain ? .blue : cell.isConnected ? .cyan : .white
        return Text(cell.pipeType.symbol)
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(Double(cell.rotation) * 90))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.3), lineWidth: 1))
            )
            .scaleEffect(cell.isConnected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: cell.isConnected)
            .onTapGesture { rotateTile(row: row, col: col) }
    }

    var solvedScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.green)
            Text("Level \(currentLevel + 1) complete")
                .foregroundStyle(.white.opacity(0.8))
            Text("Difficulty: \(difficultyLabel)")
                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Button(action: nextLevel) {
                Text("Next Level")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            Button("Main Menu") { phase = .start }.foregroundStyle(.white.opacity(0.6))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: - Logic

    func nextLevel() {
        recentResults.append(true)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.0)
        }
        currentLevel += 1
        solvedCount += 1
        grid = WaterFlowViewV2.buildLevel(currentLevel, scramble: difficultyMultiplier > 1.0)
        phase = .playing
    }

    func rotateTile(row: Int, col: Int) {
        grid[row][col].rotation = (grid[row][col].rotation + 1) % 4
        checkSolved()
    }

    func checkSolved() {
        let gs = WaterFlowViewV2.gridSize
        let sourceRow = gs / 2
        var visited = Array(repeating: Array(repeating: false, count: gs), count: gs)
        var queue: [(Int,Int)] = [(sourceRow, 0)]
        visited[sourceRow][0] = true
        let dirs = [(-1,0),(0,1),(1,0),(0,-1)]
        var newGrid = grid
        for r in 0..<gs { for c in 0..<gs { newGrid[r][c].isConnected = false } }
        newGrid[sourceRow][0].isConnected = true

        while !queue.isEmpty {
            let (r,c) = queue.removeFirst()
            let openings = newGrid[r][c].effectiveOpenings
            for d in 0..<4 {
                guard openings[d] else { continue }
                let nr = r + dirs[d].0, nc = c + dirs[d].1
                guard nr >= 0 && nr < gs && nc >= 0 && nc < gs else { continue }
                guard !visited[nr][nc] else { continue }
                let opposite = (d + 2) % 4
                guard newGrid[nr][nc].effectiveOpenings[opposite] else { continue }
                visited[nr][nc] = true
                newGrid[nr][nc].isConnected = true
                queue.append((nr,nc))
            }
        }
        grid = newGrid
        if newGrid[sourceRow][gs-1].isConnected {
            withAnimation(.spring()) { phase = .solved }
        }
    }
}

#Preview { WaterFlowViewV2() }
