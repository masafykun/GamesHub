import SwiftUI

// MARK: - Pipe Types

// MARK: - Tile Model

// MARK: - Game State

struct PipeConnectGameState {
    var grid: [[PipeConnectTile]] = []
    var moves: Int = 0
    var isWon: Bool = false
    var sourcePos: (row: Int, col: Int) = (0, 0)
    var sinkPos: (row: Int, col: Int) = (5, 5)
    var connectedCells: Set<String> = []

    static let gridSize = 6
}

// MARK: - LCG Generator

struct PipeConnectLCG {
    var state: UInt64

    init(seed: Int) {
        self.state = UInt64(seed)
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(_ range: Int) -> Int {
        return Int(next() % UInt64(range))
    }
}

// MARK: - Grid Generator

struct PipeConnectGenerator {
    static func generate(seed: Int) -> [[PipeConnectTile]] {
        var lcg = PipeConnectLCG(seed: seed)
        let size = PipeConnectGameState.gridSize

        // Build a valid path from (0,0) to (5,5) using random walk
        var path: [(Int, Int)] = []
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)
        path.append((0, 0))
        visited[0][0] = true

        // Random walk to reach sink
        var current = (0, 0)
        var attempts = 0
        while current != (size - 1, size - 1) && attempts < 500 {
            attempts += 1
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)].shuffled(using: &lcg)
            var moved = false
            for dir in directions {
                let nr = current.0 + dir.0
                let nc = current.1 + dir.1
                if nr >= 0 && nr < size && nc >= 0 && nc < size && !visited[nr][nc] {
                    // Prefer moving toward sink
                    visited[nr][nc] = true
                    path.append((nr, nc))
                    current = (nr, nc)
                    moved = true
                    break
                }
            }
            if !moved {
                // Backtrack
                if path.count > 1 {
                    path.removeLast()
                    current = path.last!
                } else {
                    break
                }
            }
        }

        // If we didn't reach the sink, use a forced path
        if current != (size - 1, size - 1) {
            path = buildForcedPath(lcg: &lcg)
        }

        // Build grid from path
        var grid: [[PipeConnectTile]] = Array(repeating: Array(repeating: PipeConnectTile(type: .straight, rotation: 0), count: size), count: size)
        let pathSet = Set(path.map { "\($0.0),\($0.1)" })

        // Fill path cells with correct pipe types
        for i in 0..<path.count {
            let (r, c) = path[i]
            let prevDir: Int? = i > 0 ? directionFrom(path[i-1], to: path[i]) : nil
            let nextDir: Int? = i < path.count - 1 ? directionFrom(path[i], to: path[i+1]) : nil

            var tile: PipeConnectTile
            if let prev = prevDir, let next = nextDir {
                // Middle of path: need both prev (incoming, so opposite) and next (outgoing)
                let incomingDir = (prev + 2) % 4  // direction from which we came
                tile = makeTile(dir1: incomingDir, dir2: next, lcg: &lcg)
            } else if let next = nextDir {
                // Source: only going forward
                tile = makeSingleDirectionTile(going: next, lcg: &lcg)
                tile.type = .source
            } else if let prev = prevDir {
                // Sink: only came from somewhere
                let incomingDir = (prev + 2) % 4
                tile = makeSingleDirectionTile(going: incomingDir, lcg: &lcg)
                tile.type = .sink
            } else {
                tile = PipeConnectTile(type: .straight, rotation: 0)
            }
            grid[r][c] = tile
        }

        // Fill non-path cells with random pipes
        for r in 0..<size {
            for c in 0..<size {
                if !pathSet.contains("\(r),\(c)") {
                    let pipeTypeRaw = lcg.nextInt(3)
                    let rot = lcg.nextInt(4)
                    let pipeType = [PipeConnectPipeType.straight, .elbow, .tJunction][pipeTypeRaw % 3]
                    grid[r][c] = PipeConnectTile(type: pipeType, rotation: rot)
                }
            }
        }

        // Randomize rotation of all path tiles (except source/sink) to make puzzle interesting
        for i in 1..<(path.count - 1) {
            let (r, c) = path[i]
            let extraRotations = lcg.nextInt(4)
            if extraRotations > 0 {
                grid[r][c].rotation = (grid[r][c].rotation + extraRotations) % 4
            }
        }

        return grid
    }

    private static func buildForcedPath(lcg: inout PipeConnectLCG) -> [(Int, Int)] {
        let size = PipeConnectGameState.gridSize
        var path: [(Int, Int)] = [(0, 0)]
        var r = 0
        var c = 0
        while r < size - 1 { path.append((r + 1, c)); r += 1 }
        while c < size - 1 { path.append((r, c + 1)); c += 1 }
        return path
    }

    private static func directionFrom(_ from: (Int, Int), to: (Int, Int)) -> Int {
        let dr = to.0 - from.0
        let dc = to.1 - from.1
        if dr == -1 { return 0 }  // up
        if dc == 1  { return 1 }  // right
        if dr == 1  { return 2 }  // down
        if dc == -1 { return 3 }  // left
        return 0
    }

    private static func makeTile(dir1: Int, dir2: Int, lcg: inout PipeConnectLCG) -> PipeConnectTile {
        let dirs = Set([dir1, dir2])
        // Straight: opposite pairs
        if dirs == Set([0, 2]) || dirs == Set([1, 3]) {
            let baseRot = dirs == Set([0, 2]) ? 0 : 1
            return PipeConnectTile(type: .straight, rotation: baseRot)
        }
        // Elbow: any other pair of 2
        // Figure out correct rotation for elbow (base: top+right = [0,1])
        let elbowRotations: [Set<Int>: Int] = [
            Set([0, 1]): 0,
            Set([1, 2]): 1,
            Set([2, 3]): 2,
            Set([3, 0]): 3
        ]
        let rot = elbowRotations[dirs] ?? 0
        return PipeConnectTile(type: .elbow, rotation: rot)
    }

    private static func makeSingleDirectionTile(going: Int, lcg: inout PipeConnectLCG) -> PipeConnectTile {
        // For source/sink, use a straight pipe aligned with the going direction
        if going == 0 || going == 2 {
            return PipeConnectTile(type: .straight, rotation: 0)
        } else {
            return PipeConnectTile(type: .straight, rotation: 1)
        }
    }
}

extension Array {
    mutating func shuffle(using lcg: inout PipeConnectLCG) {
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = lcg.nextInt(i + 1)
            swapAt(i, j)
        }
    }

    func shuffled(using lcg: inout PipeConnectLCG) -> [Element] {
        var copy = self
        copy.shuffle(using: &lcg)
        return copy
    }
}

// MARK: - Pipe Shape Renderer

// MARK: - Tile View

struct PCV3TileView: View {
    let tile: PipeConnectTile
    let isConnected: Bool
    let cellSize: CGFloat
    let onTap: () -> Void

    var body: some View {
        PipeConnectPipeShape(tile: tile, cellSize: cellSize, isConnected: isConnected)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture { onTap() }
    }
}

// MARK: - Main View

struct PipeConnectViewV3: View {
    @State private var gameState = PipeConnectGameState()
    @State private var seedInt: Int = 1
    @State private var showWinBanner: Bool = false
    @State private var animateWin: Bool = false

    let gridSize = PipeConnectGameState.gridSize

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let availableWidth = min(geo.size.width - 32, geo.size.height - 160)
            let cellSize = availableWidth / CGFloat(gridSize)

            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                if isLandscape {
                    HStack(spacing: 16) {
                        sidePanel
                            .frame(width: 160)
                        gridView(cellSize: cellSize)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        topPanel
                        gridView(cellSize: cellSize)
                        bottomPanel
                    }
                    .padding()
                }

                if showWinBanner {
                    winOverlay
                }
            }
        }
        .onAppear {
            startNewGame()
        }
    }

    // MARK: - Subviews

    private var topPanel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PIPE CONNECT")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("SEED: #\(seedInt)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOVES")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(gameState.moves)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .neumorphicCard()
    }

    private var sidePanel: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("PIPE CONNECT")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text("V3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            Divider()

            VStack(spacing: 4) {
                Text("SEED")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("#\(seedInt)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .neumorphicCard()

            VStack(spacing: 4) {
                Text("MOVES")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(gameState.moves)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .neumorphicCard()

            statusIndicator
                .frame(maxWidth: .infinity)

            Spacer()

            Button(action: restartGame) {
                Label("New Game", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom)
        }
        .padding(12)
        .neumorphicCard()
    }

    private var bottomPanel: some View {
        HStack(spacing: 12) {
            statusIndicator
            Spacer()
            Button(action: restartGame) {
                Label("New Game", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .neumorphicCard()
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gameState.isWon ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .shadow(color: gameState.isWon ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
            Text(gameState.isWon ? "CONNECTED!" : "Disconnected")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(gameState.isWon ? .green : .orange)
        }
        .padding(8)
        .neumorphicCard()
    }

    private func gridView(cellSize: CGFloat) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let tile = gameState.grid[row][col]
                        let key = "\(row),\(col)"
                        let connected = gameState.connectedCells.contains(key)
                        PCV3TileView(
                            tile: tile,
                            isConnected: connected,
                            cellSize: cellSize,
                            onTap: { rotateTile(row: row, col: col) }
                        )
                    }
                }
            }
        }
        .padding(10)
        .neumorphicCard()
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showWinBanner = false }

            VStack(spacing: 20) {
                Text("YOU WIN!")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(.green)
                    .scaleEffect(animateWin ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animateWin)

                Text("Seed #\(seedInt) solved!")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Moves: \(gameState.moves)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Button(action: restartGame) {
                    Text("Play Next")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(32)
            .neumorphicCard()
            .onAppear { animateWin = true }
            .onDisappear { animateWin = false }
        }
    }

    // MARK: - Game Logic

    private func startNewGame() {
        var newState = PipeConnectGameState()
        newState.grid = PipeConnectGenerator.generate(seed: seedInt)
        newState.sourcePos = (0, 0)
        newState.sinkPos = (gridSize - 1, gridSize - 1)
        newState.moves = 0
        newState.isWon = false
        newState.connectedCells = []
        gameState = newState
        showWinBanner = false
        updateConnectivity()
    }

    private func restartGame() {
        seedInt += 1
        startNewGame()
    }

    private func rotateTile(row: Int, col: Int) {
        guard !gameState.isWon else { return }
        gameState.grid[row][col].rotation = (gameState.grid[row][col].rotation + 1) % 4
        gameState.moves += 1
        updateConnectivity()
    }

    private func updateConnectivity() {
        let size = gridSize
        var visited: Set<String> = []
        var queue: [(Int, Int)] = [(gameState.sourcePos.row, gameState.sourcePos.col)]
        visited.insert("0,0")

        // BFS flood-fill from source
        let deltas: [(Int, Int, PipeConnectDirection, PipeConnectDirection)] = [
            (-1, 0, .up, .down), (0, 1, .right, .left), (1, 0, .down, .up), (0, -1, .left, .right)
        ]

        var head = 0
        while head < queue.count {
            let (r, c) = queue[head]
            head += 1

            let tile = gameState.grid[r][c]
            for (dr, dc, outDir, inDir) in deltas {
                let nr = r + dr
                let nc = c + dc
                let key = "\(nr),\(nc)"
                guard nr >= 0 && nr < size && nc >= 0 && nc < size else { continue }
                guard !visited.contains(key) else { continue }
                guard tile.openDirections.contains(outDir) else { continue }
                let neighbor = gameState.grid[nr][nc]
                guard neighbor.openDirections.contains(inDir) else { continue }
                visited.insert(key)
                queue.append((nr, nc))
            }
        }

        gameState.connectedCells = visited
        let sinkKey = "\(gameState.sinkPos.row),\(gameState.sinkPos.col)"
        let wasWon = gameState.isWon
        gameState.isWon = visited.contains(sinkKey)

        if gameState.isWon && !wasWon {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showWinBanner = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PipeConnectViewV3()
}
