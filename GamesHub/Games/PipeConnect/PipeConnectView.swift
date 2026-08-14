import SwiftUI

// MARK: - Pipe Types & Enums

enum PipeConnectPipeType {
    case straight   // connects two opposite sides
    case elbow      // connects two adjacent sides
    case tJunction  // connects three sides
    case source     // connects all sides (conceptually), acts as source
    case sink       // connects all sides (conceptually), acts as sink
    case empty      // no connections
}

/// Represents the four cardinal directions
enum PipeConnectDirection: CaseIterable {
    case up, right, down, left

    var opposite: PipeConnectDirection {
        switch self {
        case .up:    return .down
        case .right: return .left
        case .down:  return .up
        case .left:  return .right
        }
    }

    /// Rotated 90° clockwise
    var rotated: PipeConnectDirection {
        switch self {
        case .up:    return .right
        case .right: return .down
        case .down:  return .left
        case .left:  return .up
        }
    }
}

// MARK: - Tile Model

struct PipeConnectTile {
    var type: PipeConnectPipeType
    var rotation: Int   // 0, 1, 2, 3 (multiples of 90°)
    var isConnected: Bool = false

    /// Returns the set of directions this tile opens to, given its rotation.
    var openDirections: Set<PipeConnectDirection> {
        let base = baseOpenDirections
        var result = Set<PipeConnectDirection>()
        for dir in base {
            var rotated = dir
            for _ in 0..<(rotation % 4) {
                rotated = rotated.rotated
            }
            result.insert(rotated)
        }
        return result
    }

    private var baseOpenDirections: Set<PipeConnectDirection> {
        switch type {
        case .straight:
            return [.up, .down]
        case .elbow:
            return [.up, .right]
        case .tJunction:
            return [.up, .right, .down]
        case .source, .sink:
            return [.up, .right, .down, .left]
        case .empty:
            return []
        }
    }
}

// MARK: - Layout Definition

struct PipeConnectLayout {
    let name: String
    // Each cell: (row, col, type, rotation)
    let tiles: [(row: Int, col: Int, type: PipeConnectPipeType, rotation: Int)]
    let sourcePos: (row: Int, col: Int)
    let sinkPos: (row: Int, col: Int)
}

// MARK: - Game Model

class PipeConnectGame: ObservableObject {
    static let gridSize = 6

    @Published var grid: [[PipeConnectTile]] = []
    @Published var moves: Int = 0
    @Published var isWon: Bool = false
    @Published var layoutIndex: Int = 0

    private let layouts: [PipeConnectLayout] = PipeConnectGame.makeLayouts()

    var sourcePos: (row: Int, col: Int) = (0, 0)
    var sinkPos: (row: Int, col: Int) = (5, 5)

    init() {
        loadLayout(index: 0)
    }

    func loadLayout(index: Int) {
        layoutIndex = index
        let layout = layouts[index]
        sourcePos = layout.sourcePos
        sinkPos = layout.sinkPos
        moves = 0
        isWon = false

        let n = PipeConnectGame.gridSize
        var newGrid = Array(
            repeating: Array(repeating: PipeConnectTile(type: .empty, rotation: 0), count: n),
            count: n
        )

        for cell in layout.tiles {
            newGrid[cell.row][cell.col] = PipeConnectTile(type: cell.type, rotation: cell.rotation)
        }

        // Place source and sink
        newGrid[layout.sourcePos.row][layout.sourcePos.col] = PipeConnectTile(type: .source, rotation: 0)
        newGrid[layout.sinkPos.row][layout.sinkPos.col] = PipeConnectTile(type: .sink, rotation: 0)

        grid = newGrid
        scrambleRotations()
        updateConnections()
    }

    /// Rotates every rotatable tile at random; a layout ships in its solved
    /// state, so without this the puzzle would open already finished.
    private func scrambleRotations() {
        let n = PipeConnectGame.gridSize
        var attempts = 0
        repeat {
            for r in 0..<n {
                for c in 0..<n {
                    let type = grid[r][c].type
                    guard type != .source, type != .sink, type != .empty else { continue }
                    grid[r][c].rotation = Int.random(in: 0..<4)
                }
            }
            updateConnections()
            attempts += 1
        } while isWon && attempts < 20
        moves = 0
    }

    func tap(row: Int, col: Int) {
        guard !isWon else { return }
        let type = grid[row][col].type
        guard type != .source && type != .sink && type != .empty else { return }

        grid[row][col].rotation = (grid[row][col].rotation + 1) % 4
        moves += 1
        updateConnections()
    }

    func nextLayout() {
        let next = (layoutIndex + 1) % layouts.count
        loadLayout(index: next)
    }

    func restart() {
        loadLayout(index: layoutIndex)
    }

    // MARK: - Connection Logic (BFS from source)

    private func updateConnections() {
        let n = PipeConnectGame.gridSize
        // Reset all
        for r in 0..<n {
            for c in 0..<n {
                grid[r][c].isConnected = false
            }
        }

        // BFS
        var visited = Set<String>()
        var queue = [(row: Int, col: Int)]()
        let sr = sourcePos.row
        let sc = sourcePos.col
        queue.append((sr, sc))
        visited.insert("\(sr),\(sc)")
        grid[sr][sc].isConnected = true

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let r = current.row
            let c = current.col
            let tile = grid[r][c]

            for dir in tile.openDirections {
                let (nr, nc) = neighbor(r: r, c: c, dir: dir)
                guard nr >= 0 && nr < n && nc >= 0 && nc < n else { continue }
                let key = "\(nr),\(nc)"
                guard !visited.contains(key) else { continue }

                let neighborTile = grid[nr][nc]
                // Neighbor must open back toward current cell
                if neighborTile.openDirections.contains(dir.opposite) {
                    visited.insert(key)
                    grid[nr][nc].isConnected = true
                    queue.append((nr, nc))
                }
            }
        }

        // Win check: sink is connected
        isWon = grid[sinkPos.row][sinkPos.col].isConnected
    }

    private func neighbor(r: Int, c: Int, dir: PipeConnectDirection) -> (Int, Int) {
        switch dir {
        case .up:    return (r - 1, c)
        case .down:  return (r + 1, c)
        case .left:  return (r, c - 1)
        case .right: return (r, c + 1)
        }
    }

    // MARK: - Hardcoded Layouts

    static func makeLayouts() -> [PipeConnectLayout] {
        // Layout 1: simple horizontal/vertical path
        let layout1 = PipeConnectLayout(
            name: "Classic",
            tiles: [
                // Row 0: source at (0,0), straight pipes across
                (0, 1, .straight, 1),  // horizontal
                (0, 2, .straight, 1),
                (0, 3, .elbow,    2),  // turn down
                // Col 3 going down
                (1, 3, .straight, 0),
                (2, 3, .elbow,    3),  // turn right
                // Row 2 going right
                (2, 4, .straight, 1),
                (2, 5, .elbow,    2),  // turn down
                // Col 5 going down
                (3, 5, .straight, 0),
                (4, 5, .straight, 0),
                // sink at (5,5)
            ],
            sourcePos: (0, 0),
            sinkPos: (5, 5)
        )

        // Layout 2: snaking path with T-junctions
        let layout2 = PipeConnectLayout(
            name: "Zigzag",
            tiles: [
                // source at (0,0), go right
                (0, 1, .straight, 1),
                (0, 2, .straight, 1),
                (0, 3, .straight, 1),
                (0, 4, .elbow,    2),  // turn down
                (1, 4, .elbow,    3),  // turn left
                (1, 3, .straight, 1),
                (1, 2, .straight, 1),
                (1, 1, .elbow,    2),  // turn down
                (2, 1, .elbow,    1),  // turn right
                (2, 2, .straight, 1),
                (2, 3, .straight, 1),
                (2, 4, .straight, 1),
                (2, 5, .elbow,    2),  // turn down
                (3, 5, .straight, 0),
                (4, 5, .elbow,    3),  // turn left
                (4, 4, .straight, 1),
                (4, 3, .straight, 1),
                (4, 2, .straight, 1),
                (4, 1, .elbow,    2),  // turn down
                (5, 1, .straight, 1),
                (5, 2, .straight, 1),
                (5, 3, .straight, 1),
                (5, 4, .straight, 1),
                // sink at (5,5)
            ],
            sourcePos: (0, 0),
            sinkPos: (5, 5)
        )

        // Layout 3: uses T-junctions (only one valid path still reaches sink)
        let layout3 = PipeConnectLayout(
            name: "Branch",
            tiles: [
                // source at (0,2), go right then down
                (0, 3, .straight, 1),
                (0, 4, .elbow,    2),  // turn down
                (1, 4, .tJunction, 1), // opens up, down, left — left is dead end here
                (1, 3, .elbow,    0),  // opens up, right — dead end (connects to tJunction left, but tJunction left goes to (1,3) which goes right back — valid loop? no: elbow at rotation0 = up+right; (1,3).right=(1,4) tJunction left open, (1,3).up=(0,3) straight connects)
                // continue down from tJunction
                (2, 4, .straight, 0),
                (3, 4, .elbow,    2),  // turn right... wait let's make a clean path
                (3, 4, .elbow,    3),  // turn left
                (3, 3, .straight, 1),
                (3, 2, .straight, 1),
                (3, 1, .elbow,    2),  // turn down
                (4, 1, .straight, 0),
                (5, 1, .elbow,    1),  // turn right
                (5, 2, .straight, 1),
                (5, 3, .straight, 1),
                (5, 4, .straight, 1),
                // sink at (5,5)
            ],
            sourcePos: (0, 2),
            sinkPos: (5, 5)
        )

        return [layout1, layout2, layout3]
    }
}

// MARK: - Enums

enum PipeConnectTileRole {
    case normal
    case source
    case sink
}

enum PipeConnectDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

// MARK: - Tile Model

// MARK: - Layout Definition

// MARK: - Layout Builder

// MARK: - View Model

// MARK: - Main View

struct PipeConnectView: View {
    @StateObject private var game = PipeConnectGame()

    @State private var currentLayoutIndex: Int = 0
    @State private var difficulty: PipeConnectDifficulty = .medium
    @State private var roundScores: [Int] = []

    @State private var startTime: Date = Date()
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var showWinOverlay: Bool = false
    @State private var rotationAngles: [[Double]] = Array(repeating: Array(repeating: 0.0, count: 6), count: 6)
    @State private var animatingCells: Set<String> = []

    // Difficulty thresholds (solve time in seconds)
    private let easyThreshold: Double = 60
    private let hardThreshold: Double = 20

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 16) {
                headerBar
                statsRow
                gridView
                Spacer()
            }
            .padding()

            if showWinOverlay {
                winOverlayView
            }
        }
        .onAppear { startGame() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.18),
                Color(red: 0.10, green: 0.14, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    var headerBar: some View {
        HStack {
            Text("Pipe Connect")
                .font(.title2.bold())
                .foregroundColor(.white)

            Spacer()

            difficultyBadge
        }
    }

    var difficultyBadge: some View {
        Text(difficulty.rawValue)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(difficulty.badgeColor.opacity(0.8))
                    .background(.ultraThinMaterial, in: Capsule())
            )
    }

    // MARK: - Stats Row

    var statsRow: some View {
        HStack(spacing: 16) {
            statCard(icon: "arrow.triangle.2.circlepath", label: "Moves", value: "\(game.moves)")
            statCard(icon: "clock", label: "Time", value: timeString(elapsedSeconds))
            statCard(icon: "checkmark.circle", label: "Status",
                     value: game.isWon ? "Connected!" : "Disconnected",
                     valueColor: game.isWon ? .green : .red)
        }
    }

    func statCard(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Grid

    var gridView: some View {
        let cellSize: CGFloat = (UIScreen.main.bounds.width - 48) / 6

        return VStack(spacing: 2) {
            ForEach(0..<PipeConnectGame.gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<PipeConnectGame.gridSize, id: \.self) { col in
                        PipeConnectTileView(
                            tile: game.grid[row][col],
                            isConnected: game.grid[row][col].isConnected,
                            isSource: row == game.sourcePos.row && col == game.sourcePos.col,
                            isSink: row == game.sinkPos.row && col == game.sinkPos.col,
                            size: cellSize,
                            extraRotation: rotationAngles[row][col]
                        )
                        .onTapGesture {
                            handleTap(row: row, col: col)
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Win Overlay

    var winOverlayView: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Connected!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Solved in \(game.moves) moves & \(timeString(elapsedSeconds))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                if roundScores.count > 0 {
                    VStack(spacing: 6) {
                        Text("Recent Scores")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.7))
                        Text(roundScores.map { "\($0)" }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        if roundScores.count > 1 {
                            Text("Avg: \(movingAverage)")
                                .font(.caption.bold())
                                .foregroundColor(.cyan.opacity(0.9))
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button(action: { nextRound() }) {
                        Text("Next Round")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.7))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }

                    Button(action: { restartGame() }) {
                        Text("Restart")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .background(.ultraThinMaterial, in: Capsule())
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(32)
        }
    }

    // MARK: - Helpers

    var movingAverage: String {
        guard !roundScores.isEmpty else { return "0" }
        let avg = roundScores.reduce(0, +) / roundScores.count
        return "\(avg)"
    }

    func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Game Logic

    func startGame() {
        game.loadLayout(index: currentLayoutIndex)
        rotationAngles = Array(repeating: Array(repeating: 0.0, count: 6), count: 6)
        startTime = Date()
        elapsedSeconds = 0
        showWinOverlay = false
        startTimer()
    }

    func restartGame() {
        stopTimer()
        startGame()
    }

    func nextRound() {
        stopTimer()
        currentLayoutIndex = (currentLayoutIndex + 1) % 3
        startGame()
    }

    func startTimer() {
        stopTimer()
        timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            if !self.game.isWon {
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func handleTap(row: Int, col: Int) {
        guard !game.isWon else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            rotationAngles[row][col] += 90
        }
        game.tap(row: row, col: col)

        if game.isWon {
            stopTimer()
            let score = max(0, 200 - game.moves - elapsedSeconds)
            recordRoundEnd(score: score)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { showWinOverlay = true }
            }
        }
    }

    func recordRoundEnd(score: Int) {
        roundScores.append(score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adjustDifficulty()
    }

    func adjustDifficulty() {
        let solveTime = Double(elapsedSeconds)
        // Moving average of recent scores (time-based)
        let recentTimes = roundScores.suffix(3).map { Double($0) }
        let avgScore = recentTimes.reduce(0, +) / Double(max(1, recentTimes.count))

        // Use solve time for difficulty adjustment
        if solveTime < hardThreshold {
            difficulty = .hard
        } else if solveTime < easyThreshold {
            difficulty = .medium
        } else {
            difficulty = .easy
        }

        // Also factor moving average score:
        // High score fast = player is good -> harder
        // Low score slow  = player struggling -> easier
        let _ = avgScore  // used for tuning; current logic uses raw solve time

        // Select layout complexity based on difficulty
        switch difficulty {
        case .easy:
            currentLayoutIndex = 0
        case .medium:
            currentLayoutIndex = 1
        case .hard:
            currentLayoutIndex = 2
        }
    }
}

// MARK: - Tile View

struct PipeConnectTileView: View {
    let tile: PipeConnectTile
    let isConnected: Bool
    let isSource: Bool
    let isSink: Bool
    let size: CGFloat
    let extraRotation: Double

    var body: some View {
        ZStack {
            tileBackground

            PipeConnectPipeShape(openings: tile.openDirections)
                .stroke(pipeColor, style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round, lineJoin: .round))
                .padding(size * 0.05)
                .animation(.easeInOut(duration: 0.15), value: tile.rotation)

            if isSource || isSink {
                Circle()
                    .fill(isSource ? Color.blue.opacity(0.9) : Color.red.opacity(0.9))
                    .frame(width: size * 0.28, height: size * 0.28)
                    .shadow(color: (isSource ? Color.blue : Color.red).opacity(0.8), radius: 6)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    var tileBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                isConnected
                ? Color(red: 0.14, green: 0.22, blue: 0.38).opacity(0.9)
                : Color(red: 0.12, green: 0.13, blue: 0.20).opacity(0.9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isConnected
                        ? Color.cyan.opacity(0.35)
                        : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }

    var pipeColor: Color {
        if isSource { return .blue }
        if isSink   { return .red }
        return isConnected ? Color.cyan : Color(white: 0.45)
    }
}

// MARK: - Pipe Shape

struct PipeConnectPipeShape: Shape {
    let openings: Set<PipeConnectDirection>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        if openings.contains(.up)    { path.move(to: CGPoint(x: cx, y: cy)); path.addLine(to: CGPoint(x: cx, y: rect.minY)) }
        if openings.contains(.down)  { path.move(to: CGPoint(x: cx, y: cy)); path.addLine(to: CGPoint(x: cx, y: rect.maxY)) }
        if openings.contains(.left)  { path.move(to: CGPoint(x: cx, y: cy)); path.addLine(to: CGPoint(x: rect.minX, y: cy)) }
        if openings.contains(.right) { path.move(to: CGPoint(x: cx, y: cy)); path.addLine(to: CGPoint(x: rect.maxX, y: cy)) }
        return path
    }
}

