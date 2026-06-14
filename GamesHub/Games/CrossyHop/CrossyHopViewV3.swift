import SwiftUI

// MARK: - LCG Seeded RNG

struct CrHpLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models V3

enum CrHpV3Phase { case start, playing, over }
enum CrHpV3RowKind { case safe, road, river }

struct CrHpV3Vehicle {
    var col: Double
    let direction: Int
    let speed: Double
}

struct CrHpV3Log {
    var col: Double
    let width: Int
    let direction: Int
    let speed: Double
}

struct CrHpV3Row {
    let kind: CrHpV3RowKind
    var vehicles: [CrHpV3Vehicle]
    var logs: [CrHpV3Log]
}

// MARK: - CrossyHopViewV3

struct CrossyHopViewV3: View {
    static let cols = 5
    static let rows = 9

    @State private var phase: CrHpV3Phase = .start
    @State private var playerRow = 0
    @State private var playerCol = 2
    @State private var score = 0
    @State private var grid: [CrHpV3Row] = []
    @State private var gameTimer: Timer? = nil
    @State private var seedInt: Int = 1

    let cellSize: CGFloat = 50
    let shadowColor = Color.black.opacity(0.25)

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
            Text("CrossyHop")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))

            Text("Hop across traffic & rivers\nto reach the top!")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))

            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button("Start Game") { startGame() }
                .font(.title2.bold())
                .padding(.horizontal, 44).padding(.vertical, 16)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: shadowColor, radius: 6, x: 3, y: 3)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: Game
    var gameView: some View {
        VStack(spacing: 12) {
            HStack {
                scoreCard
                Spacer()
                seedLabel
            }.padding(.horizontal)

            gridView
                .padding(10)
                .neumorphicCard(radius: 18)
                .padding(.horizontal)
                .gesture(DragGesture(minimumDistance: 0).onEnded { handleDrag($0) })

            Text("Tap = hop forward   Swipe = move sideways")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
    }

    var scoreCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill").foregroundColor(.yellow)
            Text("Score: \(score)").font(.headline).foregroundColor(Color(.label))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .neumorphicCard(radius: 12)
    }

    var seedLabel: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(Color(.tertiaryLabel))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            case .safe:  return Color(red: 0.75, green: 0.88, blue: 0.72)
            case .road:  return Color(red: 0.72, green: 0.72, blue: 0.75)
            case .river: return Color(red: 0.65, green: 0.78, blue: 0.92)
            }
        }()
        let hasLog = rowData.logs.contains { log in
            let s = Int(log.col); return (s..<(s + log.width)).contains(col)
        }
        let hasCar = rowData.vehicles.contains { abs($0.col - Double(col)) < 0.9 }

        return ZStack {
            bg.cornerRadius(5)
                .shadow(color: Color.white.opacity(0.8), radius: 2, x: -1, y: -1)
                .shadow(color: shadowColor, radius: 2, x: 1, y: 1)
            if rowData.kind == .river && hasLog {
                Color(red: 0.58, green: 0.42, blue: 0.28).opacity(0.85).cornerRadius(5)
            }
            if rowData.kind == .road && hasCar { Text("🚗").font(.system(size: cellSize * 0.5)) }
            if isPlayer { Text("🐸").font(.system(size: cellSize * 0.6)) }
        }
        .frame(width: cellSize, height: cellSize)
    }

    // MARK: Over
    var overView: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))

            Text("Score: \(score)")
                .font(.title.bold())
                .foregroundColor(.green)

            Text("SEED: #\(seedInt - 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button("Play Again") { startGame() }
                .font(.title2.bold())
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: shadowColor, radius: 6, x: 3, y: 3)

            Button("Menu") { phase = .start; gameTimer?.invalidate() }
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: Logic
    func startGame() {
        gameTimer?.invalidate()
        playerRow = 0; playerCol = 2; score = 0
        grid = buildGrid(seed: seedInt)
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in tick() }
    }

    func buildGrid(seed: Int) -> [CrHpV3Row] {
        var rng = CrHpLCG(seed: seed)
        var result: [CrHpV3Row] = []
        for i in 0..<Self.rows {
            if i == 0 || i == Self.rows - 1 {
                result.append(CrHpV3Row(kind: .safe, vehicles: [], logs: []))
            } else if i % 2 == 1 {
                let dir = rng.nextInt(2) == 0 ? 1 : -1
                let numCars = 1 + rng.nextInt(2)
                var cars: [CrHpV3Vehicle] = []
                for _ in 0..<numCars {
                    let startCol = Double(rng.nextInt(Self.cols))
                    let speed = 1.2 + rng.nextDouble() * 1.0
                    cars.append(CrHpV3Vehicle(col: startCol, direction: dir, speed: speed))
                }
                result.append(CrHpV3Row(kind: .road, vehicles: cars, logs: []))
            } else {
                let dir = rng.nextInt(2) == 0 ? 1 : -1
                let numLogs = 1 + rng.nextInt(2)
                var logs: [CrHpV3Log] = []
                var pos = 0.0
                for _ in 0..<numLogs {
                    let w = 2 + rng.nextInt(2)
                    let speed = 1.0 + rng.nextDouble() * 0.8
                    logs.append(CrHpV3Log(col: pos, width: w, direction: dir, speed: speed))
                    pos += Double(w) + Double(1 + rng.nextInt(2))
                }
                result.append(CrHpV3Row(kind: .river, vehicles: [], logs: logs))
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
            if row.vehicles.contains(where: { abs($0.col - Double(playerCol)) < 0.8 }) { endGame() }
        } else if row.kind == .river {
            let onLog = row.logs.contains { log in
                Double(playerCol) >= log.col - 0.3 && Double(playerCol) < log.col + Double(log.width) - 0.3
            }
            if !onLog { endGame() }
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
            playerRow = 0
        }
    }

    func endGame() {
        gameTimer?.invalidate()
        seedInt += 1
        phase = .over
    }
}

#Preview { CrossyHopViewV3() }
