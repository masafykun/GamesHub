import SwiftUI

struct BreakoutView: View {
    @StateObject private var gameState = BreakoutGameState()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Bricks
                ForEach(gameState.bricks) { brick in
                    if brick.isAlive {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(brick.color)
                            .frame(width: brick.size.width, height: brick.size.height)
                            .position(brick.position)
                    }
                }

                // Ball
                Circle()
                    .fill(Color.white)
                    .frame(width: gameState.ballRadius * 2, height: gameState.ballRadius * 2)
                    .position(gameState.ballPosition)

                // Paddle
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyan)
                    .frame(width: gameState.paddleWidth, height: gameState.paddleHeight)
                    .position(CGPoint(x: gameState.paddleX, y: gameState.paddleY))

                // HUD
                VStack {
                    HStack {
                        Text("Score: \(gameState.score)")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.leading, 16)
                        Spacer()
                        Text("Lives: \(gameState.lives)")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.trailing, 16)
                    }
                    .padding(.top, 8)
                    Spacer()
                }

                // Overlay messages
                if gameState.phase == .waiting {
                    VStack(spacing: 16) {
                        Text("BREAKOUT")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.cyan)
                        Text("Drag paddle to move\nTap to launch ball")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        Button("Start") {
                            gameState.startGame(in: geo.size)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }

                if gameState.phase == .won {
                    VStack(spacing: 16) {
                        Text("YOU WIN!")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.yellow)
                        Text("Score: \(gameState.score)")
                            .foregroundColor(.white)
                            .font(.title2)
                        Button("Play Again") {
                            gameState.startGame(in: geo.size)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }

                if gameState.phase == .lost {
                    VStack(spacing: 16) {
                        Text("GAME OVER")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.red)
                        Text("Score: \(gameState.score)")
                            .foregroundColor(.white)
                            .font(.title2)
                        Button("Try Again") {
                            gameState.startGame(in: geo.size)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .onAppear {
                gameState.setupField(in: geo.size)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        gameState.movePaddle(to: value.location.x, in: geo.size)
                    }
            )
            .onTapGesture {
                if gameState.phase == .paused {
                    gameState.launchBall()
                }
            }
        }
    }
}

enum BreakoutPhase {
    case waiting, paused, playing, won, lost
}

struct BreakoutBrick: Identifiable {
    let id: Int
    var position: CGPoint
    var size: CGSize
    var color: Color
    var isAlive: Bool = true
    var rect: CGRect { CGRect(origin: position, size: size) }
}

class BreakoutGameState: ObservableObject {
    @Published var bricks: [BreakoutBrick] = []
    @Published var ballPosition: CGPoint = .zero
    @Published var paddleX: CGFloat = 0
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var phase: BreakoutPhase = .waiting

    let paddleWidth: CGFloat = 90
    let paddleHeight: CGFloat = 14
    let ballRadius: CGFloat = 10

    var paddleY: CGFloat = 0
    var ballVelocity: CGPoint = .zero
    var fieldSize: CGSize = .zero

    private var timer: Timer?

    func setupField(in size: CGSize) {
        fieldSize = size
        paddleX = size.width / 2
        paddleY = size.height - 60
        ballPosition = CGPoint(x: size.width / 2, y: paddleY - ballRadius - 1)
        setupBricks(in: size)
    }

    func setupBricks(in size: CGSize) {
        let rows = 5
        let cols = 8
        let topOffset: CGFloat = 80
        let hPad: CGFloat = 8
        let vPad: CGFloat = 6
        let brickWidth = (size.width - hPad * CGFloat(cols + 1)) / CGFloat(cols)
        let brickHeight: CGFloat = 22

        let rowColors: [Color] = [.red, .orange, .yellow, .green, .blue]
        var brickList: [BreakoutBrick] = []
        var idCounter = 0

        for row in 0..<rows {
            for col in 0..<cols {
                let x = hPad + CGFloat(col) * (brickWidth + hPad) + brickWidth / 2
                let y = topOffset + CGFloat(row) * (brickHeight + vPad) + brickHeight / 2
                brickList.append(BreakoutBrick(
                    id: idCounter,
                    position: CGPoint(x: x, y: y),
                    size: CGSize(width: brickWidth, height: brickHeight),
                    color: rowColors[row % rowColors.count]
                ))
                idCounter += 1
            }
        }
        bricks = brickList
    }

    func startGame(in size: CGSize) {
        score = 0
        lives = 3
        fieldSize = size
        paddleX = size.width / 2
        paddleY = size.height - 60
        ballPosition = CGPoint(x: size.width / 2, y: paddleY - ballRadius - 1)
        ballVelocity = .zero
        setupBricks(in: size)
        phase = .paused
        stopTimer()
    }

    func launchBall() {
        guard phase == .paused else { return }
        let angle = CGFloat.random(in: -0.6...0.6)
        let speed: CGFloat = 5.5
        ballVelocity = CGPoint(x: sin(angle) * speed, y: -cos(angle) * speed)
        phase = .playing
        startTimer()
    }

    func movePaddle(to x: CGFloat, in size: CGSize) {
        let half = paddleWidth / 2
        paddleX = min(max(x, half), size.width - half)

        if phase == .paused {
            ballPosition = CGPoint(x: paddleX, y: paddleY - ballRadius - 1)
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard phase == .playing else { return }

        var pos = ballPosition
        var vel = ballVelocity

        pos.x += vel.x
        pos.y += vel.y

        let width = fieldSize.width
        let height = fieldSize.height

        // Wall bounce left/right
        if pos.x - ballRadius <= 0 {
            pos.x = ballRadius
            vel.x = abs(vel.x)
        } else if pos.x + ballRadius >= width {
            pos.x = width - ballRadius
            vel.x = -abs(vel.x)
        }

        // Ceiling bounce
        if pos.y - ballRadius <= 0 {
            pos.y = ballRadius
            vel.y = abs(vel.y)
        }

        // Paddle collision
        let paddleLeft = paddleX - paddleWidth / 2
        let paddleRight = paddleX + paddleWidth / 2
        let paddleTop = paddleY - paddleHeight / 2

        if vel.y > 0
            && pos.y + ballRadius >= paddleTop
            && pos.y + ballRadius <= paddleTop + paddleHeight
            && pos.x >= paddleLeft
            && pos.x <= paddleRight {

            pos.y = paddleTop - ballRadius
            // Vary angle based on hit position
            let hitFraction = (pos.x - paddleLeft) / paddleWidth  // 0..1
            let angle = (hitFraction - 0.5) * 1.4  // -0.7..0.7 radians
            let speed = sqrt(vel.x * vel.x + vel.y * vel.y)
            vel.x = sin(angle) * speed
            vel.y = -abs(cos(angle) * speed)
        }

        // Ball fell below paddle
        if pos.y - ballRadius > height {
            lives -= 1
            if lives <= 0 {
                phase = .lost
                stopTimer()
            } else {
                // Reset ball
                phase = .paused
                stopTimer()
                ballPosition = CGPoint(x: paddleX, y: paddleY - ballRadius - 1)
                ballVelocity = .zero
            }
            return
        }

        // Brick collision
        for i in bricks.indices where bricks[i].isAlive {
            let brick = bricks[i]
            let bLeft = brick.position.x - brick.size.width / 2
            let bRight = brick.position.x + brick.size.width / 2
            let bTop = brick.position.y - brick.size.height / 2
            let bBottom = brick.position.y + brick.size.height / 2

            if pos.x + ballRadius > bLeft
                && pos.x - ballRadius < bRight
                && pos.y + ballRadius > bTop
                && pos.y - ballRadius < bBottom {

                bricks[i].isAlive = false
                score += 10

                // Determine bounce direction
                let overlapLeft = (pos.x + ballRadius) - bLeft
                let overlapRight = bRight - (pos.x - ballRadius)
                let overlapTop = (pos.y + ballRadius) - bTop
                let overlapBottom = bBottom - (pos.y - ballRadius)

                let minOverlap = min(overlapLeft, overlapRight, overlapTop, overlapBottom)

                if minOverlap == overlapTop || minOverlap == overlapBottom {
                    vel.y = -vel.y
                } else {
                    vel.x = -vel.x
                }

                break
            }
        }

        // Check win condition
        if bricks.allSatisfy({ !$0.isAlive }) {
            phase = .won
            stopTimer()
            return
        }

        ballPosition = pos
        ballVelocity = vel
    }
}
