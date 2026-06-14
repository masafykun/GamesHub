import SwiftUI

// MARK: - LCG Seeded RNG

struct MgBLCG {
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

enum MgBV3MagnetType { case attractive, repulsive }

struct MgBV3Magnet: Identifiable {
    let id = UUID()
    var gridCol: Int
    var gridRow: Int
    var type: MgBV3MagnetType
}

struct MgBV3Level {
    let cols: Int
    let rows: Int
    let coins: [CGPoint]
    let exit: CGPoint
    let ballStart: CGPoint
    let seed: Int
}

enum MgBV3Phase { case start, playing, won, lost }

// MARK: - MagnetBallViewV3

struct MagnetBallViewV3: View {

    @State private var seedInt: Int = 1
    @State private var phase: MgBV3Phase = .start
    @State private var levelIndex: Int = 0
    @State private var currentLevel: MgBV3Level = MgBV3Level(cols: 6, rows: 8, coins: [], exit: CGPoint(x:5,y:7), ballStart: CGPoint(x:0,y:0), seed: 1)
    @State private var magnets: [MgBV3Magnet] = []
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var collectedCoins: Set<Int> = []
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var boardSize: CGSize = .zero
    @State private var totalLevels: Int = 4

    var cellW: CGFloat { boardSize.width / CGFloat(currentLevel.cols) }
    var cellH: CGFloat { boardSize.height / CGFloat(currentLevel.rows) }

    func cellCenter(_ c: Int, _ r: Int, _ size: CGSize) -> CGPoint {
        let cw = size.width / CGFloat(currentLevel.cols)
        let ch = size.height / CGFloat(currentLevel.rows)
        return CGPoint(x: CGFloat(c) * cw + cw / 2, y: CGFloat(r) * ch + ch / 2)
    }

    // MARK: Procedural Level Generation

    func generateLevel(seed: Int, index: Int) -> MgBV3Level {
        var rng = MgBLCG(seed: seed &+ index &* 31337)
        let cols = 5 + rng.nextInt(3)
        let rows = 7 + rng.nextInt(3)
        let numCoins = 2 + rng.nextInt(3)
        var coins: [CGPoint] = []
        var occupied: Set<String> = []
        // Ball start corner
        let startCorner = rng.nextInt(4)
        let bx = startCorner < 2 ? 0 : cols - 1
        let by = startCorner % 2 == 0 ? 0 : rows - 1
        occupied.insert("\(bx),\(by)")
        // Exit — opposite region
        var ex: Int; var ey: Int
        repeat {
            ex = rng.nextInt(cols)
            ey = rng.nextInt(rows)
        } while occupied.contains("\(ex),\(ey)") || (abs(ex - bx) + abs(ey - by)) < (cols + rows) / 2
        occupied.insert("\(ex),\(ey)")
        // Coins scattered
        var tries = 0
        while coins.count < numCoins && tries < 100 {
            let cx = rng.nextInt(cols)
            let cy = rng.nextInt(rows)
            if !occupied.contains("\(cx),\(cy)") {
                coins.append(CGPoint(x: cx, y: cy))
                occupied.insert("\(cx),\(cy)")
            }
            tries += 1
        }
        return MgBV3Level(cols: cols, rows: rows, coins: coins,
                          exit: CGPoint(x: ex, y: ey),
                          ballStart: CGPoint(x: bx, y: by),
                          seed: seed)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: resultScreen(won: true)
            case .lost: resultScreen(won: false)
            }
        }
    }

    // MARK: Start Screen

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("MagnetBall")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))
                Text("Place magnets to guide the ball.\nBlue = attract   Red = repel\nCollect coins, reach the star!")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(24)
            .neumorphicCard(radius: 20)

            Button("Start Game") { beginGame() }
                .font(.title3.bold())
                .foregroundColor(Color(.label))
                .padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 30)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding()
    }

    // MARK: Game Screen

    var gameScreen: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Level \(levelIndex+1)/\(totalLevels)")
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
                Text("Score: \(score)")
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
            }
            .padding(.horizontal)
            .padding(10)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack {
                    // Grid cells
                    ForEach(0..<currentLevel.rows, id: \.self) { r in
                        ForEach(0..<currentLevel.cols, id: \.self) { c in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .shadow(color: .white.opacity(0.8), radius: 2, x: -1, y: -1)
                                .shadow(color: Color(.systemGray3).opacity(0.6), radius: 2, x: 1, y: 1)
                                .frame(width: cellW - 3, height: cellH - 3)
                                .position(cellCenter(c, r, geo.size))
                        }
                    }
                    // Coins
                    ForEach(Array(currentLevel.coins.enumerated()), id: \.offset) { idx, coin in
                        if !collectedCoins.contains(idx) {
                            Circle()
                                .fill(Color.yellow)
                                .shadow(color: .orange.opacity(0.5), radius: 4)
                                .frame(width: cellW * 0.42, height: cellH * 0.42)
                                .position(cellCenter(Int(coin.x), Int(coin.y), geo.size))
                        }
                    }
                    // Exit
                    Image(systemName: "star.fill")
                        .foregroundColor(.green)
                        .font(.system(size: cellW * 0.55))
                        .shadow(color: .green.opacity(0.5), radius: 5)
                        .position(cellCenter(Int(currentLevel.exit.x), Int(currentLevel.exit.y), geo.size))
                    // Magnets
                    ForEach(magnets) { m in
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .shadow(color: .white.opacity(0.9), radius: 3, x: -2, y: -2)
                                .shadow(color: Color(.systemGray3), radius: 3, x: 2, y: 2)
                                .frame(width: cellW * 0.7, height: cellH * 0.7)
                            Circle()
                                .fill(m.type == .attractive ? Color.blue.opacity(0.7) : Color.red.opacity(0.7))
                                .frame(width: cellW * 0.5, height: cellH * 0.5)
                            Text(m.type == .attractive ? "+" : "−")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .position(cellCenter(m.gridCol, m.gridRow, geo.size))
                    }
                    // Ball
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .shadow(color: .white.opacity(0.9), radius: 5, x: -3, y: -3)
                            .shadow(color: Color(.systemGray3), radius: 5, x: 3, y: 3)
                            .frame(width: cellW * 0.58, height: cellH * 0.58)
                        Circle()
                            .fill(Color(.systemGray2))
                            .frame(width: cellW * 0.38, height: cellH * 0.38)
                    }
                    .position(x: ballPos.x * cellW + cellW / 2,
                              y: ballPos.y * cellH + cellH / 2)
                }
                .contentShape(Rectangle())
                .onTapGesture { loc in
                    tapCell(Int(loc.x / cellW), Int(loc.y / cellH))
                }
                .onAppear {
                    boardSize = geo.size
                    resetBall()
                }
            }

            HStack {
                Button("Restart") { restartLevel() }
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .neumorphicCard(radius: 12)
                Spacer()
                Button("Menu") { phase = .start; gameTimer?.invalidate() }
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .neumorphicCard(radius: 12)
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }

    func resultScreen(won: Bool) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text(won ? "Level Clear!" : "Try Again")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))
                Text("Score: \(score)").font(.title3).foregroundColor(Color(.secondaryLabel))
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(26)
            .neumorphicCard(radius: 20)

            HStack(spacing: 14) {
                if won && levelIndex + 1 < totalLevels {
                    Button("Next Level") { nextLevel() }
                        .font(.callout.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .neumorphicCard(radius: 12)
                }
                Button("Restart") { restartLevel() }
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .neumorphicCard(radius: 12)
                Button("Menu") { phase = .start }
                    .font(.callout.bold())
                    .foregroundColor(Color(.secondaryLabel))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .neumorphicCard(radius: 12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: Game Logic

    func beginGame() {
        levelIndex = 0
        score = 0
        currentLevel = generateLevel(seed: seedInt, index: 0)
        startPlaying()
    }

    func nextLevel() {
        levelIndex += 1
        currentLevel = generateLevel(seed: seedInt, index: levelIndex)
        startPlaying()
    }

    func restartLevel() {
        seedInt += 1
        currentLevel = generateLevel(seed: seedInt, index: levelIndex)
        startPlaying()
    }

    func startPlaying() {
        gameTimer?.invalidate()
        magnets = []
        collectedCoins = []
        phase = .playing
        if boardSize == .zero { boardSize = CGSize(width: 300, height: 420) }
        resetBall()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in update() }
    }

    func resetBall() {
        ballPos = CGPoint(x: currentLevel.ballStart.x, y: currentLevel.ballStart.y)
        var rng = MgBLCG(seed: seedInt)
        let vx = (rng.nextDouble() * 0.06 + 0.02) * (rng.nextInt(2) == 0 ? 1 : -1)
        let vy = (rng.nextDouble() * 0.06 + 0.02) * (rng.nextInt(2) == 0 ? 1 : -1)
        ballVel = CGPoint(x: vx, y: vy)
    }

    func tapCell(_ c: Int, _ r: Int) {
        guard c >= 0 && c < currentLevel.cols && r >= 0 && r < currentLevel.rows else { return }
        if let idx = magnets.firstIndex(where: { $0.gridCol == c && $0.gridRow == r }) {
            if magnets[idx].type == .attractive { magnets[idx].type = .repulsive }
            else { magnets.remove(at: idx) }
        } else {
            magnets.append(MgBV3Magnet(gridCol: c, gridRow: r, type: .attractive))
        }
    }

    func update() {
        guard phase == .playing else { return }
        let k: CGFloat = 0.3
        let dt: CGFloat = 0.016
        var ax: CGFloat = 0; var ay: CGFloat = 0
        for m in magnets {
            let mx = CGFloat(m.gridCol) + 0.5
            let my = CGFloat(m.gridRow) + 0.5
            let dx = mx - (ballPos.x + 0.5)
            let dy = my - (ballPos.y + 0.5)
            let r2 = max(dx*dx + dy*dy, 0.1)
            let r = sqrt(r2)
            let f = k / r2
            let sign: CGFloat = m.type == .attractive ? 1 : -1
            ax += sign * f * dx / r
            ay += sign * f * dy / r
        }
        ballVel.x = (ballVel.x + ax * dt) * 0.9995
        ballVel.y = (ballVel.y + ay * dt) * 0.9995
        let maxV: CGFloat = 4.0
        let spd = sqrt(ballVel.x*ballVel.x + ballVel.y*ballVel.y)
        if spd > maxV { ballVel.x = ballVel.x/spd*maxV; ballVel.y = ballVel.y/spd*maxV }
        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt
        if ballPos.x < 0 { ballPos.x = 0; ballVel.x = abs(ballVel.x) }
        if ballPos.y < 0 { ballPos.y = 0; ballVel.y = abs(ballVel.y) }
        if ballPos.x > CGFloat(currentLevel.cols) - 1 { ballPos.x = CGFloat(currentLevel.cols)-1; ballVel.x = -abs(ballVel.x) }
        if ballPos.y > CGFloat(currentLevel.rows) - 1 { ballPos.y = CGFloat(currentLevel.rows)-1; ballVel.y = -abs(ballVel.y) }
        // Coins
        for (idx, coin) in currentLevel.coins.enumerated() {
            if !collectedCoins.contains(idx) {
                let dx = (ballPos.x + 0.5) - (coin.x + 0.5)
                let dy = (ballPos.y + 0.5) - (coin.y + 0.5)
                if dx*dx + dy*dy < 0.45 { collectedCoins.insert(idx); score += 10 }
            }
        }
        // Exit
        let ex = currentLevel.exit.x; let ey = currentLevel.exit.y
        let dx = (ballPos.x + 0.5) - (ex + 0.5)
        let dy = (ballPos.y + 0.5) - (ey + 0.5)
        if dx*dx + dy*dy < 0.45 {
            score += 50 + collectedCoins.count * 10
            gameTimer?.invalidate()
            phase = .won
        }
    }
}

#Preview { MagnetBallViewV3() }
