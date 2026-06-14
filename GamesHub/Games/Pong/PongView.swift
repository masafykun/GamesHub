import SwiftUI

struct PongView: View {
    // MARK: - Game State
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGVector = CGVector(dx: 4, dy: 3)
    @State private var playerY: CGFloat = 0
    @State private var aiY: CGFloat = 0
    @State private var playerScore: Int = 0
    @State private var aiScore: Int = 0
    @State private var isPlaying: Bool = false
    @State private var gameOver: Bool = false
    @State private var winnerText: String = ""

    // MARK: - Constants
    private let ballRadius: CGFloat = 10
    private let paddleWidth: CGFloat = 14
    private let paddleHeight: CGFloat = 80
    private let paddleInset: CGFloat = 20
    private let winScore: Int = 5
    private let aiSpeed: CGFloat = 3
    private let speedMultiplier: CGFloat = 1.05
    private let maxSpeed: CGFloat = 12

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                Color.black.ignoresSafeArea()

                if !isPlaying && !gameOver {
                    startScreen
                } else if gameOver {
                    gameOverScreen
                } else {
                    gameCanvas(size: size)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    playerY = value.location.y
                                }
                        )
                }
            }
            .onAppear {
                resetBall(size: size)
                playerY = size.height / 2
                aiY = size.height / 2
            }
            .onReceive(timer) { _ in
                guard isPlaying && !gameOver else { return }
                updateGame(size: size)
            }
        }
    }

    // MARK: - Start Screen
    private var startScreen: some View {
        VStack(spacing: 40) {
            Text("PONG")
                .font(.system(size: 72, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            Button(action: startGame) {
                Text("TAP TO START")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Game Over Screen
    private var gameOverScreen: some View {
        VStack(spacing: 32) {
            Text(winnerText)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("\(aiScore) — \(playerScore)")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            Button(action: restartGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Game Canvas
    private func gameCanvas(size: CGSize) -> some View {
        ZStack {
            Canvas { context, canvasSize in
                // Center dashed line
                let dashHeight: CGFloat = 16
                let dashGap: CGFloat = 10
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let rect = CGRect(x: canvasSize.width / 2 - 2, y: y, width: 4, height: dashHeight)
                    context.fill(Path(rect), with: .color(.white.opacity(0.3)))
                    y += dashHeight + dashGap
                }

                // AI paddle (left)
                let aiPaddleRect = CGRect(
                    x: paddleInset,
                    y: aiY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                context.fill(
                    Path(roundedRect: aiPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(.white)
                )

                // Player paddle (right)
                let playerPaddleRect = CGRect(
                    x: canvasSize.width - paddleInset - paddleWidth,
                    y: playerY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(.white)
                )

                // Ball
                let ballRect = CGRect(
                    x: ballPos.x - ballRadius,
                    y: ballPos.y - ballRadius,
                    width: ballRadius * 2,
                    height: ballRadius * 2
                )
                context.fill(Path(ellipseIn: ballRect), with: .color(.white))
            }
            .frame(width: size.width, height: size.height)

            // Score display
            VStack {
                HStack {
                    Text("\(aiScore)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)

                    Text("\(playerScore)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 40)
                Spacer()
            }
        }
    }

    // MARK: - Game Logic
    private func startGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        isPlaying = true
    }

    private func restartGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        winnerText = ""
        isPlaying = true
    }

    private func resetBall(size: CGSize) {
        ballPos = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx: CGFloat = Bool.random() ? 4 : -4
        let dy: CGFloat = Bool.random() ? 3 : -3
        ballVel = CGVector(dx: dx, dy: dy)
    }

    private func updateGame(size: CGSize) {
        // Move ball
        ballPos.x += ballVel.dx
        ballPos.y += ballVel.dy

        // Wall bounce (top/bottom)
        if ballPos.y - ballRadius <= 0 {
            ballPos.y = ballRadius
            ballVel.dy = abs(ballVel.dy)
        }
        if ballPos.y + ballRadius >= size.height {
            ballPos.y = size.height - ballRadius
            ballVel.dy = -abs(ballVel.dy)
        }

        // AI paddle tracking
        let aiDiff = ballPos.y - aiY
        let aiMove = min(abs(aiDiff), aiSpeed) * (aiDiff > 0 ? 1 : -1)
        aiY = (aiY + aiMove).clamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))

        // Player paddle bounds
        playerY = playerY.clamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))

        // Player paddle collision (right side)
        let playerPaddleX = size.width - paddleInset - paddleWidth
        if ballPos.x + ballRadius >= playerPaddleX &&
            ballPos.x + ballRadius <= playerPaddleX + paddleWidth + abs(ballVel.dx) &&
            ballPos.y >= playerY - paddleHeight / 2 &&
            ballPos.y <= playerY + paddleHeight / 2 &&
            ballVel.dx > 0 {
            ballPos.x = playerPaddleX - ballRadius
            ballVel.dx = -ballVel.dx
            speedUp()
        }

        // AI paddle collision (left side)
        let aiPaddleX = paddleInset + paddleWidth
        if ballPos.x - ballRadius <= aiPaddleX &&
            ballPos.x - ballRadius >= aiPaddleX - paddleWidth - abs(ballVel.dx) &&
            ballPos.y >= aiY - paddleHeight / 2 &&
            ballPos.y <= aiY + paddleHeight / 2 &&
            ballVel.dx < 0 {
            ballPos.x = aiPaddleX + ballRadius
            ballVel.dx = -ballVel.dx
            speedUp()
        }

        // Scoring
        if ballPos.x - ballRadius <= 0 {
            // Ball passed left wall: AI scores
            aiScore += 1
            checkWin(size: size)
            if !gameOver { resetBall(size: size) }
        } else if ballPos.x + ballRadius >= size.width {
            // Ball passed right wall: player scores
            playerScore += 1
            checkWin(size: size)
            if !gameOver { resetBall(size: size) }
        }
    }

    private func speedUp() {
        let speed = sqrt(ballVel.dx * ballVel.dx + ballVel.dy * ballVel.dy)
        if speed < maxSpeed {
            ballVel.dx *= speedMultiplier
            ballVel.dy *= speedMultiplier
        }
    }

    private func checkWin(size: CGSize) {
        if playerScore >= winScore {
            winnerText = "YOU WIN!"
            isPlaying = false
            gameOver = true
        } else if aiScore >= winScore {
            winnerText = "AI WINS!"
            isPlaying = false
            gameOver = true
        }
    }
}

// MARK: - Comparable clamping helper (file-private)
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
