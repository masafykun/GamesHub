import SwiftUI

// MARK: - LCG Random (V3)

struct WFlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Types (V3)

enum WFlV3PipeType: CaseIterable {
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

struct WFlV3Cell {
    var pipeType: WFlV3PipeType
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

enum WFlV3Phase { case start, playing, solved }

// MARK: - V3 View (Neumorphism + Seeded Procedural Generation)

struct WaterFlowViewV3: View {
    static let gridSize = 6
    @State private var phase: WFlV3Phase = .start
    @State private var grid: [[WFlV3Cell]] = []
    @State private var seedInt: Int = 1
    @State private var solvedCount = 0
    @State private var solveScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .solved: solvedScreen
            }
        }
        .onAppear {
            if grid.isEmpty { grid = buildGrid(seed: seedInt) }
        }
    }

    // MARK: - Grid Generation

    func buildGrid(seed: Int) -> [[WFlV3Cell]] {
        let gs = WaterFlowViewV3.gridSize
        var rng = WFlLCG(seed: seed)
        let allTypes = WFlV3PipeType.allCases
        var cells = [[WFlV3Cell]]()

        // Generate a solvable path first, then fill rest randomly
        // Create a random path from left-center to right-center
        let sourceRow = gs / 2
        var path: [(Int,Int)] = [(sourceRow, 0)]
        var visited = Array(repeating: Array(repeating: false, count: gs), count: gs)
        visited[sourceRow][0] = true

        // Random walk from source to drain
        var cur = (sourceRow, 0)
        while cur.1 < gs - 1 {
            var moves: [(Int,Int)] = []
            let dirs = [(-1,0),(0,1),(1,0),(0,-1)]
            for (dr,dc) in dirs {
                let nr = cur.0 + dr, nc = cur.1 + dc
                guard nr >= 0 && nr < gs && nc >= 0 && nc < gs && !visited[nr][nc] else { continue }
                moves.append((nr,nc))
            }
            if moves.isEmpty { break }
            let chosen = moves[rng.nextInt(moves.count)]
            visited[chosen.0][chosen.1] = true
            path.append(chosen)
            cur = chosen
        }
        // Build path set for lookup
        var pathSet = Set<Int>()
        for (r,c) in path { pathSet.insert(r * gs + c) }

        // Build cells with correct pipe types along path
        for r in 0..<gs {
            var row = [WFlV3Cell]()
            for c in 0..<gs {
                let rot = rng.nextInt(4)
                let pt = allTypes[rng.nextInt(allTypes.count)]
                var cell = WFlV3Cell(pipeType: pt, rotation: rot)
                if r == sourceRow && c == 0 { cell.isSource = true }
                if r == sourceRow && c == gs-1 { cell.isDrain = true }

                // For path cells, assign a pipe type that connects the correct directions
                if pathSet.contains(r * gs + c) {
                    let idx = path.firstIndex(where: { $0.0 == r && $0.1 == c }) ?? 0
                    let prevDir: Int? = idx > 0 ? direction(from: path[idx-1], to: (r,c)) : nil
                    let nextDir: Int? = idx < path.count-1 ? direction(from: (r,c), to: path[idx+1]) : nil
                    let (assignedType, assignedRot) = pipeForDirections(prev: prevDir, next: nextDir, rng: &rng)
                    cell.pipeType = assignedType
                    cell.rotation = assignedRot
                }
                row.append(cell)
            }
            cells.append(row)
        }
        return cells
    }

    // Returns direction index [top=0, right=1, bottom=2, left=3] from a to b
    func direction(from a: (Int,Int), to b: (Int,Int)) -> Int {
        let dr = b.0 - a.0, dc = b.1 - a.1
        if dr == -1 { return 0 }
        if dc == 1  { return 1 }
        if dr == 1  { return 2 }
        return 3
    }

    // Returns a (pipeType, rotation) that opens in the two given directions
    func pipeForDirections(prev: Int?, next: Int?, rng: inout WFlLCG) -> (WFlV3PipeType, Int) {
        let openSet: Set<Int>
        if let p = prev, let n = next { openSet = [p, n] }
        else if let p = prev { openSet = [p, (p+2)%4] }
        else if let n = next { openSet = [n, (n+2)%4] }
        else { openSet = [0,2] }

        // Try each pipe type + rotation
        for _ in 0..<32 {
            let pt = WFlV3PipeType.allCases[rng.nextInt(WFlV3PipeType.allCases.count)]
            let rot = rng.nextInt(4)
            var cell = WFlV3Cell(pipeType: pt, rotation: rot)
            let eff = cell.effectiveOpenings
            let opens = Set((0..<4).filter { eff[$0] })
            if opens.isSuperset(of: openSet) { return (pt, rot) }
        }
        // Fallback: straight pipe in correct orientation
        if openSet.contains(0) || openSet.contains(2) {
            return (.straight, 0) // vertical
        }
        return (.straight, 1) // horizontal
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("WaterFlow").font(.largeTitle.bold())
            Text("Rotate pipes to connect\nSource to Drain")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(action: { phase = .playing }) {
                Text("Start Game")
                    .font(.headline)
                    .padding(.horizontal, 32).padding(.vertical, 12)
            }
            .neumorphicCard(radius: 16)
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(seedInt)").font(.title2.bold())
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text("Solved: \(solvedCount)").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            gridView

            Text("Tap tiles to rotate pipes").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }

    var gridView: some View {
        VStack(spacing: 4) {
            ForEach(0..<WaterFlowViewV3.gridSize, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<WaterFlowViewV3.gridSize, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .padding(14)
        .neumorphicCard(radius: 20)
        .padding(.horizontal)
    }

    func cellView(row: Int, col: Int) -> some View {
        let cell = grid[row][col]
        let fg: Color = cell.isSource ? .green : cell.isDrain ? .blue : cell.isConnected ? Color(red:0,green:0.6,blue:0.8) : .primary
        return Text(cell.pipeType.symbol)
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(fg)
            .rotationEffect(.degrees(Double(cell.rotation) * 90))
            .frame(width: 44, height: 44)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cell.isConnected ? fg.opacity(0.4) : Color.clear, lineWidth: 2)
                }
            )
            .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 2)
            .onTapGesture { rotateTile(row: row, col: col) }
    }

    var solvedScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.green)
                .scaleEffect(solveScale)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { solveScale = 1.15 }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) { solveScale = 1.0 }
                }
            Text("Level \(seedInt) complete").foregroundStyle(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.gray)
            Button(action: nextLevel) {
                Text("Next Level")
                    .font(.headline)
                    .padding(.horizontal, 32).padding(.vertical, 12)
            }
            .neumorphicCard(radius: 16)
            Button("Main Menu") { phase = .start }.foregroundStyle(.secondary)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: - Logic

    func nextLevel() {
        seedInt += 1
        solvedCount += 1
        grid = buildGrid(seed: seedInt)
        solveScale = 1.0
        phase = .playing
    }

    func rotateTile(row: Int, col: Int) {
        grid[row][col].rotation = (grid[row][col].rotation + 1) % 4
        checkSolved()
    }

    func checkSolved() {
        let gs = WaterFlowViewV3.gridSize
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

#Preview { WaterFlowViewV3() }
