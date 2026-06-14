import SwiftUI

// MARK: - Models

enum CrHpPhase { case start, playing, over }

enum CrHpRowKind { case safe, road, river }

struct CrHpVehicle {
    var col: Double
    let direction: Int // +1 right, -1 left
    let speed: Double  // cols per second
}

struct CrHpLog {
    var col: Double
    let width: Int     // 2 or 3 columns wide
    let direction: Int
    let speed: Double
}

struct CrHpRow {
    let kind: CrHpRowKind
    var vehicles: [CrHpVehicle]
    var logs: [CrHpLog]
}

// MARK: - CrossyHopView

struct CrossyHopView: View {
    static let cols = 5
    static let rows = 9  // row 0 = safe bottom, rows 1-7 = traffic/river, row 8 = safe top

    @State private var phase: CrHpPhase = .start
    @State private var playerRow = 0
    @State private var playerCol = 2
    @State private var score = 0
    @State private var maxRow = 0
    @State private var grid: [CrHpRow] = []
    @State private var timer: Timer? = nil
    @State private var dragStart: CGPoint? = nil

    let cellSize: CGFloat = 52

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.2, blue: 0.13).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .playing: gameView
            case .over: overView
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: Start
    var startView: some View {
        VStack(spacing: 24) {
            Text("CrossyHop").font(.largeTitle.bold()).foregroundColor(.green)
            Text("Hop across traffic & rivers\nto reach the top!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
            Button("Start") { startGame() }
                .font(.title2.bold()).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.green).foregroundColor(.black).clipShape(Capsule())
        }
    }

    // MARK: Game
    var gameView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Score: \(score)").font(.title2.bold()).foregroundColor(.white)
                Spacer()
                Text("Best Row: \(maxRow)").foregroundColor(.green.opacity(0.8))
            }.padding(.horizontal)

            gridView
                .gesture(DragGesture(minimumDistance: 0)
                    .onEnded { handleDrag($0) })

            Text("Tap = hop forward  Swipe = move sideways").font(.caption).foregroundColor(.white.opacity(0.5)).padding(.bottom, 4)
        }
    }

    var gridView: some View {
        VStack(spacing: 2) {
            ForEach((0..<Self.rows).reversed(), id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<Self.cols, id: \.self) { c in
                        cellView(row: r, col: c)
                    }
                }
            }
        }
    }

    func cellView(row: Int, col: Int) -> some View {
        let rowData = grid[row]
        let isPlayer = (row == playerRow && col == playerCol)
        let bg: Color = {
            switch rowData.kind {
            case .safe: return Color(red: 0.2, green: 0.45, blue: 0.2)
            case .road: return Color(red: 0.25, green: 0.25, blue: 0.25)
            case .river: return Color(red: 0.1, green: 0.3, blue: 0.6)
            }
        }()
        let hasLog = rowData.logs.contains { log in
            let start = Int(log.col)
            return (start..<(start + log.width)).contains(col)
        }
        let hasCar = rowData.vehicles.contains { Int($0.col.rounded()) == col }

        return ZStack {
            bg.cornerRadius(4)
            if rowData.kind == .river && hasLog { Color.brown.opacity(0.7).cornerRadius(4) }
            if rowData.kind == .road && hasCar { Text("🚗").font(.system(size: cellSize * 0.55)) }
            if isPlayer { Text("🐸").font(.system(size: cellSize * 0.65)) }
        }
        .frame(width: cellSize, height: cellSize)
    }

    // MARK: Over
    var overView: some View {
        VStack(spacing: 20) {
            Text("Game Over").font(.largeTitle.bold()).foregroundColor(.red)
            Text("Score: \(score)").font(.title).foregroundColor(.white)
            Button("Play Again") { startGame() }
                .font(.title2.bold()).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.green).foregroundColor(.black).clipShape(Capsule())
            Button("Menu") { phase = .start; timer?.invalidate() }
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: Logic
    func startGame() {
        timer?.invalidate()
        playerRow = 0; playerCol = 2; score = 0; maxRow = 0
        grid = buildGrid()
        phase = .playing
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in tick() }
    }

    func buildGrid() -> [CrHpRow] {
        var rows: [CrHpRow] = []
        for i in 0..<Self.rows {
            if i == 0 || i == Self.rows - 1 {
                rows.append(CrHpRow(kind: .safe, vehicles: [], logs: []))
            } else if i % 2 == 1 {
                let dir = i % 4 == 1 ? 1 : -1
                let cars = (0..<2).map { j in CrHpVehicle(col: Double(j * 3), direction: dir, speed: 1.5 + Double(i) * 0.1) }
                rows.append(CrHpRow(kind: .road, vehicles: cars, logs: []))
            } else {
                let dir = i % 4 == 0 ? 1 : -1
                let logs = [CrHpLog(col: 0, width: 2, direction: dir, speed: 1.2), CrHpLog(col: 3, width: 2, direction: dir, speed: 1.2)]
                rows.append(CrHpRow(kind: .river, vehicles: [], logs: logs))
            }
        }
        return rows
    }

    func tick() {
        for i in 0..<grid.count {
            for j in 0..<grid[i].vehicles.count {
                grid[i].vehicles[j].col += Double(grid[i].vehicles[j].direction) * grid[i].vehicles[j].speed * 0.05
                let c = grid[i].vehicles[j].col
                if c > Double(Self.cols) { grid[i].vehicles[j].col = -1 }
                if c < -1 { grid[i].vehicles[j].col = Double(Self.cols) }
            }
            for j in 0..<grid[i].logs.count {
                grid[i].logs[j].col += Double(grid[i].logs[j].direction) * grid[i].logs[j].speed * 0.05
                let c = grid[i].logs[j].col
                let w = Double(grid[i].logs[j].width)
                if c > Double(Self.cols) { grid[i].logs[j].col = -w }
                if c < -w { grid[i].logs[j].col = Double(Self.cols) }
            }
        }
        checkCollision()
    }

    func checkCollision() {
        let row = grid[playerRow]
        if row.kind == .road {
            let hit = row.vehicles.contains { abs($0.col - Double(playerCol)) < 0.8 }
            if hit { endGame() }
        } else if row.kind == .river {
            let onLog = row.logs.contains { log in
                let start = log.col; let end = log.col + Double(log.width)
                return Double(playerCol) >= start - 0.3 && Double(playerCol) < end - 0.3
            }
            if !onLog { endGame() }
        }
    }

    func handleDrag(_ value: DragGesture.Value) {
        guard phase == .playing else { return }
        let dx = value.translation.width; let dy = value.translation.height
        if abs(dx) < 10 && abs(dy) < 10 { hopForward() }
        else if abs(dx) > abs(dy) { moveHorizontal(dx > 0 ? 1 : -1) }
    }

    func hopForward() {
        let newRow = min(playerRow + 1, Self.rows - 1)
        playerRow = newRow
        if newRow > maxRow { maxRow = newRow }
        if newRow == Self.rows - 1 { score += 1; playerRow = 0 }
    }

    func moveHorizontal(_ dir: Int) {
        playerCol = max(0, min(Self.cols - 1, playerCol + dir))
    }

    func endGame() {
        timer?.invalidate()
        phase = .over
    }
}

#Preview { CrossyHopView() }
