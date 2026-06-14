import SwiftUI

// MARK: - Types

enum WFlPipeType: CaseIterable {
    case straight, elbow, tJunction, cross
    var symbol: String {
        switch self {
        case .straight: return "│"
        case .elbow: return "╰"
        case .tJunction: return "┤"
        case .cross: return "┼"
        }
    }
    // Openings: [top, right, bottom, left]
    var openings: [Bool] {
        switch self {
        case .straight: return [true, false, true, false]
        case .elbow: return [false, true, true, false]
        case .tJunction: return [true, true, true, false]
        case .cross: return [true, true, true, true]
        }
    }
}

struct WFlCell {
    var pipeType: WFlPipeType
    var rotation: Int // 0,1,2,3 (multiples of 90 degrees)
    var isSource: Bool = false
    var isDrain: Bool = false
    var isConnected: Bool = false

    var effectiveOpenings: [Bool] {
        let base = pipeType.openings
        var result = [Bool](repeating: false, count: 4)
        for i in 0..<4 {
            result[(i + rotation) % 4] = base[i]
        }
        return result
    }
}

enum WFlPhase { case start, playing, solved }

// MARK: - Level Data

struct WFlLevel {
    let grid: [[WFlCell]]
}

// MARK: - Main View

struct WaterFlowView: View {
    static let gridSize = 6
    @State private var phase: WFlPhase = .start
    @State private var grid: [[WFlCell]] = WaterFlowView.buildLevel(0)
    @State private var currentLevel = 0
    @State private var solvedCount = 0
    @State private var solveAnimation = false

    static func buildLevel(_ index: Int) -> [[WFlCell]] {
        let levels: [[[( WFlPipeType, Int)]]] = [
            // Level 0: simple straight path
            [
                [(.straight,1),(.elbow,0),(.straight,0),(.elbow,0),(.elbow,2),(.straight,1)],
                [(.straight,0),(.cross,0),(.elbow,1),(.tJunction,3),(.cross,0),(.straight,0)],
                [(.elbow,1),(.tJunction,0),(.cross,0),(.elbow,2),(.tJunction,1),(.elbow,3)],
                [(.straight,0),(.elbow,3),(.tJunction,2),(.straight,1),(.elbow,0),(.straight,0)],
                [(.elbow,2),(.straight,1),(.elbow,0),(.tJunction,1),(.cross,0),(.elbow,3)],
                [(.straight,1),(.elbow,2),(.straight,0),(.elbow,1),(.straight,1),(.straight,0)]
            ],
            // Level 1
            [
                [(.elbow,1),(.straight,1),(.elbow,0),(.straight,1),(.elbow,0),(.elbow,3)],
                [(.straight,0),(.elbow,2),(.tJunction,0),(.elbow,3),(.straight,0),(.straight,0)],
                [(.elbow,1),(.straight,1),(.cross,0),(.straight,1),(.tJunction,2),(.elbow,3)],
                [(.straight,0),(.elbow,0),(.tJunction,3),(.elbow,1),(.straight,0),(.straight,0)],
                [(.tJunction,1),(.cross,0),(.elbow,2),(.straight,0),(.elbow,3),(.elbow,2)],
                [(.elbow,2),(.straight,1),(.straight,1),(.elbow,1),(.straight,1),(.elbow,3)]
            ],
            // Level 2
            [
                [(.elbow,1),(.cross,0),(.elbow,0),(.tJunction,0),(.elbow,0),(.elbow,3)],
                [(.straight,0),(.tJunction,2),(.straight,1),(.elbow,3),(.straight,0),(.straight,0)],
                [(.elbow,1),(.elbow,0),(.tJunction,1),(.cross,0),(.tJunction,2),(.elbow,3)],
                [(.straight,0),(.straight,0),(.elbow,2),(.tJunction,3),(.straight,0),(.straight,0)],
                [(.tJunction,1),(.elbow,3),(.straight,1),(.elbow,1),(.cross,0),(.elbow,2)],
                [(.elbow,2),(.straight,0),(.elbow,2),(.straight,1),(.straight,1),(.elbow,3)]
            ],
            // Level 3
            [
                [(.elbow,1),(.tJunction,0),(.cross,0),(.tJunction,0),(.cross,0),(.elbow,3)],
                [(.straight,0),(.elbow,3),(.tJunction,1),(.elbow,2),(.tJunction,1),(.straight,0)],
                [(.tJunction,1),(.straight,1),(.elbow,0),(.straight,1),(.elbow,0),(.tJunction,2)],
                [(.straight,0),(.elbow,1),(.cross,0),(.elbow,3),(.cross,0),(.straight,0)],
                [(.elbow,1),(.cross,0),(.tJunction,3),(.cross,0),(.tJunction,1),(.elbow,3)],
                [(.elbow,2),(.straight,1),(.elbow,1),(.straight,1),(.elbow,1),(.elbow,2)]
            ],
            // Level 4
            [
                [(.elbow,1),(.elbow,0),(.straight,1),(.elbow,0),(.elbow,0),(.elbow,3)],
                [(.straight,0),(.cross,0),(.elbow,3),(.cross,0),(.straight,0),(.straight,0)],
                [(.tJunction,1),(.tJunction,2),(.straight,1),(.tJunction,0),(.elbow,3),(.tJunction,2)],
                [(.straight,0),(.straight,0),(.elbow,0),(.straight,0),(.straight,0),(.straight,0)],
                [(.elbow,1),(.tJunction,3),(.cross,0),(.tJunction,1),(.cross,0),(.elbow,3)],
                [(.elbow,2),(.elbow,1),(.straight,1),(.elbow,1),(.straight,1),(.elbow,2)]
            ]
        ]
        let levelData = levels[index % levels.count]
        var cells = [[WFlCell]]()
        for r in 0..<gridSize {
            var row = [WFlCell]()
            for c in 0..<gridSize {
                let (pt, rot) = levelData[r][c]
                var cell = WFlCell(pipeType: pt, rotation: rot)
                if r == gridSize/2 && c == 0 { cell.isSource = true }
                if r == gridSize/2 && c == gridSize-1 { cell.isDrain = true }
                row.append(cell)
            }
            cells.append(row)
        }
        return cells
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .solved: solvedScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("WaterFlow").font(.largeTitle.bold())
            Text("Rotate pipes to connect\nSource to Drain").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Start Game") { phase = .playing }.buttonStyle(.borderedProminent)
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(currentLevel + 1)").font(.title2.bold())
                Spacer()
                Text("Solved: \(solvedCount)").foregroundStyle(.secondary)
            }.padding(.horizontal)

            gridView

            Text("Tap tiles to rotate pipes").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }

    var gridView: some View {
        VStack(spacing: 2) {
            ForEach(0..<WaterFlowView.gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<WaterFlowView.gridSize, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
    }

    func cellView(row: Int, col: Int) -> some View {
        let cell = grid[row][col]
        let bg: Color = cell.isSource ? .green : cell.isDrain ? .blue : cell.isConnected ? .cyan.opacity(0.4) : Color(.secondarySystemBackground)
        return Text(cell.pipeType.symbol)
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .rotationEffect(.degrees(Double(cell.rotation) * 90))
            .frame(width: 48, height: 48)
            .background(bg)
            .cornerRadius(6)
            .onTapGesture { rotateTile(row: row, col: col) }
    }

    var solvedScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.green)
            Text("Level \(currentLevel + 1) complete").foregroundStyle(.secondary)
            Button("Next Level") {
                currentLevel += 1
                solvedCount += 1
                grid = WaterFlowView.buildLevel(currentLevel)
                solveAnimation = false
                phase = .playing
            }.buttonStyle(.borderedProminent)
            Button("Main Menu") { phase = .start }.foregroundStyle(.secondary)
        }.padding()
    }

    func rotateTile(row: Int, col: Int) {
        grid[row][col].rotation = (grid[row][col].rotation + 1) % 4
        checkSolved()
    }

    func checkSolved() {
        let gs = WaterFlowView.gridSize
        let sourceRow = gs / 2
        // BFS from source
        var visited = Array(repeating: Array(repeating: false, count: gs), count: gs)
        var queue: [(Int,Int)] = [(sourceRow, 0)]
        visited[sourceRow][0] = true
        let dirs = [(-1,0),(0,1),(1,0),(0,-1)] // top, right, bottom, left
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
                let neighborOpenings = newGrid[nr][nc].effectiveOpenings
                let opposite = (d + 2) % 4
                guard neighborOpenings[opposite] else { continue }
                visited[nr][nc] = true
                newGrid[nr][nc].isConnected = true
                queue.append((nr,nc))
            }
        }
        grid = newGrid
        if newGrid[sourceRow][gs-1].isConnected {
            withAnimation { phase = .solved }
        }
    }
}

#Preview { WaterFlowView() }
