import SwiftUI

// MARK: - Models 

enum CrossyHopPhase { case start, playing, over }
enum CrossyHopRowKind { case safe, road, river }

struct CrossyHopVehicle {
    var col: Double
    let direction: Int
    var speed: Double
}

struct CrossyHopLog {
    var col: Double
    let width: Int
    let direction: Int
    var speed: Double
}

struct CrossyHopRow {
    let kind: CrossyHopRowKind
    var vehicles: [CrossyHopVehicle]
    var logs: [CrossyHopLog]
}

// MARK: - CrossyHopView

struct CrossyHopView: View {
    static let cols = 5
    static let rows = 9

    @State private var phase: CrossyHopPhase = .start
    @State private var playerRow = 0
    @State private var playerCol = 2
    @State private var score = 0
    @State private var grid: [CrossyHopRow] = []
    @State private var gameTimer: Timer? = nil

    // Adaptive difficulty
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    let cellSize: CGFloat = 50
    let accent = Color(red: 0.4, green: 0.9, blue: 0.6)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .playing: gameView
            case .over: overView
            }
        }
        .onDisappear { gameTimer?.invalidate() }
    }

    // MARK: Start
    var startView: some View {
        VStack(spacing: 28) {
            Text("CrossyHop").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Hop across traffic & rivers").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            if speedMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0f%%", speedMultiplier * 100))").font(.caption).foregroundColor(accent)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.ultraThinMaterial).clipShape(Capsule())
            }
            Button("Start Game") { startGame() }
                .font(.title2.bold()).padding(.horizontal, 44).padding(.vertical, 16)
                .background(accent).foregroundColor(.black).clipShape(Capsule())
                .shadow(color: accent.opacity(0.5), radius: 12)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: Game
    var gameView: some View {
        VStack(spacing: 10) {
            HStack {
                scorePanel
                Spacer()
                difficultyBadge
            }.padding(.horizontal)

            gridView
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)
                .gesture(DragGesture(minimumDistance: 0).onEnded { handleDrag($0) })

            Text("Tap = hop   Swipe = move").font(.caption).foregroundColor(.white.opacity(0.4))
        }
    }

    var scorePanel: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill").foregroundColor(.yellow)
            Text("\(score)").font(.title2.bold()).foregroundColor(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var difficultyBadge: some View {
        Text("x\(String(format: "%.1f", speedMultiplier))")
            .font(.caption.bold()).foregroundColor(speedMultiplier > 1.0 ? .orange : .white.opacity(0.6))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
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
            case .safe: return Color(red: 0.15, green: 0.5, blue: 0.25).opacity(0.6)
            case .road: return Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.7)
            case .river: return Color(red: 0.1, green: 0.25, blue: 0.55).opacity(0.7)
            }
        }()
        let hasLog = rowData.logs.contains { log in
            let s = Int(log.col); return (s..<(s + log.width)).contains(col)
        }
        let hasCar = rowData.vehicles.contains { abs($0.col - Double(col)) < 0.9 }

        return ZStack {
            bg.cornerRadius(4)
            if rowData.kind == .river && hasLog {
                Color.brown.opacity(0.5).cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.brown.opacity(0.4), lineWidth: 1))
            }
            if rowData.kind == .road && hasCar { Text("🚗").font(.system(size: cellSize * 0.5)) }
            if isPlayer { Text("🐸").font(.system(size: cellSize * 0.6)) }
        }
        .frame(width: cellSize, height: cellSize)
    }

    // MARK: Over
    var overView: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text("Score: \(score)").font(.title.bold()).foregroundColor(accent)
            if speedMultiplier > 1.0 {
                Text("Difficulty bonus active!").font(.caption).foregroundColor(.orange)
            }
            Button("Play Again") { startGame() }
                .font(.title2.bold()).padding(.horizontal, 40).padding(.vertical, 14)
                .background(accent).foregroundColor(.black).clipShape(Capsule())
                .shadow(color: accent.opacity(0.4), radius: 10)
            Button("Menu") { phase = .start; gameTimer?.invalidate() }
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: Logic
    func startGame() {
        gameTimer?.invalidate()
        playerRow = 0; playerCol = 2; score = 0
        grid = buildGrid()
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in tick() }
    }

    func buildGrid() -> [CrossyHopRow] {
        var result: [CrossyHopRow] = []
        for i in 0..<Self.rows {
            if i == 0 || i == Self.rows - 1 {
                result.append(CrossyHopRow(kind: .safe, vehicles: [], logs: []))
            } else if i % 2 == 1 {
                let dir = i % 4 == 1 ? 1 : -1
                let base = 1.5 * speedMultiplier
                let cars = (0..<2).map { j in CrossyHopVehicle(col: Double(j * 3), direction: dir, speed: base + Double(i) * 0.08) }
                result.append(CrossyHopRow(kind: .road, vehicles: cars, logs: []))
            } else {
                let dir = i % 4 == 0 ? 1 : -1
                let base = 1.2 * speedMultiplier
                let logs = [CrossyHopLog(col: 0, width: 2, direction: dir, speed: base), CrossyHopLog(col: 3, width: 2, direction: dir, speed: base)]
                result.append(CrossyHopRow(kind: .river, vehicles: [], logs: logs))
            }
        }
        return result
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
                let c = grid[i].logs[j].col; let w = Double(grid[i].logs[j].width)
                if c > Double(Self.cols) { grid[i].logs[j].col = -w }
                if c < -w { grid[i].logs[j].col = Double(Self.cols) }
            }
        }
        checkCollision()
    }

    func checkCollision() {
        let row = grid[playerRow]
        if row.kind == .road {
            if row.vehicles.contains(where: { abs($0.col - Double(playerCol)) < 0.8 }) { endGame(survived: false) }
        } else if row.kind == .river {
            let onLog = row.logs.contains { log in
                Double(playerCol) >= log.col - 0.3 && Double(playerCol) < log.col + Double(log.width) - 0.3
            }
            if !onLog { endGame(survived: false) }
        }
    }

    func handleDrag(_ value: DragGesture.Value) {
        guard phase == .playing else { return }
        let dx = value.translation.width; let dy = value.translation.height
        if abs(dx) < 10 && abs(dy) < 10 { hopForward() }
        else if abs(dx) > abs(dy) { playerCol = max(0, min(Self.cols - 1, playerCol + (dx > 0 ? 1 : -1))) }
    }

    func hopForward() {
        let newRow = min(playerRow + 1, Self.rows - 1)
        playerRow = newRow
        if newRow == Self.rows - 1 {
            score += 1
            endGame(survived: true)
        }
    }

    func endGame(survived: Bool) {
        gameTimer?.invalidate()
        recentResults.append(survived)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
        }
        if survived {
            playerRow = 0
            grid = buildGrid()
            gameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in tick() }
        } else {
            phase = .over
        }
    }
}

#Preview { CrossyHopView() }
