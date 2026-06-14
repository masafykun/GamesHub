import SwiftUI

// MARK: - Models

enum MgBMagnetType { case attractive, repulsive }

struct MgBMagnet: Identifiable {
    let id = UUID()
    var gridCol: Int
    var gridRow: Int
    var type: MgBMagnetType
}

struct MgBLevel {
    let cols: Int
    let rows: Int
    let coins: [CGPoint]   // grid coords
    let exit: CGPoint
    let ballStart: CGPoint
}

// MARK: - Game State

enum MgBPhase { case start, playing, won, lost }

struct MagnetBallView: View {

    static let levels: [MgBLevel] = [
        MgBLevel(cols: 6, rows: 8, coins: [CGPoint(x:2,y:2),CGPoint(x:4,y:5)], exit: CGPoint(x:5,y:7), ballStart: CGPoint(x:0,y:0)),
        MgBLevel(cols: 6, rows: 8, coins: [CGPoint(x:1,y:3),CGPoint(x:3,y:1),CGPoint(x:5,y:4)], exit: CGPoint(x:5,y:7), ballStart: CGPoint(x:0,y:7)),
        MgBLevel(cols: 7, rows: 9, coins: [CGPoint(x:2,y:2),CGPoint(x:4,y:4),CGPoint(x:6,y:6)], exit: CGPoint(x:6,y:8), ballStart: CGPoint(x:0,y:0)),
        MgBLevel(cols: 7, rows: 9, coins: [CGPoint(x:1,y:1),CGPoint(x:3,y:3),CGPoint(x:5,y:5),CGPoint(x:6,y:2)], exit: CGPoint(x:6,y:8), ballStart: CGPoint(x:0,y:8)),
    ]

    @State private var phase: MgBPhase = .start
    @State private var levelIndex: Int = 0
    @State private var magnets: [MgBMagnet] = []
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var collectedCoins: Set<Int> = []
    @State private var score: Int = 0
    @State private var timer: Timer? = nil
    @State private var boardSize: CGSize = .zero

    var level: MgBLevel { Self.levels[levelIndex] }
    var cellW: CGFloat { boardSize.width / CGFloat(level.cols) }
    var cellH: CGFloat { boardSize.height / CGFloat(level.rows) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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
        VStack(spacing: 24) {
            Text("MagnetBall").font(.largeTitle.bold())
            Text("Tap grid: Blue = attract, Red = repel, tap again to remove.\nGuide the ball to collect coins and reach the exit.")
                .multilineTextAlignment(.center).font(.footnote).foregroundColor(.gray)
                .padding(.horizontal)
            Button("Play") { startLevel(0) }
                .font(.title2.bold())
                .padding(.horizontal, 40).padding(.vertical, 12)
                .background(Color.blue).clipShape(Capsule())
        }
    }

    // MARK: Game Screen

    var gameScreen: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Level \(levelIndex+1)/\(Self.levels.count)").font(.headline)
                Spacer()
                Text("Score: \(score)").font(.headline)
            }.padding(.horizontal)

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    // Grid background
                    ForEach(0..<level.rows, id: \.self) { r in
                        ForEach(0..<level.cols, id: \.self) { c in
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                .frame(width: cellW, height: cellH)
                                .position(cellCenter(c, r, size))
                        }
                    }
                    // Coins
                    ForEach(Array(level.coins.enumerated()), id: \.offset) { idx, coin in
                        if !collectedCoins.contains(idx) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: cellW * 0.5))
                                .position(cellCenter(Int(coin.x), Int(coin.y), size))
                        }
                    }
                    // Exit
                    Image(systemName: "star.fill")
                        .foregroundColor(.green)
                        .font(.system(size: cellW * 0.6))
                        .position(cellCenter(Int(level.exit.x), Int(level.exit.y), size))
                    // Magnets
                    ForEach(magnets) { m in
                        Circle()
                            .fill(m.type == .attractive ? Color.blue.opacity(0.8) : Color.red.opacity(0.8))
                            .frame(width: cellW * 0.7, height: cellH * 0.7)
                            .overlay(Text(m.type == .attractive ? "+" : "−").font(.caption.bold()).foregroundColor(.white))
                            .position(cellCenter(m.gridCol, m.gridRow, size))
                    }
                    // Ball
                    Circle()
                        .fill(Color.white)
                        .frame(width: cellW * 0.55, height: cellH * 0.55)
                        .shadow(color: .white.opacity(0.8), radius: 6)
                        .position(x: ballPos.x * cellW + cellW / 2,
                                  y: ballPos.y * cellH + cellH / 2)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let c = Int(location.x / cellW)
                    let r = Int(location.y / cellH)
                    tapCell(c, r)
                }
                .onAppear {
                    boardSize = size
                    resetBall(size)
                }
            }

            HStack {
                Button("Restart") { startLevel(levelIndex) }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.gray.opacity(0.3)).clipShape(Capsule())
                Spacer()
                Button(phase == .playing ? "Run Ball" : "") { }
                    .hidden()
            }.padding(.horizontal)
        }.padding(.top)
    }

    func resultScreen(won: Bool) -> some View {
        VStack(spacing: 20) {
            Text(won ? "Level Complete!" : "Try Again").font(.largeTitle.bold())
            Text("Score: \(score)").font(.title2)
            HStack(spacing: 16) {
                if won && levelIndex + 1 < Self.levels.count {
                    Button("Next Level") { startLevel(levelIndex + 1) }
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Color.green).clipShape(Capsule())
                }
                Button("Restart") { startLevel(levelIndex) }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.blue).clipShape(Capsule())
                Button("Menu") { phase = .start; timer?.invalidate() }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.gray.opacity(0.4)).clipShape(Capsule())
            }
        }
    }

    // MARK: Helpers

    func cellCenter(_ c: Int, _ r: Int, _ size: CGSize) -> CGPoint {
        let cw = size.width / CGFloat(level.cols)
        let ch = size.height / CGFloat(level.rows)
        return CGPoint(x: CGFloat(c) * cw + cw / 2, y: CGFloat(r) * ch + ch / 2)
    }

    func tapCell(_ c: Int, _ r: Int) {
        if let idx = magnets.firstIndex(where: { $0.gridCol == c && $0.gridRow == r }) {
            let m = magnets[idx]
            if m.type == .attractive { magnets[idx].type = .repulsive }
            else { magnets.remove(at: idx) }
        } else {
            magnets.append(MgBMagnet(gridCol: c, gridRow: r, type: .attractive))
        }
    }

    func startLevel(_ idx: Int) {
        timer?.invalidate()
        levelIndex = idx
        magnets = []
        collectedCoins = []
        if idx == 0 { score = 0 }
        phase = .playing
        boardSize = boardSize == .zero ? CGSize(width: 300, height: 400) : boardSize
        resetBall(boardSize)
        startTimer()
    }

    func resetBall(_ size: CGSize) {
        ballPos = CGPoint(x: level.ballStart.x, y: level.ballStart.y)
        ballVel = CGPoint(x: 0.03, y: 0.02)
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in update() }
    }

    func update() {
        guard phase == .playing else { return }
        let k: CGFloat = 0.3
        var ax: CGFloat = 0; var ay: CGFloat = 0
        for m in magnets {
            let mx = CGFloat(m.gridCol) + 0.5
            let my = CGFloat(m.gridRow) + 0.5
            let dx = mx - (ballPos.x + 0.5)
            let dy = my - (ballPos.y + 0.5)
            let r2 = max(dx*dx + dy*dy, 0.1)
            let f = k / r2
            let sign: CGFloat = m.type == .attractive ? 1 : -1
            ax += sign * f * dx / sqrt(r2)
            ay += sign * f * dy / sqrt(r2)
        }
        ballVel.x += ax * 0.016
        ballVel.y += ay * 0.016
        let maxV: CGFloat = 3.0
        let spd = sqrt(ballVel.x*ballVel.x + ballVel.y*ballVel.y)
        if spd > maxV { ballVel.x = ballVel.x/spd*maxV; ballVel.y = ballVel.y/spd*maxV }
        ballPos.x += ballVel.x * 0.016
        ballPos.y += ballVel.y * 0.016
        // Bounce off walls
        if ballPos.x < 0 { ballPos.x = 0; ballVel.x = abs(ballVel.x) }
        if ballPos.y < 0 { ballPos.y = 0; ballVel.y = abs(ballVel.y) }
        if ballPos.x > CGFloat(level.cols) - 1 { ballPos.x = CGFloat(level.cols) - 1; ballVel.x = -abs(ballVel.x) }
        if ballPos.y > CGFloat(level.rows) - 1 { ballPos.y = CGFloat(level.rows) - 1; ballVel.y = -abs(ballVel.y) }
        // Check coins
        for (idx, coin) in level.coins.enumerated() {
            if !collectedCoins.contains(idx) {
                let dx = (ballPos.x + 0.5) - (coin.x + 0.5)
                let dy = (ballPos.y + 0.5) - (coin.y + 0.5)
                if dx*dx + dy*dy < 0.5 { collectedCoins.insert(idx); score += 10 }
            }
        }
        // Check exit
        let ex = level.exit.x; let ey = level.exit.y
        let ddx = (ballPos.x + 0.5) - (ex + 0.5)
        let ddy = (ballPos.y + 0.5) - (ey + 0.5)
        if ddx*ddx + ddy*ddy < 0.5 {
            score += 50
            timer?.invalidate()
            if levelIndex + 1 < Self.levels.count { phase = .won }
            else { phase = .won }
        }
    }
}

#Preview { MagnetBallView() }
