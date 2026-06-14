import SwiftUI

// MARK: - Models

enum BreakoutDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Engine State

enum BreakoutEngineState {
    case idle, playing, won, gameOver
}

// MARK: - ViewModel

class BreakoutGameEngine: ObservableObject {
    // Layout constants (set from view geometry)
    var canvasSize: CGSize = .zero

    // Game state
    @Published var gameState: BreakoutEngineState = .idle
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var bricks: [BreakoutBrick] = []
    @Published var ballPos: CGPoint = .zero
    @Published var paddleX: CGFloat = 0
    @Published var difficulty: BreakoutDifficulty = .medium
    @Published var roundScores: [Int] = []

    // Physics
    var ballVelocity: CGPoint = .zero
    var baseSpeed: CGFloat = 5.0
    var paddleWidth: CGFloat = 100

    private var timer: Timer?

    // Layout
    let rows = 5
    let cols = 8
    let brickPadding: CGFloat = 4
    let paddleHeight: CGFloat = 14
    let ballRadius: CGFloat = 10
    let paddleBottomOffset: CGFloat = 60

    // MARK: - Setup

    func setup(size: CGSize) {
        canvasSize = size
        paddleX = size.width / 2
        resetBall()
        buildBricks()
    }

    func resetBall() {
        ballPos = CGPoint(x: canvasSize.width / 2,
                          y: canvasSize.height - paddleBottomOffset - paddleHeight - ballRadius - 2)
        let angle = CGFloat.random(in: -CGFloat.pi / 4 ... CGFloat.pi / 4) - CGFloat.pi / 2
        ballVelocity = CGPoint(x: baseSpeed * cos(angle + CGFloat.pi / 2),
                               y: -baseSpeed)
    }

    func buildBricks() {
        bricks = []
        let totalWidth = canvasSize.width - 16
        let brickWidth = (totalWidth - CGFloat(cols - 1) * brickPadding) / CGFloat(cols)
        let brickHeight: CGFloat = 24
        let topOffset: CGFloat = 80

        let rowColors: [Color] = [.red, .orange, .yellow, .green, .cyan]

        var id = 0
        for row in 0..<rows {
            for col in 0..<cols {
                let x = 8 + CGFloat(col) * (brickWidth + brickPadding)
                let y = topOffset + CGFloat(row) * (brickHeight + brickPadding)
                let rect = CGRect(x: x, y: y, width: brickWidth, height: brickHeight)
                bricks.append(BreakoutBrick(id: id, position: CGPoint(x: x, y: y), size: CGSize(width: brickWidth, height: brickHeight), color: rowColors[row]))
                id += 1
            }
        }
    }

    // MARK: - Difficulty

    func computeDifficulty() {
        guard !roundScores.isEmpty else {
            difficulty = .medium
            return
        }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg < 80 {
            difficulty = .easy
            baseSpeed = 4.0
            paddleWidth = 120
        } else if avg < 200 {
            difficulty = .medium
            baseSpeed = 5.5
            paddleWidth = 100
        } else {
            difficulty = .hard
            baseSpeed = 7.0
            paddleWidth = 75
        }
    }

    // MARK: - Game Loop

    func startGame() {
        guard canvasSize != .zero else { return }
        score = 0
        lives = 3
        buildBricks()
        resetBall()
        gameState = .playing
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard gameState == .playing else { return }
        moveBall()
        checkWin()
    }

    func moveBall() {
        var newX = ballPos.x + ballVelocity.x
        var newY = ballPos.y + ballVelocity.y
        var vx = ballVelocity.x
        var vy = ballVelocity.y

        // Wall bounces
        if newX - ballRadius < 0 {
            newX = ballRadius
            vx = abs(vx)
        } else if newX + ballRadius > canvasSize.width {
            newX = canvasSize.width - ballRadius
            vx = -abs(vx)
        }

        if newY - ballRadius < 0 {
            newY = ballRadius
            vy = abs(vy)
        }

        // Paddle collision
        let paddleY = canvasSize.height - paddleBottomOffset - paddleHeight
        let paddleMinX = paddleX - paddleWidth / 2
        let paddleMaxX = paddleX + paddleWidth / 2

        if newY + ballRadius >= paddleY &&
           newY + ballRadius <= paddleY + paddleHeight + abs(vy) &&
           newX >= paddleMinX &&
           newX <= paddleMaxX &&
           vy > 0 {
            newY = paddleY - ballRadius
            vy = -abs(vy)
            // Add angle based on hit position
            let hitFraction = (newX - paddleMinX) / paddleWidth // 0..1
            let deflect = (hitFraction - 0.5) * 2.0 // -1..1
            vx = deflect * baseSpeed
            let speed = sqrt(vx * vx + vy * vy)
            let scale = baseSpeed / max(speed, 0.1)
            vx *= scale
            vy = -baseSpeed
        }

        // Brick collisions
        let ballRect = CGRect(x: newX - ballRadius, y: newY - ballRadius,
                              width: ballRadius * 2, height: ballRadius * 2)
        for i in bricks.indices {
            guard bricks[i].isAlive else { continue }
            let br = bricks[i].rect
            if ballRect.intersects(br) {
                bricks[i].isAlive = false
                score += 10

                // Determine bounce direction
                let prevBallRect = CGRect(x: ballPos.x - ballRadius, y: ballPos.y - ballRadius,
                                         width: ballRadius * 2, height: ballRadius * 2)
                let overlapX = min(ballRect.maxX, br.maxX) - max(ballRect.minX, br.minX)
                let overlapY = min(ballRect.maxY, br.maxY) - max(ballRect.minY, br.minY)
                let wasAbove = prevBallRect.maxY <= br.minY + 2
                let wasBelow = prevBallRect.minY >= br.maxY - 2

                if overlapX < overlapY || wasAbove || wasBelow {
                    vy = -vy
                } else {
                    vx = -vx
                }
                break
            }
        }

        // Ball fell below
        if newY - ballRadius > canvasSize.height {
            lives -= 1
            if lives <= 0 {
                gameOver()
                return
            } else {
                resetBall()
                return
            }
        }

        ballVelocity = CGPoint(x: vx, y: vy)
        ballPos = CGPoint(x: newX, y: newY)
    }

    func checkWin() {
        if bricks.allSatisfy({ !$0.isAlive }) {
            stopTimer()
            gameState = .won
            finishRound()
        }
    }

    func gameOver() {
        stopTimer()
        gameState = .gameOver
        finishRound()
    }

    func finishRound() {
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        computeDifficulty()
    }

    // MARK: - Paddle

    func movePaddle(to x: CGFloat) {
        let half = paddleWidth / 2
        paddleX = min(max(x, half), canvasSize.width - half)
    }
}

// MARK: - Main View

struct BreakoutViewV2: View {
    @StateObject private var engine = BreakoutGameEngine()
    @State private var roundScores: [Int] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                backgroundGradient

                // Game canvas
                GameCanvas(engine: engine)

                // Overlay UI
                VStack {
                    topBar
                    Spacer()
                }

                // Overlays
                if engine.gameState == .idle {
                    idleOverlay
                } else if engine.gameState == .gameOver {
                    gameOverOverlay
                } else if engine.gameState == .won {
                    wonOverlay
                }
            }
            .onAppear {
                engine.roundScores = roundScores
                engine.computeDifficulty()
                engine.setup(size: geo.size)
            }
            .onChange(of: engine.roundScores) { _, newVal in
                roundScores = newVal
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background

    var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.05, blue: 0.2)]
                : [Color(red: 0.85, green: 0.9, blue: 1.0), Color(red: 0.7, green: 0.8, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack {
            // Score
            glassLabel {
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(engine.score)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            // Difficulty badge
            glassLabel {
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.difficulty.color)
                        .frame(width: 8, height: 8)
                    Text(engine.difficulty.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(engine.difficulty.color)
                }
            }

            Spacer()

            // Lives
            glassLabel {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < engine.lives ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
    }

    func glassLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Idle Overlay

    var idleOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("BREAKOUT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )

                Text("V2 — Adaptive")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                if !roundScores.isEmpty {
                    glassLabel {
                        VStack(spacing: 4) {
                            Text("Recent Scores")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(roundScores.map { "\($0)" }.joined(separator: "  "))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }

                Button(action: { engine.startGame() }) {
                    Text("TAP TO PLAY")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.5), radius: 12, x: 0, y: 6)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(engine.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                difficultyAdjustmentInfo

                Button(action: { engine.startGame() }) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 36)
        }
    }

    // MARK: - Won Overlay

    var wonOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("YOU WIN!")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(engine.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                difficultyAdjustmentInfo

                Button(action: { engine.startGame() }) {
                    Text("NEXT ROUND")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 36)
        }
    }

    // MARK: - Difficulty Adjustment Info

    var difficultyAdjustmentInfo: some View {
        VStack(spacing: 6) {
            if roundScores.count >= 2 {
                let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
                Text("Avg Score: \(Int(avg))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                Text("Next:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Circle()
                    .fill(engine.difficulty.color)
                    .frame(width: 8, height: 8)
                Text(engine.difficulty.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(engine.difficulty.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Game Canvas

struct BreakoutGameCanvas: View {
    @ObservedObject var engine: BreakoutGameEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Bricks
                ForEach(engine.bricks) { brick in
                    if brick.isAlive {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [brick.color.opacity(0.9), brick.color.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: brick.color.opacity(0.4), radius: 4, x: 0, y: 2)
                            .frame(width: brick.rect.width, height: brick.rect.height)
                            .position(x: brick.rect.midX, y: brick.rect.midY)
                    }
                }

                // Ball
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .cyan.opacity(0.9)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: engine.ballRadius * 2
                            )
                        )
                        .frame(width: engine.ballRadius * 2, height: engine.ballRadius * 2)
                        .shadow(color: .cyan.opacity(0.7), radius: 8, x: 0, y: 0)
                }
                .position(engine.ballPos)

                // Paddle
                RoundedRectangle(cornerRadius: engine.paddleHeight / 2)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: engine.paddleHeight / 2)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: engine.paddleHeight / 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.cyan.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 6, x: 0, y: 2)
                    .frame(width: engine.paddleWidth, height: engine.paddleHeight)
                    .position(x: engine.paddleX,
                              y: geo.size.height - engine.paddleBottomOffset - engine.paddleHeight / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if engine.gameState == .idle {
                            engine.setup(size: geo.size)
                            engine.startGame()
                        }
                        engine.movePaddle(to: value.location.x)
                    }
            )
        }
    }
}

// Alias to satisfy the rule of naming with game prefix
typealias GameCanvas = BreakoutGameCanvas
