import SwiftUI

// MARK: - Models
struct BkBlBrick: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var hits: Int
}

struct BkBlBall {
    var x: Double
    var y: Double
    var dx: Double
    var dy: Double
}

enum BkBlPhase {
    case start, playing, gameOver
}

// MARK: - Main View
struct BrickBlastView: View {
    let cols = 7
    let rows = 5
    let brickW: CGFloat = 44
    let brickH: CGFloat = 20
    let ballR: CGFloat = 8

    @State private var phase: BkBlPhase = .start
    @State private var bricks: [BkBlBrick] = []
    @State private var ball: BkBlBall = BkBlBall(x: 0, y: 0, dx: 0, dy: 0)
    @State private var ballActive = false
    @State private var aimAngle: Double = -Double.pi / 2
    @State private var score = 0
    @State private var gameTimer: Timer? = nil
    @State private var rowTimer: Timer? = nil
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
    }

    // MARK: - Screens
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("BRICK BLAST").font(.largeTitle).bold().foregroundColor(.orange)
            Text("Tap to aim, fire to launch!\nBreak all bricks before they reach you.").multilineTextAlignment(.center).foregroundColor(.gray)
            Button("START") { startGame() }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 12)
                .background(Color.orange).foregroundColor(.black).clipShape(Capsule())
        }.padding()
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.largeTitle).bold().foregroundColor(.red)
            Text("Score: \(score)").font(.title).foregroundColor(.white)
            Button("PLAY AGAIN") { startGame() }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 12)
                .background(Color.orange).foregroundColor(.black).clipShape(Capsule())
        }
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                // Bricks
                ForEach(bricks) { brick in
                    brickView(brick: brick, geo: geo)
                }
                // Ball
                if ballActive {
                    Circle()
                        .fill(Color.white)
                        .frame(width: ballR * 2, height: ballR * 2)
                        .position(x: ball.x, y: ball.y)
                }
                // Aim arrow
                if !ballActive {
                    aimArrow(geo: geo)
                }
                // Paddle line
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 60, height: 6)
                    .position(x: geo.size.width / 2, y: geo.size.height - 40)
                // Score
                Text("Score: \(score)")
                    .foregroundColor(.white).font(.headline)
                    .position(x: 70, y: 24)
                // Fire button
                if !ballActive {
                    Button("FIRE") { fireBall(geo: geo) }
                        .font(.headline).padding(.horizontal, 30).padding(.vertical, 10)
                        .background(Color.orange).foregroundColor(.black).clipShape(Capsule())
                        .position(x: geo.size.width / 2, y: geo.size.height - 16)
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
            .onAppear { canvasSize = geo.size }
        }
    }

    func brickView(brick: BkBlBrick, geo: GeometryProxy) -> some View {
        let x = CGFloat(brick.col) * (brickW + 4) + brickW / 2 + 8
        let y = CGFloat(brick.row) * (brickH + 4) + brickH / 2 + 50
        let color: Color = brick.hits == 3 ? .red : brick.hits == 2 ? .yellow : .green
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(color)
                .frame(width: brickW, height: brickH)
            Text("\(brick.hits)").font(.caption2).bold().foregroundColor(.black)
        }.position(x: x, y: y)
    }

    func aimArrow(geo: GeometryProxy) -> some View {
        let cx = geo.size.width / 2
        let cy = geo.size.height - 44
        let len: CGFloat = 60
        let ex = cx + len * CGFloat(cos(aimAngle))
        let ey = cy + len * CGFloat(sin(aimAngle))
        return Path { path in
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: ex, y: ey))
        }.stroke(Color.orange, lineWidth: 2)
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

    func generateRow(row: Int) -> [BkBlBrick] {
        (0..<cols).map { col in
            BkBlBrick(col: col, row: row, hits: Int.random(in: 1...3))
        }
    }

    func fireBall(geo: GeometryProxy) {
        guard !ballActive else { return }
        let speed: Double = 5
        ball = BkBlBall(
            x: geo.size.width / 2,
            y: geo.size.height - 50,
            dx: speed * cos(aimAngle),
            dy: speed * sin(aimAngle)
        )
        ballActive = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateBall(geo: geo)
        }
    }

    func updateBall(geo: GeometryProxy) {
        ball.x += ball.dx
        ball.y += ball.dy

        if ball.x - ballR < 0 { ball.x = ballR; ball.dx = abs(ball.dx) }
        if ball.x + ballR > geo.size.width { ball.x = geo.size.width - ballR; ball.dx = -abs(ball.dx) }
        if ball.y - ballR < 0 { ball.y = ballR; ball.dy = abs(ball.dy) }

        if ball.y + ballR > geo.size.height {
            endBall()
            phase = .gameOver
            return
        }

        // Brick collision
        for i in bricks.indices {
            let bx = CGFloat(bricks[i].col) * (brickW + 4) + 8
            let by = CGFloat(bricks[i].row) * (brickH + 4) + 50
            let rect = CGRect(x: bx, y: by, width: brickW, height: brickH)
            if rect.contains(CGPoint(x: ball.x, y: ball.y)) {
                bricks[i].hits -= 1
                if bricks[i].hits <= 0 { bricks.remove(at: i); score += 1 }
                ball.dy = -ball.dy
                break
            }
        }

        // Check bricks reaching bottom
        if bricks.contains(where: { CGFloat($0.row) * (brickH + 4) + 50 > geo.size.height - 80 }) {
            endBall()
            phase = .gameOver
        }
    }

    func endBall() {
        gameTimer?.invalidate()
        gameTimer = nil
        rowTimer?.invalidate()
        rowTimer = nil
        ballActive = false
    }

    func startRowTimer() {
        rowTimer?.invalidate()
        rowTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            descendAndAdd()
        }
    }

    func descendAndAdd() {
        bricks = bricks.map { var b = $0; b.row += 1; return b }
        let newRow = generateRow(row: 0)
        bricks.append(contentsOf: newRow)
    }
}

#Preview { BrickBlastView() }
