import SwiftUI

// MARK: - LCG Seeded Random
struct BkBlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models
struct BkBlV3Brick: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var hits: Int
}

struct BkBlV3Ball {
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
}

enum BkBlV3Phase {
    case start, playing, gameOver
}

// MARK: - V3 View (Neumorphism + Seeded Procedural Generation)
struct BrickBlastViewV3: View {
    let cols = 7
    let brickW: CGFloat = 44
    let brickH: CGFloat = 20
    let ballR: CGFloat = 8

    @State private var phase: BkBlV3Phase = .start
    @State private var bricks: [BkBlV3Brick] = []
    @State private var ball: BkBlV3Ball = BkBlV3Ball(x: 0, y: 0, dx: 0, dy: 0)
    @State private var ballActive = false
    @State private var aimAngle: Double = -Double.pi / 2
    @State private var score = 0
    @State private var gameTimer: Timer? = nil
    @State private var rowTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var lcg: BkBlLCG = BkBlLCG(seed: 1)
    @State private var rowCount: Int = 0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
            Text("BRICK BLAST").font(.largeTitle).bold().foregroundColor(.primary)
            Text("Aim and fire to break bricks!\nBricks descend over time.").multilineTextAlignment(.center).foregroundColor(.secondary)
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button("START") { startGame() }
                .font(.headline.bold()).padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 22)
                .foregroundColor(.primary)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.largeTitle).bold().foregroundColor(.red)
            Text("Score: \(score)").font(.title2).foregroundColor(.primary)
            Text("SEED: #\(seedInt - 1)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button("PLAY AGAIN") { startGame() }
                .font(.headline.bold()).padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 22)
                .foregroundColor(.primary)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bricks) { brick in brickView(brick: brick) }

                if ballActive {
                    Circle()
                        .fill(Color(.systemGray2))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                        .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                        .frame(width: ballR * 2, height: ballR * 2)
                        .position(x: ball.x, y: ball.y)
                }

                if !ballActive { aimArrow(geo: geo) }

                // Paddle
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(.systemGray4))
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)
                    .frame(width: 70, height: 10)
                    .position(x: geo.size.width / 2, y: geo.size.height - 40)

                // Score + Seed
                HStack {
                    Text("Score: \(score)").font(.headline.bold()).foregroundColor(.primary)
                    Spacer()
                    Text("SEED: #\(seedInt)").font(.system(.caption2, design: .monospaced)).foregroundColor(.gray)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .neumorphicCard(radius: 12)
                .frame(width: geo.size.width - 32)
                .position(x: geo.size.width / 2, y: 28)

                if !ballActive {
                    Button("FIRE") { fireBall(geo: geo) }
                        .font(.headline.bold()).padding(.horizontal, 32).padding(.vertical, 10)
                        .neumorphicCard(radius: 20)
                        .foregroundColor(.primary)
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

    func brickView(brick: BkBlV3Brick) -> some View {
        let x = CGFloat(brick.col) * (brickW + 4) + brickW / 2 + 8
        let y = CGFloat(brick.row) * (brickH + 4) + brickH / 2 + 50
        let accent: Color = brick.hits == 3 ? .red : brick.hits == 2 ? .orange : .green
        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(.systemGray5))
                .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
                .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                .frame(width: brickW, height: brickH)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(accent.opacity(0.5), lineWidth: 1.5)
                )
            Text("\(brick.hits)").font(.caption2.bold()).foregroundColor(accent)
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
        }.stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
    }

    // MARK: - Seeded Generation
    func generateRow(row: Int) -> [BkBlV3Brick] {
        // Use LCG to decide hits for each brick, and occasionally skip a column
        var result: [BkBlV3Brick] = []
        for col in 0..<cols {
            let skip = lcg.nextInt(5) == 0  // 20% chance to skip a column
            if !skip {
                let hits = lcg.nextInt(3) + 1
                result.append(BkBlV3Brick(col: col, row: row, hits: hits))
            }
        }
        // Ensure at least 2 bricks per row
        if result.count < 2 {
            let col = lcg.nextInt(cols)
            result.append(BkBlV3Brick(col: col, row: row, hits: 1))
        }
        return result
    }

    // MARK: - Game Logic
    func startGame() {
        score = 0
        ballActive = false
        aimAngle = -Double.pi / 2
        rowCount = 0
        lcg = BkBlLCG(seed: seedInt)
        seedInt += 1
        bricks = generateRow(row: 0) + generateRow(row: 1)
        rowCount = 2
        phase = .playing
        startRowTimer()
    }

    func fireBall(geo: GeometryProxy) {
        guard !ballActive else { return }
        let speed: Double = 5.5
        ball = BkBlV3Ball(
            x: geo.size.width / 2, y: geo.size.height - 50,
            dx: speed * cos(aimAngle), dy: speed * sin(aimAngle)
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
            endBall(); phase = .gameOver; return
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
            endBall(); phase = .gameOver
        }
    }

    func endBall() {
        gameTimer?.invalidate(); gameTimer = nil
        rowTimer?.invalidate(); rowTimer = nil
        ballActive = false
    }

    func startRowTimer() {
        rowTimer?.invalidate()
        rowTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            bricks = bricks.map { var b = $0; b.row += 1; return b }
            let newRow = generateRow(row: 0)
            bricks.append(contentsOf: newRow)
            rowCount += 1
        }
    }
}

#Preview { BrickBlastViewV3() }
