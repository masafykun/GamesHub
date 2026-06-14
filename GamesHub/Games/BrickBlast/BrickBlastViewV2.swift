import SwiftUI

// MARK: - Models
struct BkBlV2Brick: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var hits: Int
}

struct BkBlV2Ball {
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
}

enum BkBlV2Phase {
    case start, playing, gameOver
}

// MARK: - V2 View (Glassmorphism + Adaptive Difficulty)
struct BrickBlastViewV2: View {
    let cols = 7
    let brickW: CGFloat = 44
    let brickH: CGFloat = 20
    let ballR: CGFloat = 8

    @State private var phase: BkBlV2Phase = .start
    @State private var bricks: [BkBlV2Brick] = []
    @State private var ball: BkBlV2Ball = BkBlV2Ball(x: 0, y: 0, dx: 0, dy: 0)
    @State private var ballActive = false
    @State private var aimAngle: Double = -Double.pi / 2
    @State private var score = 0
    @State private var gameTimer: Timer? = nil
    @State private var rowTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var ballSpeed: Double = 5.0
    @State private var rowInterval: Double = 5.0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.3), Color(red: 0.05, green: 0.15, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens
    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BRICK BLAST").font(.largeTitle).bold().foregroundColor(.white)
            Text("Aim with drag\nTap FIRE to launch the ball").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            if !recentResults.isEmpty {
                Text("Difficulty adapts to your skill").font(.caption).foregroundColor(.cyan.opacity(0.8))
            }
            Button("START") { startGame() }
                .font(.headline.bold()).padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.largeTitle).bold().foregroundColor(.red.opacity(0.9))
            Text("Score: \(score)").font(.title).foregroundColor(.white)
            Text("Speed: \(String(format: "%.1f", ballSpeed))x").font(.caption).foregroundColor(.cyan)
            Button("PLAY AGAIN") { startGame() }
                .font(.headline.bold()).padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bricks) { brick in brickView(brick: brick) }
                if ballActive {
                    Circle()
                        .fill(.white.shadow(.drop(color: .cyan, radius: 6)))
                        .frame(width: ballR * 2, height: ballR * 2)
                        .position(x: ball.x, y: ball.y)
                }
                if !ballActive { aimArrow(geo: geo) }

                // Paddle
                RoundedRectangle(cornerRadius: 4)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.5), lineWidth: 1))
                    .frame(width: 70, height: 8)
                    .position(x: geo.size.width / 2, y: geo.size.height - 40)

                // Score panel
                HStack {
                    Text("Score: \(score)").font(.headline.bold()).foregroundColor(.white)
                    Spacer()
                    Text("Spd: \(String(format: "%.1f", ballSpeed / 5.0))x").font(.caption).foregroundColor(.cyan)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                .frame(width: geo.size.width - 32)
                .position(x: geo.size.width / 2, y: 28)

                if !ballActive {
                    Button("FIRE") { fireBall(geo: geo) }
                        .font(.headline.bold()).padding(.horizontal, 32).padding(.vertical, 10)
                        .background(.ultraThinMaterial).clipShape(Capsule())
                        .overlay(Capsule().stroke(.cyan.opacity(0.6), lineWidth: 1))
                        .foregroundColor(.white)
                        .position(x: geo.size.width / 2, y: geo.size.height - 14)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                let cx = geo.size.width / 2
                let cy = geo.size.height - 44
                let dx = val.location.x - cx
                let dy = val.location.y - cy
                if abs(dx) > 2 || abs(dy) > 2 {
                    aimAngle = atan2(dy, dx)
                }
            })
        }
    }

    func brickView(brick: BkBlV2Brick) -> some View {
        let x = CGFloat(brick.col) * (brickW + 4) + brickW / 2 + 8
        let y = CGFloat(brick.row) * (brickH + 4) + brickH / 2 + 50
        let hue: Double = brick.hits == 3 ? 0.0 : brick.hits == 2 ? 0.12 : 0.45
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hue: hue, saturation: 0.9, brightness: 1).opacity(0.8), lineWidth: 1.5))
                .frame(width: brickW, height: brickH)
            Text("\(brick.hits)").font(.caption2.bold()).foregroundColor(.white)
        }.position(x: x, y: y)
    }

    func aimArrow(geo: GeometryProxy) -> some View {
        let cx = geo.size.width / 2
        let cy = geo.size.height - 44
        let len: CGFloat = 70
        let ex = cx + len * CGFloat(cos(aimAngle))
        let ey = cy + len * CGFloat(sin(aimAngle))
        return Path { path in
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: ex, y: ey))
        }.stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
    }

    // MARK: - Adaptive Difficulty
    func applyAdaptiveDifficulty(won: Bool) {
        recentResults.append(won)
        if recentResults.count > 5 { recentResults.removeFirst() }
        let wins = recentResults.filter { $0 }.count
        if recentResults.count == 5 && wins > 4 {
            ballSpeed = min(ballSpeed * 1.2, 12.0)
            rowInterval = max(rowInterval * 0.85, 2.5)
        }
    }

    // MARK: - Game Logic
    func startGame() {
        score = 0
        ballActive = false
        aimAngle = -Double.pi / 2
        bricks = generateRow(row: 0) + generateRow(row: 1)
        phase = .playing
        startRowTimer()
    }

    func generateRow(row: Int) -> [BkBlV2Brick] {
        (0..<cols).map { col in BkBlV2Brick(col: col, row: row, hits: Int.random(in: 1...3)) }
    }

    func fireBall(geo: GeometryProxy) {
        guard !ballActive else { return }
        ball = BkBlV2Ball(
            x: geo.size.width / 2, y: geo.size.height - 50,
            dx: ballSpeed * cos(aimAngle), dy: ballSpeed * sin(aimAngle)
        )
        ballActive = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateBall(geo: geo)
        }
    }

    func updateBall(geo: GeometryProxy) {
        ball.x += ball.dx; ball.y += ball.dy
        if ball.x - ballR < 0 { ball.x = ballR; ball.dx = abs(ball.dx) }
        if ball.x + ballR > geo.size.width { ball.x = geo.size.width - ballR; ball.dx = -abs(ball.dx) }
        if ball.y - ballR < 0 { ball.y = ballR; ball.dy = abs(ball.dy) }
        if ball.y + ballR > geo.size.height {
            endBall(); applyAdaptiveDifficulty(won: false); phase = .gameOver; return
        }
        for i in bricks.indices {
            let bx = CGFloat(bricks[i].col) * (brickW + 4) + 8
            let by = CGFloat(bricks[i].row) * (brickH + 4) + 50
            if CGRect(x: bx, y: by, width: brickW, height: brickH).contains(CGPoint(x: ball.x, y: ball.y)) {
                bricks[i].hits -= 1
                if bricks[i].hits <= 0 { bricks.remove(at: i); score += 1 }
                ball.dy = -ball.dy; break
            }
        }
        if bricks.contains(where: { CGFloat($0.row) * (brickH + 4) + 50 > geo.size.height - 80 }) {
            endBall(); applyAdaptiveDifficulty(won: false); phase = .gameOver
        }
    }

    func endBall() {
        gameTimer?.invalidate(); gameTimer = nil
        rowTimer?.invalidate(); rowTimer = nil
        ballActive = false
    }

    func startRowTimer() {
        rowTimer?.invalidate()
        rowTimer = Timer.scheduledTimer(withTimeInterval: rowInterval, repeats: true) { _ in
            bricks = bricks.map { var b = $0; b.row += 1; return b }
            bricks.append(contentsOf: generateRow(row: 0))
        }
    }
}

#Preview { BrickBlastViewV2() }
