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
        updateConnections()
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

// MARK: - Pipe Shape Drawing

struct PipeConnectPipeShape: View {
    let tile: PipeConnectTile
    let cellSize: CGFloat
    let isConnected: Bool

    private var pipeColor: Color {
        isConnected ? Color(red: 0.2, green: 0.7, blue: 1.0) : Color(red: 0.6, green: 0.6, blue: 0.65)
    }

    private var bgColor: Color {
        Color(red: 0.15, green: 0.15, blue: 0.2)
    }

    var body: some View {
        ZStack {
            bgColor

            switch tile.type {
            case .source:
                sourceShape
            case .sink:
                sinkShape
            case .straight:
                straightPipe
                    .rotationEffect(.degrees(Double(tile.rotation) * 90))
            case .elbow:
                elbowPipe
                    .rotationEffect(.degrees(Double(tile.rotation) * 90))
            case .tJunction:
                tJunctionPipe
                    .rotationEffect(.degrees(Double(tile.rotation) * 90))
            case .empty:
                Color.clear
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // Straight pipe: vertical channel
    private var straightPipe: some View {
        let w = cellSize * 0.3
        return ZStack {
            // Vertical bar
            Rectangle()
                .fill(pipeColor)
                .frame(width: w, height: cellSize)
            // Highlights
            Rectangle()
                .fill(pipeColor.opacity(0.4))
                .frame(width: w * 0.3, height: cellSize)
                .offset(x: -w * 0.25)
        }
    }

    // Elbow: up + right curve
    private var elbowPipe: some View {
        let w = cellSize * 0.3
        let half = cellSize / 2
        return ZStack {
            // Vertical segment (top half)
            Rectangle()
                .fill(pipeColor)
                .frame(width: w, height: half + w / 2)
                .offset(y: -half / 2 + w / 4)
            // Horizontal segment (right half)
            Rectangle()
                .fill(pipeColor)
                .frame(width: half + w / 2, height: w)
                .offset(x: half / 2 - w / 4)
            // Corner fill
            Rectangle()
                .fill(pipeColor)
                .frame(width: w, height: w)
                .offset(x: w / 2 - w / 2, y: w / 2 - w / 2)  // center overlap
        }
    }

    // T-junction: up + down + right
    private var tJunctionPipe: some View {
        let w = cellSize * 0.3
        let half = cellSize / 2
        return ZStack {
            // Vertical bar
            Rectangle()
                .fill(pipeColor)
                .frame(width: w, height: cellSize)
            // Horizontal right segment
            Rectangle()
                .fill(pipeColor)
                .frame(width: half + w / 2, height: w)
                .offset(x: half / 2 - w / 4)
        }
    }

    // Source: blue circle with dot
    private var sourceShape: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.1, green: 0.4, blue: 0.9))
                .padding(cellSize * 0.15)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: cellSize * 0.25, height: cellSize * 0.25)
            // Open all 4 sides
            allSideConnectors(color: Color(red: 0.2, green: 0.5, blue: 1.0))
        }
    }

    // Sink: red circle with dot
    private var sinkShape: some View {
        ZStack {
            Circle()
                .fill(isConnected ? Color(red: 0.9, green: 0.2, blue: 0.2) : Color(red: 0.5, green: 0.15, blue: 0.15))
                .padding(cellSize * 0.15)
            Circle()
                .fill(Color.white.opacity(isConnected ? 0.9 : 0.4))
                .frame(width: cellSize * 0.25, height: cellSize * 0.25)
            allSideConnectors(color: isConnected ? Color(red: 1.0, green: 0.3, blue: 0.3) : Color(red: 0.5, green: 0.2, blue: 0.2))
        }
    }

    private func allSideConnectors(color: Color) -> some View {
        let w = cellSize * 0.28
        let h = cellSize * 0.22
        return ZStack {
            Rectangle().fill(color).frame(width: w, height: h).offset(y: -(cellSize / 2 - h / 2))
            Rectangle().fill(color).frame(width: w, height: h).offset(y:  (cellSize / 2 - h / 2))
            Rectangle().fill(color).frame(width: h, height: w).offset(x: -(cellSize / 2 - h / 2))
            Rectangle().fill(color).frame(width: h, height: w).offset(x:  (cellSize / 2 - h / 2))
        }
    }
}

// MARK: - Grid View

struct PipeConnectGridView: View {
    @ObservedObject var game: PipeConnectGame
    let cellSize: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<PipeConnectGame.gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<PipeConnectGame.gridSize, id: \.self) { col in
                        PipeConnectCellView(
                            tile: game.grid[row][col],
                            cellSize: cellSize,
                            onTap: { game.tap(row: row, col: col) }
                        )
                    }
                }
            }
        }
        .padding(4)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PipeConnectCellView: View {
    let tile: PipeConnectTile
    let cellSize: CGFloat
    let onTap: () -> Void

    @State private var rotationAnimation: Double = 0

    var body: some View {
        PipeConnectPipeShape(tile: tile, cellSize: cellSize, isConnected: tile.isConnected)
            .rotationEffect(.degrees(rotationAnimation))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    rotationAnimation += 90
                }
                onTap()
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        tile.isConnected
                            ? Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.5)
                            : Color.white.opacity(0.05),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Status Bar

struct PipeConnectStatusView: View {
    let moves: Int
    let isWon: Bool

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("MOVES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(moves)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("STATUS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                HStack(spacing: 6) {
                    Circle()
                        .fill(isWon ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: isWon ? .green : .red, radius: 4)
                    Text(isWon ? "CONNECTED" : "OPEN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isWon ? .green : Color(red: 1, green: 0.4, blue: 0.4))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Win Overlay

struct PipeConnectWinOverlay: View {
    let moves: Int
    let onNextLayout: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("CONNECTED!")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green, radius: 12)

                VStack(spacing: 6) {
                    Text("Solved in")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(moves) moves")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                HStack(spacing: 16) {
                    Button(action: onRestart) {
                        Text("RETRY")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.2, green: 0.2, blue: 0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: onNextLayout) {
                        Text("NEXT")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(32)
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .green.opacity(0.3), radius: 30)
        }
    }
}

// MARK: - Main View

struct PipeConnectView: View {
    @StateObject private var game = PipeConnectGame()

    var body: some View {
        GeometryReader { geo in
            let isSmall = geo.size.width < 390
            let padding: CGFloat = isSmall ? 12 : 16
            let availableWidth = geo.size.width - padding * 2
            let gridSpacing: CGFloat = 2 * CGFloat(PipeConnectGame.gridSize - 1) + 8
            let cellSize = (availableWidth - gridSpacing) / CGFloat(PipeConnectGame.gridSize)

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.1, green: 0.08, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PIPE CONNECT")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Layout \(game.layoutIndex + 1) of 3")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { game.restart() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color(red: 0.2, green: 0.2, blue: 0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, padding)

                    // Legend
                    HStack(spacing: 20) {
                        PipeConnectLegendItem(color: Color(red: 0.1, green: 0.4, blue: 0.9), label: "SOURCE")
                        PipeConnectLegendItem(color: Color(red: 0.9, green: 0.2, blue: 0.2), label: "SINK")
                        PipeConnectLegendItem(color: Color(red: 0.2, green: 0.7, blue: 1.0), label: "CONNECTED")
                        PipeConnectLegendItem(color: Color(red: 0.5, green: 0.5, blue: 0.55), label: "OPEN")
                    }
                    .padding(.horizontal, padding)

                    // Status
                    PipeConnectStatusView(moves: game.moves, isWon: game.isWon)
                        .padding(.horizontal, padding)

                    // Grid
                    PipeConnectGridView(game: game, cellSize: cellSize)
                        .padding(.horizontal, padding)

                    // Hint
                    Text("TAP A PIPE TO ROTATE 90°")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))

                    // Layout selector
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            Button(action: { game.loadLayout(index: i) }) {
                                Text("L\(i+1)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(game.layoutIndex == i ? .black : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        game.layoutIndex == i
                                            ? Color(red: 0.2, green: 0.7, blue: 1.0)
                                            : Color(red: 0.2, green: 0.2, blue: 0.3)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 12)

                // Win overlay
                if game.isWon {
                    PipeConnectWinOverlay(
                        moves: game.moves,
                        onNextLayout: { game.nextLayout() },
                        onRestart: { game.restart() }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: game.isWon)
                }
            }
        }
    }
}

struct PipeConnectLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
