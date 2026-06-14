import SwiftUI

// MARK: - Neumorphic helper (file-private so it doesn't conflict with any shared Extensions.swift)
private struct PongV3NeumorphicCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemGray6))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
            .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }
}

private extension View {
    func pongV3NeumorphicCard() -> some View {
        modifier(PongV3NeumorphicCard())
    }
}

struct PongViewV3: View {
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

    // MARK: - Neumorphic palette
    private let bgColor = Color(.systemGray6)
    private let primaryText = Color(.label)
    private let accentColor = Color(red: 0.25, green: 0.50, blue: 0.90)
    private let aiPaddleColor = Color(red: 0.65, green: 0.35, blue: 0.85)

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                bgColor.ignoresSafeArea()

                if !isPlaying && !gameOver {
                    pongV3StartScreen
                } else if gameOver {
                    pongV3GameOverScreen
                } else {
                    pongV3GameCanvas(size: size)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    playerY = value.location.y
                                }
                        )
                }
            }
            .onAppear {
                pongV3ResetBall(size: size)
                playerY = size.height / 2
                aiY = size.height / 2
            }
            .onReceive(timer) { _ in
                guard isPlaying && !gameOver else { return }
                pongV3UpdateGame(size: size)
            }
        }
    }

    // MARK: - Start Screen
    private var pongV3StartScreen: some View {
        VStack(spacing: 48) {
            VStack(spacing: 10) {
                Text("PONG")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text("CLASSIC")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryText.opacity(0.35))
                    .kerning(6)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(bgColor)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 6, y: 6)
                    .shadow(color: .white.opacity(0.7), radius: 12, x: -6, y: -6)
            )

            Button(action: pongV3StartGame) {
                Text("TAP TO START")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(bgColor)
                                .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                                .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
                            // Inset pressed effect border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                        }
                    )
            }

            VStack(spacing: 6) {
                Text("Drag right side to control your paddle")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(primaryText.opacity(0.4))
                Text("First to 5 wins")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(primaryText.opacity(0.4))
            }
        }
        .padding(32)
    }

    // MARK: - Game Over Screen
    private var pongV3GameOverScreen: some View {
        VStack(spacing: 36) {
            Text(winnerText)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(winnerText == "YOU WIN!" ? accentColor : Color(red: 0.85, green: 0.25, blue: 0.25))
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(bgColor)
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 5, y: 5)
                        .shadow(color: .white.opacity(0.7), radius: 10, x: -5, y: -5)
                )

            // Score card
            HStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("AI")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryText.opacity(0.45))
                        .kerning(3)
                    Text("\(aiScore)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(aiPaddleColor)
                }
                Text("—")
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundColor(primaryText.opacity(0.25))
                VStack(spacing: 6) {
                    Text("YOU")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(primaryText.opacity(0.45))
                        .kerning(3)
                    Text("\(playerScore)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(accentColor)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(bgColor)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 5, y: 5)
                    .shadow(color: .white.opacity(0.7), radius: 10, x: -5, y: -5)
            )

            Button(action: pongV3RestartGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(bgColor)
                                .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                                .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                        }
                    )
            }
        }
        .padding(32)
    }

    // MARK: - Game Canvas
    private func pongV3GameCanvas(size: CGSize) -> some View {
        ZStack {
            Canvas { context, canvasSize in
                // Inset field area (neumorphic inset)
                let fieldRect = CGRect(x: 8, y: 8, width: canvasSize.width - 16, height: canvasSize.height - 16)
                // Outer shadow (dark)
                context.fill(
                    Path(roundedRect: fieldRect.offsetBy(dx: 3, dy: 3), cornerRadius: 20),
                    with: .color(Color.black.opacity(0.10))
                )
                // Inner light
                context.fill(
                    Path(roundedRect: fieldRect.offsetBy(dx: -3, dy: -3), cornerRadius: 20),
                    with: .color(Color.white.opacity(0.55))
                )
                // Field
                context.fill(
                    Path(roundedRect: fieldRect, cornerRadius: 20),
                    with: .color(Color(.systemGray6))
                )

                // Dividing center line (subtle)
                let dashHeight: CGFloat = 14
                let dashGap: CGFloat = 10
                var y: CGFloat = fieldRect.minY + 16
                while y < fieldRect.maxY - 16 {
                    let rect = CGRect(x: canvasSize.width / 2 - 2, y: y, width: 4, height: dashHeight)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(Color(.systemGray4).opacity(0.6))
                    )
                    y += dashHeight + dashGap
                }

                // AI paddle (neumorphic raised pill)
                let aiPaddleRect = CGRect(
                    x: paddleInset,
                    y: aiY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                // Shadow layers
                context.fill(
                    Path(roundedRect: aiPaddleRect.offsetBy(dx: 3, dy: 3), cornerRadius: paddleWidth / 2),
                    with: .color(Color.black.opacity(0.18))
                )
                context.fill(
                    Path(roundedRect: aiPaddleRect.offsetBy(dx: -3, dy: -3), cornerRadius: paddleWidth / 2),
                    with: .color(Color.white.opacity(0.70))
                )
                context.fill(
                    Path(roundedRect: aiPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(Color(red: 0.65, green: 0.35, blue: 0.85))
                )

                // Player paddle (neumorphic raised pill)
                let playerPaddleRect = CGRect(
                    x: canvasSize.width - paddleInset - paddleWidth,
                    y: playerY - paddleHeight / 2,
                    width: paddleWidth,
                    height: paddleHeight
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect.offsetBy(dx: 3, dy: 3), cornerRadius: paddleWidth / 2),
                    with: .color(Color.black.opacity(0.18))
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect.offsetBy(dx: -3, dy: -3), cornerRadius: paddleWidth / 2),
                    with: .color(Color.white.opacity(0.70))
                )
                context.fill(
                    Path(roundedRect: playerPaddleRect, cornerRadius: paddleWidth / 2),
                    with: .color(Color(red: 0.25, green: 0.50, blue: 0.90))
                )

                // Ball (raised neumorphic circle)
                let ballRect = CGRect(
                    x: ballPos.x - ballRadius,
                    y: ballPos.y - ballRadius,
                    width: ballRadius * 2,
                    height: ballRadius * 2
                )
                context.fill(
                    Path(ellipseIn: ballRect.offsetBy(dx: 3, dy: 3)),
                    with: .color(Color.black.opacity(0.15))
                )
                context.fill(
                    Path(ellipseIn: ballRect.offsetBy(dx: -3, dy: -3)),
                    with: .color(Color.white.opacity(0.70))
                )
                context.fill(
                    Path(ellipseIn: ballRect),
                    with: .color(Color(.label))
                )
            }
            .frame(width: size.width, height: size.height)

            // Score overlay
            VStack {
                HStack(spacing: 0) {
                    pongV3ScoreCard(label: "AI", score: aiScore, color: aiPaddleColor)
                        .frame(maxWidth: .infinity)

                    pongV3ScoreCard(label: "YOU", score: playerScore, color: accentColor)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 50)
                .padding(.horizontal, 16)

                Spacer()

                Text("DRAG TO MOVE")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(primaryText.opacity(0.25))
                    .kerning(2)
                    .padding(.bottom, 24)
            }
        }
    }

    private func pongV3ScoreCard(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(primaryText.opacity(0.35))
                .kerning(3)
            Text("\(score)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(bgColor)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
        )
    }

    // MARK: - Game Logic
    private func pongV3StartGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        isPlaying = true
    }

    private func pongV3RestartGame() {
        playerScore = 0
        aiScore = 0
        gameOver = false
        winnerText = ""
        isPlaying = true
    }

    private func pongV3ResetBall(size: CGSize) {
        ballPos = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx: CGFloat = Bool.random() ? 4 : -4
        let dy: CGFloat = Bool.random() ? 3 : -3
        ballVel = CGVector(dx: dx, dy: dy)
    }

    private func pongV3UpdateGame(size: CGSize) {
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
        aiY = (aiY + aiMove).pongV3Clamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))
        playerY = playerY.pongV3Clamped(to: paddleHeight / 2...(size.height - paddleHeight / 2))

        // Player paddle collision
        let playerPaddleX = size.width - paddleInset - paddleWidth
        if ballPos.x + ballRadius >= playerPaddleX &&
            ballPos.x + ballRadius <= playerPaddleX + paddleWidth + abs(ballVel.dx) &&
            ballPos.y >= playerY - paddleHeight / 2 &&
            ballPos.y <= playerY + paddleHeight / 2 &&
            ballVel.dx > 0 {
            ballPos.x = playerPaddleX - ballRadius
            ballVel.dx = -ballVel.dx
            pongV3SpeedUp()
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
            pongV3SpeedUp()
        }

        // Scoring
        if ballPos.x - ballRadius <= 0 {
            aiScore += 1
            pongV3CheckWin(size: size)
            if !gameOver { pongV3ResetBall(size: size) }
        } else if ballPos.x + ballRadius >= size.width {
            playerScore += 1
            pongV3CheckWin(size: size)
            if !gameOver { pongV3ResetBall(size: size) }
        }
    }

    private func pongV3SpeedUp() {
        let speed = sqrt(ballVel.dx * ballVel.dx + ballVel.dy * ballVel.dy)
        if speed < maxSpeed {
            ballVel.dx *= speedMultiplier
            ballVel.dy *= speedMultiplier
        }
    }

    private func pongV3CheckWin(size: CGSize) {
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
    func pongV3Clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGRect {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: width, height: height)
    }
}
