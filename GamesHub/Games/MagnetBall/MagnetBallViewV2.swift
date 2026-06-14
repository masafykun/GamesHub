import SwiftUI

// MARK: - Models V2

enum MgBV2MagnetType { case attractive, repulsive }

struct MgBV2Magnet: Identifiable {
    let id = UUID()
    var gridCol: Int
    var gridRow: Int
    var type: MgBV2MagnetType
}

struct MgBV2Level {
    let cols: Int
    let rows: Int
    let coins: [CGPoint]
    let exit: CGPoint
    let ballStart: CGPoint
}

enum MgBV2Phase { case start, playing, won, lost }

// MARK: - MagnetBallViewV2

struct MagnetBallViewV2: View {

    static let levels: [MgBV2Level] = [
        MgBV2Level(cols: 6, rows: 8, coins: [CGPoint(x:2,y:2),CGPoint(x:4,y:5)], exit: CGPoint(x:5,y:7), ballStart: CGPoint(x:0,y:0)),
        MgBV2Level(cols: 6, rows: 8, coins: [CGPoint(x:1,y:3),CGPoint(x:3,y:1),CGPoint(x:5,y:4)], exit: CGPoint(x:5,y:7), ballStart: CGPoint(x:0,y:7)),
        MgBV2Level(cols: 7, rows: 9, coins: [CGPoint(x:2,y:2),CGPoint(x:4,y:4),CGPoint(x:6,y:6)], exit: CGPoint(x:6,y:8), ballStart: CGPoint(x:0,y:0)),
        MgBV2Level(cols: 7, rows: 9, coins: [CGPoint(x:1,y:1),CGPoint(x:3,y:3),CGPoint(x:5,y:5),CGPoint(x:6,y:2)], exit: CGPoint(x:6,y:8), ballStart: CGPoint(x:0,y:8)),
    ]

    @State private var phase: MgBV2Phase = .start
    @State private var levelIndex: Int = 0
    @State private var magnets: [MgBV2Magnet] = []
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var collectedCoins: Set<Int> = []
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var boardSize: CGSize = .zero
    @State private var recentResults: [Bool] = []
    @State private var difficultyMult: Double = 1.0

    var level: MgBV2Level { Self.levels[levelIndex] }
    var cellW: CGFloat { boardSize.width / CGFloat(level.cols) }
    var cellH: CGFloat { boardSize.height / CGFloat(level.rows) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: resultScreen(won: true)
            case .lost: resultScreen(won: false)
            }
        }
        .foregroundColor(.white)
    }

    // MARK: Start Screen

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("MagnetBall").font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Tap grid to place magnets.\nBlue pulls, Red pushes.\nCollect coins, reach the star!").font(.subheadline)
                    .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 24)

            Button("Start Game") { startLevel(0) }
                .font(.title3.bold())
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: Game Screen

    var gameScreen: some View {
        VStack(spacing: 10) {
            HStack {
                infoChip("Level \(levelIndex+1)/\(Self.levels.count)")
                Spacer()
                if difficultyMult > 1.05 {
                    infoChip("Speed x\(String(format: "%.1f", difficultyMult))")
                        .foregroundColor(.orange)
                }
                Spacer()
                infoChip("Score: \(score)")
            }.padding(.horizontal)

            GeometryReader { geo in
                ZStack {
                    // Grid
                    ForEach(0..<level.rows, id: \.self) { r in
                        ForEach(0..<level.cols, id: \.self) { c in
                            Rectangle()
                                .stroke(.white.opacity(0.12), lineWidth: 0.5)
                                .frame(width: cellW, height: cellH)
                                .position(cellCenter(c, r, geo.size))
                        }
                    }
                    // Coins
                    ForEach(Array(level.coins.enumerated()), id: \.offset) { idx, coin in
                        if !collectedCoins.contains(idx) {
                            Circle()
                                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                                .frame(width: cellW * 0.45, height: cellH * 0.45)
                                .shadow(color: .yellow.opacity(0.6), radius: 6)
                                .position(cellCenter(Int(coin.x), Int(coin.y), geo.size))
                        }
                    }
                    // Exit star
                    Image(systemName: "star.fill")
                        .foregroundStyle(LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom))
                        .font(.system(size: cellW * 0.6))
                        .shadow(color: .green.opacity(0.8), radius: 8)
                        .position(cellCenter(Int(level.exit.x), Int(level.exit.y), geo.size))
                    // Magnets
                    ForEach(magnets) { m in
                        ZStack {
                            Circle()
                                .fill(m.type == .attractive ?
                                      LinearGradient(colors: [.blue, Color(red:0.2,green:0.4,blue:1)], startPoint: .top, endPoint: .bottom) :
                                      LinearGradient(colors: [.red, Color(red:1,green:0.3,blue:0.2)], startPoint: .top, endPoint: .bottom))
                                .frame(width: cellW * 0.72, height: cellH * 0.72)
                            Text(m.type == .attractive ? "+" : "−").font(.caption.bold()).foregroundColor(.white)
                        }
                        .shadow(color: m.type == .attractive ? .blue.opacity(0.7) : .red.opacity(0.7), radius: 6)
                        .position(cellCenter(m.gridCol, m.gridRow, geo.size))
                    }
                    // Ball
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color(white: 0.7)], center: .topLeading, startRadius: 0, endRadius: cellW * 0.3))
                        .frame(width: cellW * 0.55, height: cellH * 0.55)
                        .shadow(color: .white.opacity(0.9), radius: 8)
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
                Button("Restart") { startLevel(levelIndex) }
                    .font(.callout.bold())
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                Spacer()
                Button("Menu") { phase = .start; gameTimer?.invalidate() }
                    .font(.callout.bold())
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }.padding(.horizontal)
        }.padding(.top)
    }

    func infoChip(_ text: String) -> some View {
        Text(text).font(.callout.bold())
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func resultScreen(won: Bool) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text(won ? "Level Complete!" : "Try Again").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Score: \(score)").font(.title3)
                if difficultyMult > 1.05 {
                    Text("Difficulty: x\(String(format: "%.1f", difficultyMult))").font(.callout).foregroundColor(.orange)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            HStack(spacing: 12) {
                if won && levelIndex + 1 < Self.levels.count {
                    Button("Next Level") {
                        recentResults.append(true)
                        updateDifficulty()
                        startLevel(levelIndex + 1)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.green.opacity(0.6), lineWidth: 1))
                }
                Button("Restart") {
                    recentResults.append(false)
                    startLevel(levelIndex)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))

                Button("Menu") { phase = .start }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }.padding(.horizontal)
    }

    // MARK: Adaptive Difficulty

    func updateDifficulty() {
        let last5 = Array(recentResults.suffix(5))
        let wins = last5.filter { $0 }.count
        if last5.count == 5 && wins > 4 {
            difficultyMult = min(difficultyMult * 1.2, 3.0)
        }
    }

    // MARK: Helpers

    func cellCenter(_ c: Int, _ r: Int, _ size: CGSize) -> CGPoint {
        let cw = size.width / CGFloat(level.cols)
        let ch = size.height / CGFloat(level.rows)
        return CGPoint(x: CGFloat(c) * cw + cw / 2, y: CGFloat(r) * ch + ch / 2)
    }

    func tapCell(_ c: Int, _ r: Int) {
        guard c >= 0 && c < level.cols && r >= 0 && r < level.rows else { return }
        if let idx = magnets.firstIndex(where: { $0.gridCol == c && $0.gridRow == r }) {
            if magnets[idx].type == .attractive { magnets[idx].type = .repulsive }
            else { magnets.remove(at: idx) }
        } else {
            magnets.append(MgBV2Magnet(gridCol: c, gridRow: r, type: .attractive))
        }
    }

    func startLevel(_ idx: Int) {
        gameTimer?.invalidate()
        levelIndex = idx
        magnets = []
        collectedCoins = []
        if idx == 0 { score = 0 }
        phase = .playing
        if boardSize == .zero { boardSize = CGSize(width: 300, height: 400) }
        resetBall()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in update() }
    }

    func resetBall() {
        ballPos = CGPoint(x: level.ballStart.x, y: level.ballStart.y)
        ballVel = CGPoint(x: 0.04, y: 0.03)
    }

    func update() {
        guard phase == .playing else { return }
        let k: CGFloat = 0.3
        let dt: CGFloat = CGFloat(0.016 * difficultyMult)
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
        ballVel.x = (ballVel.x + ax * dt) * 0.999
        ballVel.y = (ballVel.y + ay * dt) * 0.999
        let maxV: CGFloat = CGFloat(4.0 * difficultyMult)
        let spd = sqrt(ballVel.x*ballVel.x + ballVel.y*ballVel.y)
        if spd > maxV { ballVel.x = ballVel.x/spd*maxV; ballVel.y = ballVel.y/spd*maxV }
        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt
        if ballPos.x < 0 { ballPos.x = 0; ballVel.x = abs(ballVel.x) }
        if ballPos.y < 0 { ballPos.y = 0; ballVel.y = abs(ballVel.y) }
        if ballPos.x > CGFloat(level.cols) - 1 { ballPos.x = CGFloat(level.cols) - 1; ballVel.x = -abs(ballVel.x) }
        if ballPos.y > CGFloat(level.rows) - 1 { ballPos.y = CGFloat(level.rows) - 1; ballVel.y = -abs(ballVel.y) }
        for (idx, coin) in level.coins.enumerated() {
            if !collectedCoins.contains(idx) {
                let dx = (ballPos.x + 0.5) - (coin.x + 0.5)
                let dy = (ballPos.y + 0.5) - (coin.y + 0.5)
                if dx*dx + dy*dy < 0.5 { collectedCoins.insert(idx); score += 10 }
            }
        }
        let ex = level.exit.x; let ey = level.exit.y
        let dx = (ballPos.x + 0.5) - (ex + 0.5)
        let dy = (ballPos.y + 0.5) - (ey + 0.5)
        if dx*dx + dy*dy < 0.5 {
            score += 50 + collectedCoins.count * 5
            gameTimer?.invalidate()
            phase = .won
        }
    }
}

#Preview { MagnetBallViewV2() }
