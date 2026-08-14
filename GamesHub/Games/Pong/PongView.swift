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
    @State private var ballGlow: Bool = false

    // MARK: - Constants
    private let ballRadius: CGFloat = 10
    private let paddleWidth: CGFloat = 14
    private let paddleHeight: CGFloat = 80
    private let paddleInset: CGFloat = 20
    private let winScore: Int = 5
    private let aiSpeed: CGFloat = 3
    private let speedMultiplier: CGFloat = 1.05
    private let maxSpeed: CGFloat = 12

    // MARK: - Glassmorphism Colors
    private let accentBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    private let accentPurple = Color(red: 0.6, green: 0.2, blue: 1.0)
    private let accentCyan = Color(red: 0.0, green: 0.8, blue: 1.0)

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // Deep gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.04, blue: 0.18),
                        Color(red: 0.08, green: 0.04, blue: 0.25),
                        Color(red: 0.05, green: 0.08, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Ambient glow orbs
                Circle()
                    .fill(accentPurple.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -size.width * 0.25, y: -size.height * 0.2)

                Circle()
                    .fill(accentBlue.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: size.width * 0.25, y: size.height * 0.25)

                if !isPlaying && !gameOver {
                    pongStartScreen
                } else if gameOver {
                    pongGameOverScreen
                } else {
                    pongGameCanvas(size: size)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    playerY = value.location.y
                                }
                        )
                }
            }
            .onAppear {
                pongResetBall(size: size)
                playerY = size.height / 2
                aiY = size.height / 2
            }
            .onReceive(timer) { _ in
                guard isPlaying && !gameOver else { return }
                pongUpdateGame(size: size)
            }
        }
    }

    // MARK: - Start Screen
    private var pongStartScreen: some View {
        VStack(spacing: 48) {
            VStack(spacing: 8) {
                Text("PONG")
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentCyan, accentBlue, accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: accentBlue.opacity(0.6), radius: 20, x: 0, y: 0)
                    .shadow(color: accentCyan.opacity(0.4), radius: 40, x: 0, y: 0)

                Text("CLASSIC ARCADE")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(4)
            }

            Button(action: pongStartGame) {
                Text("TAP TO START")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [accentCyan.opacity(0.8), accentPurple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .shadow(color: accentBlue.opacity(0.4), radius: 20, x: 0, y: 0)
            }

            VStack(spacing: 8) {
                Text("Drag right side to control your paddle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                Text("First to 5 wins")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .shadow(color: accentPurple.opacity(0.3), radius: 30, x: 0, y: 10)
        )
        .padding(32)
    }

    // MARK: - Game Over Screen
    private var pongGameOverScreen: some View {
        VStack(spacing: 32) {
            Text(winnerText)
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: winnerText == "YOU WIN!" ? [accentCyan, accentBlue] : [Color.red.opacity(0.8), accentPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: (winnerText == "YOU WIN!" ? accentCyan : Color.red).opacity(0.5), radius: 20)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("AI")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(2)
                    Text("\(aiScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Text("—")
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                VStack(spacing: 4) {
                    Text("YOU")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(2)
                    Text("\(playerScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            Button(action: pongRestartGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [accentCyan.opacity(0.8), accentPurple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .shadow(color: accentBlue.opacity(0.4), radius: 20, x: 0, y: 0)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .shadow(color: accentPurple.opacity(0.3), radius: 30, x: 0, y: 10)
        )
        .padding(32)
    }

    // MARK: - Game Canvas
    private func pongGameCanvas(size: CGSize) -> some View {
        ZStack {
            Canvas { context, canvasSize in
                // Center dashed line (glowing)
                let dashHeight: CGFloat = 16
                let dashGap: CGFloat = 10
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let rect = CGRect(x: canvasSize.width / 2 - 2, y: y, width: 4, height: dashHeight)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3))
                    )
                    y += dashHeight + dashGap
                }

                // AI paddle glow
                let aiPaddleRect = CGRect(
                    x: paddleInset,
                    y: aiY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                // Glow layer
                context.fill(
                    Path(roundedRect: aiPaddleRect.insetBy(dx: -6, dy: -6), cornerRadius: (paddleWidth + 12) / 2),
                    with: .color(Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.25))
                )
                context.fill(
                    Path(roundedRect: aiPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(Color(red: 0.7, green: 0.4, blue: 1.0))
                )

                // Player paddle glow
                let playerPaddleRect = CGRect(
                    x: canvasSize.width - paddleInset - paddleWidth,
                    y: playerY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect.insetBy(dx: -6, dy: -6), cornerRadius: (paddleWidth + 12) / 2),
                    with: .color(Color(red: 0.0, green: 0.7, blue: 1.0).opacity(0.25))
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(Color(red: 0.2, green: 0.8, blue: 1.0))
                )

                // Ball glow layers
                let ballRect = CGRect(
                    x: ballPos.x - ballRadius,
                    y: ballPos.y - ballRadius,
                    width: ballRadius * 2,
                    height: ballRadius * 2
                )
                let glowRect1 = ballRect.insetBy(dx: -12, dy: -12)
                let glowRect2 = ballRect.insetBy(dx: -6, dy: -6)
                context.fill(Path(ellipseIn: glowRect1), with: .color(accentCyan.opacity(0.15)))
                context.fill(Path(ellipseIn: glowRect2), with: .color(accentCyan.opacity(0.3)))
                context.fill(Path(ellipseIn: ballRect), with: .color(Color.white))
            }
            .frame(width: size.width, height: size.height)

            // Score overlay
            VStack {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("AI")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .kerning(3)
                        Text("\(aiScore)")
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: accentPurple.opacity(0.6), radius: 10)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("YOU")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .kerning(3)
                        Text("\(playerScore)")
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: accentCyan.opacity(0.6), radius: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)

                Spacer()

                Text("DRAG TO MOVE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
                    .kerning(2)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Game Logic
    private func pongStartGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        isPlaying = true
    }

    private func pongRestartGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        winnerText = ""
        isPlaying = true
    }

    private func pongResetBall(size: CGSize) {
        ballPos = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx: CGFloat = Bool.random() ? 4 : -4
        let dy: CGFloat = Bool.random() ? 3 : -3
        ballVel = CGVector(dx: dx, dy: dy)
    }

    private func pongUpdateGame(size: CGSize) {
        ballPos.x += ballVel.dx
        ballPos.y += ballVel.dy

        // Wall bounce
        if ballPos.y - ballRadius <= 0 {
            ballPos.y = ballRadius
            ballVel.dy = abs(ballVel.dy)
        }
        if ballPos.y + ballRadius >= size.height {
            ballPos.y = size.height - ballRadius
            ballVel.dy = -abs(ballVel.dy)
        }

        // AI tracking
        let aiDiff = ballPos.y - aiY
        let aiMove = min(abs(aiDiff), aiSpeed) * (aiDiff > 0 ? 1 : -1)
        aiY = (aiY + aiMove).pongClamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))
        playerY = playerY.pongClamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))

        // Player paddle collision
        let playerPaddleX = size.width - paddleInset - paddleWidth
        if ballPos.x + ballRadius >= playerPaddleX &&
            ballPos.x + ballRadius <= playerPaddleX + paddleWidth + abs(ballVel.dx) &&
            ballPos.y >= playerY - paddleHeight / 2 &&
            ballPos.y <= playerY + paddleHeight / 2 &&
            ballVel.dx > 0 {
            ballPos.x = playerPaddleX - ballRadius
            ballVel.dx = -ballVel.dx
            pongSpeedUp()
        }

        // AI paddle collision
        let aiPaddleX = paddleInset + paddleWidth
        if ballPos.x - ballRadius <= aiPaddleX &&
            ballPos.x - ballRadius >= aiPaddleX - paddleWidth - abs(ballVel.dx) &&
            ballPos.y >= aiY - paddleHeight / 2 &&
            ballPos.y <= aiY + paddleHeight / 2 &&
            ballVel.dx < 0 {
            ballPos.x = aiPaddleX + ballRadius
            ballVel.dx = -ballVel.dx
            pongSpeedUp()
        }

        // Scoring
        if ballPos.x - ballRadius <= 0 {
            aiScore += 1
            pongCheckWin(size: size)
            if !gameOver { pongResetBall(size: size) }
        } else if ballPos.x + ballRadius >= size.width {
            playerScore += 1
            pongCheckWin(size: size)
            if !gameOver { pongResetBall(size: size) }
        }
    }

    private func pongSpeedUp() {
        let speed = sqrt(ballVel.dx * ballVel.dx + ballVel.dy * ballVel.dy)
        if speed < maxSpeed {
            ballVel.dx *= speedMultiplier
            ballVel.dy *= speedMultiplier
        }
    }

    private func pongCheckWin(size: CGSize) {
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

// MARK: - File-private clamping helper
private extension Comparable {
    func pongClamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGRect {
    func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x - dx, y: origin.y - dy, width: width + dx * 2, height: height + dy * 2)
    }
}
