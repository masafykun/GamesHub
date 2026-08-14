import SwiftUI

// MARK: - Models

struct BreakoutBrick: Identifiable {
    let id: Int
    var position: CGPoint
    var size: CGSize
    var color: Color
    var isAlive: Bool = true
    var rect: CGRect { CGRect(origin: position, size: size) }
}

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

enum BreakoutEngineState {
    case idle, playing, won, gameOver
}

// MARK: - Engine

final class BreakoutGameEngine: ObservableObject {
    var canvasSize: CGSize = .zero

    @Published var gameState: BreakoutEngineState = .idle
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var bricks: [BreakoutBrick] = []
    @Published var ballPos: CGPoint = .zero
    @Published var paddleX: CGFloat = 0
    @Published var difficulty: BreakoutDifficulty = .medium
    @Published var roundScores: [Int] = []

    var ballVelocity: CGPoint = .zero
    var baseSpeed: CGFloat = 5.0
    var paddleWidth: CGFloat = 100

    private var difficultySpeed: CGFloat = 5.0
    private var timer: Timer?

    let rows = 5
    let cols = 8
    let brickPadding: CGFloat = 4
    let paddleHeight: CGFloat = 14
    let ballRadius: CGFloat = 10
    let paddleBottomOffset: CGFloat = 60

    // MARK: Setup

    func setup(size: CGSize) {
        canvasSize = size
        paddleX = size.width / 2
        resetBall()
        buildBricks()
    }

    func resetBall() {
        ballPos = CGPoint(x: paddleX,
                          y: canvasSize.height - paddleBottomOffset - paddleHeight - ballRadius - 2)
        let angle = CGFloat.random(in: -CGFloat.pi / 5 ... CGFloat.pi / 5)
        ballVelocity = CGPoint(x: baseSpeed * sin(angle), y: -baseSpeed * cos(angle))
    }

    func buildBricks() {
        bricks = []
        let totalWidth = canvasSize.width - 16
        let brickWidth = (totalWidth - CGFloat(cols - 1) * brickPadding) / CGFloat(cols)
        let brickHeight: CGFloat = 24
        let topOffset: CGFloat = 70

        let rowColors: [Color] = [.red, .orange, .yellow, .green, .cyan]

        var id = 0
        for row in 0..<rows {
            for col in 0..<cols {
                let x = 8 + CGFloat(col) * (brickWidth + brickPadding)
                let y = topOffset + CGFloat(row) * (brickHeight + brickPadding)
                bricks.append(
                    BreakoutBrick(id: id,
                                  position: CGPoint(x: x, y: y),
                                  size: CGSize(width: brickWidth, height: brickHeight),
                                  color: rowColors[row])
                )
                id += 1
            }
        }
    }

    // MARK: Difficulty

    /// Adapts to how the last few rounds went, so the paddle and ball
    /// speed match the player instead of staying fixed forever.
    func computeDifficulty() {
        guard !roundScores.isEmpty else {
            difficulty = .medium
            difficultySpeed = 5.5
            paddleWidth = 100
            return
        }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg < 150 {
            difficulty = .easy
            difficultySpeed = 4.4
            paddleWidth = 120
        } else if avg < 320 {
            difficulty = .medium
            difficultySpeed = 5.5
            paddleWidth = 100
        } else {
            difficulty = .hard
            difficultySpeed = 7.0
            paddleWidth = 78
        }
    }

    private func applySpeedForLevel() {
        baseSpeed = difficultySpeed + CGFloat(level - 1) * 0.5
    }

    // MARK: Loop

    func startGame() {
        guard canvasSize != .zero else { return }
        score = 0
        lives = 3
        level = 1
        computeDifficulty()
        applySpeedForLevel()
        paddleX = canvasSize.width / 2
        buildBricks()
        resetBall()
        gameState = .playing
        startTimer()
    }

    /// Keeps the score and lives, but rebuilds the wall a little faster.
    func nextLevel() {
        guard canvasSize != .zero else { return }
        level += 1
        applySpeedForLevel()
        buildBricks()
        resetBall()
        gameState = .playing
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
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

        // Paddle
        let paddleY = canvasSize.height - paddleBottomOffset - paddleHeight
        let paddleMinX = paddleX - paddleWidth / 2
        let paddleMaxX = paddleX + paddleWidth / 2

        if newY + ballRadius >= paddleY &&
            newY + ballRadius <= paddleY + paddleHeight + abs(vy) &&
            newX >= paddleMinX &&
            newX <= paddleMaxX &&
            vy > 0 {
            newY = paddleY - ballRadius
            // Where it lands on the paddle decides the outgoing angle.
            let hitFraction = (newX - paddleMinX) / paddleWidth
            let deflect = max(-1, min(1, (hitFraction - 0.5) * 2.0))
            let angle = deflect * (CGFloat.pi / 3)
            vx = baseSpeed * sin(angle)
            vy = -baseSpeed * cos(angle)
        }

        // Bricks
        let ballRect = CGRect(x: newX - ballRadius, y: newY - ballRadius,
                              width: ballRadius * 2, height: ballRadius * 2)
        for i in bricks.indices {
            guard bricks[i].isAlive else { continue }
            let br = bricks[i].rect
            if ballRect.intersects(br) {
                bricks[i].isAlive = false
                score += 10 * level

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

        if newY - ballRadius > canvasSize.height {
            lives -= 1
            if lives <= 0 {
                gameOver()
            } else {
                resetBall()
            }
            return
        }

        ballVelocity = CGPoint(x: vx, y: vy)
        ballPos = CGPoint(x: newX, y: newY)
    }

    func checkWin() {
        if bricks.allSatisfy({ !$0.isAlive }) {
            stopTimer()
            gameState = .won
            score += 50 * level
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
    }

    func movePaddle(to x: CGFloat) {
        let half = paddleWidth / 2
        paddleX = min(max(x, half), canvasSize.width - half)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Main View

struct BreakoutView: View {
    @StateObject private var engine = BreakoutGameEngine()
    @AppStorage("breakoutBestScore") private var bestScore: Int = 0
    @State private var roundScores: [Int] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient

                BreakoutGameCanvas(engine: engine)

                VStack {
                    topBar
                    Spacer()
                }

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
                if let last = newVal.last { bestScore = max(bestScore, last) }
            }
            .onDisappear { engine.stopTimer() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Background

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

    // MARK: Top bar

    var topBar: some View {
        HStack {
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

            glassLabel {
                VStack(spacing: 2) {
                    Text("LEVEL \(engine.level)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(engine.difficulty.color)
                            .frame(width: 7, height: 7)
                        Text(engine.difficulty.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(engine.difficulty.color)
                    }
                }
            }

            Spacer()

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
        .padding(.top, 8)
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

    // MARK: Overlays

    var idleOverlay: some View {
        overlayCard {
            VStack(spacing: 22) {
                Text("BREAKOUT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Drag anywhere to steer the paddle")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                if bestScore > 0 {
                    glassLabel {
                        Text("Best: \(bestScore)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }

                capsuleButton(title: "TAP TO PLAY", colors: [.cyan, .purple]) { engine.startGame() }
            }
        }
    }

    var gameOverOverlay: some View {
        overlayCard {
            VStack(spacing: 18) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(engine.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Best: \(bestScore) · reached level \(engine.level)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                difficultyAdjustmentInfo

                capsuleButton(title: "PLAY AGAIN", colors: [.orange, .red]) { engine.startGame() }
            }
        }
    }

    var wonOverlay: some View {
        overlayCard {
            VStack(spacing: 18) {
                Text("WALL CLEARED!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(engine.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Level \(engine.level + 1) is faster — lives carry over")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                capsuleButton(title: "NEXT LEVEL", colors: [.green, .cyan]) { engine.nextLevel() }
            }
        }
    }

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

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            content()
                .padding(28)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 32)
        }
    }

    private func capsuleButton(title: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: colors[0].opacity(0.5), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Canvas

struct BreakoutGameCanvas: View {
    @ObservedObject var engine: BreakoutGameEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
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
                    .shadow(color: .cyan.opacity(0.7), radius: 8)
                    .position(engine.ballPos)

                RoundedRectangle(cornerRadius: engine.paddleHeight / 2)
                    .fill(.ultraThinMaterial)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: engine.paddleHeight / 2)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
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
                        engine.movePaddle(to: value.location.x)
                    }
            )
        }
    }
}

#Preview {
    BreakoutView()
}
