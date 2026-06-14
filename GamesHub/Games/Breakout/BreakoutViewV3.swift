import SwiftUI

// MARK: - LCG Pseudo-Random Generator

struct BreakoutV3LCG {
    private var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        state = s == 0 ? 1 : s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextInRange(_ lo: Double, _ hi: Double) -> Double {
        lo + nextDouble() * (hi - lo)
    }

    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Data Models

struct BreakoutV3Brick: Identifiable {
    let id: UUID = UUID()
    var col: Int
    var row: Int
    var color: Color
    var isAlive: Bool = true
}

enum BreakoutV3GameState {
    case waiting
    case playing
    case paused
    case gameOver
    case won
}

// MARK: - Constants

private enum BreakoutV3Constants {
    static let rows = 5
    static let cols = 8
    static let brickHeight: CGFloat = 28
    static let brickSpacing: CGFloat = 6
    static let brickTopPadding: CGFloat = 80
    static let paddleHeight: CGFloat = 14
    static let paddleWidth: CGFloat = 90
    static let ballRadius: CGFloat = 10
    static let ballSpeed: CGFloat = 380
    static let lives = 3
    static let scorePerBrick = 10
}

// MARK: - Neumorphic Paddle View

struct BreakoutV3Paddle: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: BreakoutV3Constants.paddleHeight / 2)
            .fill(Color(.systemGray6))
            .frame(width: width, height: BreakoutV3Constants.paddleHeight)
            .shadow(color: .white.opacity(0.9), radius: 5, x: -3, y: -3)
            .shadow(color: Color(.systemGray3).opacity(0.8), radius: 5, x: 3, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: BreakoutV3Constants.paddleHeight / 2)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color(.systemGray4).opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Neumorphic Ball View

struct BreakoutV3Ball: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .white.opacity(0.9), radius: 4, x: -2, y: -2)
                .shadow(color: Color(.systemGray3).opacity(0.8), radius: 4, x: 2, y: 2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(.systemGray4), Color(.systemGray6)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: radius * 1.5
                    )
                )
                .frame(width: radius * 1.5, height: radius * 1.5)

            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: radius * 1.1, height: radius * 1.1)
                .offset(x: -1.5, y: -1.5)
        }
    }
}

// MARK: - Neumorphic Brick View

struct BreakoutV3BrickView: View {
    let brick: BreakoutV3Brick
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: Color(.systemGray3).opacity(0.7), radius: 4, x: 2, y: 2)

            RoundedRectangle(cornerRadius: 7)
                .fill(brick.color.opacity(0.25))

            RoundedRectangle(cornerRadius: 7)
                .stroke(brick.color.opacity(0.5), lineWidth: 1.5)

            // Highlight strip at top
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(.horizontal, 3)
                .padding(.top, 2)
                .frame(height: height * 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Main View

struct BreakoutViewV3: View {

    // MARK: Seed & Generation
    @State var seedInt: Int = 1
    @State private var lcg: BreakoutV3LCG = BreakoutV3LCG(seed: 1)

    // MARK: Game State
    @State private var gameState: BreakoutV3GameState = .waiting
    @State private var bricks: [BreakoutV3Brick] = []
    @State private var score: Int = 0
    @State private var lives: Int = BreakoutV3Constants.lives

    // MARK: Ball
    @State private var ballPosition: CGPoint = .zero
    @State private var ballVelocity: CGPoint = .zero

    // MARK: Paddle
    @State private var paddleX: CGFloat = 0

    // MARK: Layout
    @State private var screenSize: CGSize = .zero
    @State private var gameLoopTimer: Timer? = nil

    // MARK: Drag State
    @State private var dragStartX: CGFloat = 0
    @State private var paddleStartX: CGFloat = 0

    private let frameInterval: Double = 1.0 / 60.0

    // Palette of neumorphic-friendly accent colors
    private let brickPalette: [Color] = [
        Color(red: 0.85, green: 0.35, blue: 0.35),  // red
        Color(red: 0.85, green: 0.60, blue: 0.25),  // orange
        Color(red: 0.75, green: 0.75, blue: 0.25),  // yellow
        Color(red: 0.30, green: 0.70, blue: 0.45),  // green
        Color(red: 0.30, green: 0.55, blue: 0.80),  // blue
        Color(red: 0.55, green: 0.35, blue: 0.75),  // purple
        Color(red: 0.75, green: 0.35, blue: 0.65),  // pink
        Color(red: 0.30, green: 0.70, blue: 0.75),  // teal
    ]

    // MARK: Layout Helpers

    private func brickWidth(in size: CGSize) -> CGFloat {
        let totalSpacing = BreakoutV3Constants.brickSpacing * CGFloat(BreakoutV3Constants.cols + 1)
        return (size.width - totalSpacing) / CGFloat(BreakoutV3Constants.cols)
    }

    private func brickRect(col: Int, row: Int, in size: CGSize) -> CGRect {
        let w = brickWidth(in: size)
        let h = BreakoutV3Constants.brickHeight
        let spacing = BreakoutV3Constants.brickSpacing
        let x = spacing + CGFloat(col) * (w + spacing)
        let y = BreakoutV3Constants.brickTopPadding + CGFloat(row) * (h + spacing)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func brickCenter(col: Int, row: Int, in size: CGSize) -> CGPoint {
        let rect = brickRect(col: col, row: row, in: size)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private var paddleY: CGFloat {
        screenSize.height - 60
    }

    private var paddleHalfWidth: CGFloat {
        BreakoutV3Constants.paddleWidth / 2
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                // MARK: Bricks
                ForEach(bricks.filter { $0.isAlive }) { brick in
                    let center = brickCenter(col: brick.col, row: brick.row, in: geo.size)
                    BreakoutV3BrickView(
                        brick: brick,
                        width: brickWidth(in: geo.size),
                        height: BreakoutV3Constants.brickHeight
                    )
                    .position(center)
                }

                // MARK: Ball
                if gameState == .playing || gameState == .paused {
                    BreakoutV3Ball(radius: BreakoutV3Constants.ballRadius)
                        .position(ballPosition)
                }

                // MARK: Paddle
                if gameState == .playing || gameState == .paused {
                    BreakoutV3Paddle(width: BreakoutV3Constants.paddleWidth)
                        .position(x: paddleX, y: paddleY)
                }

                // MARK: HUD
                VStack {
                    hudBar
                    Spacer()
                }

                // MARK: Seed Badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        seedBadge
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }

                // MARK: Overlays
                if gameState == .waiting {
                    waitingOverlay
                }
                if gameState == .gameOver {
                    gameOverOverlay
                }
                if gameState == .won {
                    wonOverlay
                }
            }
            .onAppear {
                screenSize = geo.size
                paddleX = geo.size.width / 2
                ballPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height - 200)
            }
            .onChange(of: geo.size) {
                screenSize = geo.size
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { _ in
                        // Tap to start on waiting state
                        if gameState == .waiting {
                            startGame()
                        }
                    }
            )
        }
    }

    // MARK: - Drag Handling

    private func handleDragChanged(_ value: DragGesture.Value) {
        if gameState == .waiting {
            return
        }
        if gameState == .playing {
            let delta = value.location.x - value.startLocation.x
            let newX = paddleStartX + delta
            paddleX = max(paddleHalfWidth, min(screenSize.width - paddleHalfWidth, newX))
        }
    }

    // MARK: - UI Components

    private var hudBar: some View {
        HStack {
            // Score
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .tracking(2)
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
            }
            Spacer()
            // Seed
            VStack(spacing: 2) {
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.35, green: 0.45, blue: 0.65))
            }
            Spacer()
            // Lives
            VStack(alignment: .trailing, spacing: 2) {
                Text("LIVES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .tracking(2)
                HStack(spacing: 4) {
                    ForEach(0..<BreakoutV3Constants.lives, id: \.self) { i in
                        Circle()
                            .fill(i < lives
                                  ? Color(red: 0.85, green: 0.35, blue: 0.35)
                                  : Color(.systemGray5))
                            .frame(width: 10, height: 10)
                            .shadow(color: i < lives
                                    ? Color(red: 0.85, green: 0.35, blue: 0.35).opacity(0.5)
                                    : Color.clear,
                                    radius: 3, x: 0, y: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .neumorphicCard(radius: 20)
        .padding(.horizontal, 16)
        .padding(.top, 52)
    }

    private var seedBadge: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(Color(.systemGray))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .neumorphicCard(radius: 8)
    }

    private var waitingOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.85).ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("BREAKOUT")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))
                    Text("V3 — SEEDED")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(Color(.systemGray))
                }

                VStack(spacing: 8) {
                    Text("Drag paddle to move")
                        .font(.system(size: 15))
                        .foregroundColor(Color(.secondaryLabel))
                    Text("Seed determines brick colors & ball angle")
                        .font(.system(size: 13))
                        .foregroundColor(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.35, green: 0.45, blue: 0.65))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 14)

                Text("Tap to Start")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.75, green: 0.25, blue: 0.25))

                VStack(spacing: 6) {
                    Text("Score: \(score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    Text("Seed #\(seedInt)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(.systemGray2))
                }

                Button(action: restartGame) {
                    Text("Next Seed")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 30)
                }
            }
        }
    }

    private var wonOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("YOU WIN!")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.25, green: 0.65, blue: 0.35))

                VStack(spacing: 6) {
                    Text("Score: \(score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    Text("Seed #\(seedInt) cleared!")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(.systemGray2))
                }

                Button(action: restartGame) {
                    Text("Next Seed")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 30)
                }
            }
        }
    }

    // MARK: - Game Lifecycle

    private func startGame() {
        stopTimer()
        lcg = BreakoutV3LCG(seed: seedInt)
        bricks = generateBricks()
        score = 0
        lives = BreakoutV3Constants.lives
        paddleX = screenSize.width / 2
        paddleStartX = screenSize.width / 2
        resetBall()
        gameState = .playing
        startTimer()
    }

    private func restartGame() {
        stopTimer()
        seedInt += 1
        startGame()
    }

    private func resetBall() {
        ballPosition = CGPoint(x: paddleX, y: screenSize.height - 120)
        // Use LCG to determine starting angle: between -60° and 60° from straight up
        let angleDeg = lcg.nextInRange(-60, 60)
        let angleRad = angleDeg * Double.pi / 180.0
        let speed = Double(BreakoutV3Constants.ballSpeed)
        // Negative Y = upward
        ballVelocity = CGPoint(
            x: CGFloat(speed * sin(angleRad)),
            y: CGFloat(-speed * cos(angleRad))
        )
    }

    private func generateBricks() -> [BreakoutV3Brick] {
        var result: [BreakoutV3Brick] = []
        for row in 0..<BreakoutV3Constants.rows {
            for col in 0..<BreakoutV3Constants.cols {
                let colorIndex = lcg.nextInt(brickPalette.count)
                let color = brickPalette[colorIndex]
                result.append(BreakoutV3Brick(col: col, row: row, color: color))
            }
        }
        return result
    }

    // MARK: - Timer

    private func startTimer() {
        gameLoopTimer = Timer(timeInterval: frameInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            updatePhysics()
        }
        if let t = gameLoopTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func stopTimer() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
    }

    // MARK: - Physics Update

    private func updatePhysics() {
        let dt = CGFloat(frameInterval)
        let r = BreakoutV3Constants.ballRadius
        let size = screenSize

        // Move ball
        var newPos = CGPoint(
            x: ballPosition.x + ballVelocity.x * dt,
            y: ballPosition.y + ballVelocity.y * dt
        )
        var vel = ballVelocity

        // Left / Right wall bounce
        if newPos.x - r < 0 {
            newPos.x = r
            vel.x = abs(vel.x)
        } else if newPos.x + r > size.width {
            newPos.x = size.width - r
            vel.x = -abs(vel.x)
        }

        // Top wall bounce
        if newPos.y - r < 0 {
            newPos.y = r
            vel.y = abs(vel.y)
        }

        // Ball falls below paddle => lose life
        if newPos.y - r > size.height {
            lives -= 1
            if lives <= 0 {
                stopTimer()
                gameState = .gameOver
                return
            } else {
                // Reset ball position on paddle
                paddleStartX = paddleX
                resetBall()
                ballPosition = CGPoint(x: paddleX, y: size.height - 120)
                return
            }
        }

        // Paddle collision
        let paddleRect = CGRect(
            x: paddleX - paddleHalfWidth,
            y: paddleY - BreakoutV3Constants.paddleHeight / 2,
            width: BreakoutV3Constants.paddleWidth,
            height: BreakoutV3Constants.paddleHeight
        )

        if vel.y > 0 &&
            newPos.y + r >= paddleRect.minY &&
            newPos.y - r <= paddleRect.maxY &&
            newPos.x >= paddleRect.minX &&
            newPos.x <= paddleRect.maxX {
            // Reflect upward
            vel.y = -abs(vel.y)
            newPos.y = paddleRect.minY - r

            // Add slight spin based on hit position relative to paddle center
            let hitOffset = (newPos.x - paddleX) / paddleHalfWidth  // -1 to 1
            vel.x = vel.x + hitOffset * 60
            // Clamp speed
            let currentSpeed = sqrt(vel.x * vel.x + vel.y * vel.y)
            let targetSpeed = BreakoutV3Constants.ballSpeed
            if currentSpeed > 0 {
                vel.x = vel.x / currentSpeed * targetSpeed
                vel.y = vel.y / currentSpeed * targetSpeed
            }
        }

        // Brick collision
        for i in bricks.indices {
            guard bricks[i].isAlive else { continue }
            let rect = brickRect(col: bricks[i].col, row: bricks[i].row, in: size)

            // Expanded rect for collision check
            let expandedRect = rect.insetBy(dx: -r, dy: -r)
            guard expandedRect.contains(newPos) else { continue }

            // Hit this brick
            bricks[i].isAlive = false
            score += BreakoutV3Constants.scorePerBrick

            // Determine bounce axis: which side did ball enter from?
            let overlapLeft = newPos.x - rect.minX
            let overlapRight = rect.maxX - newPos.x
            let overlapTop = newPos.y - rect.minY
            let overlapBottom = rect.maxY - newPos.y

            let minOverlap = min(overlapLeft, overlapRight, overlapTop, overlapBottom)

            if minOverlap == overlapTop || minOverlap == overlapBottom {
                vel.y = -vel.y
            } else {
                vel.x = -vel.x
            }
            break // Only hit one brick per frame
        }

        ballPosition = newPos
        ballVelocity = vel

        // Update paddle drag start tracking continuously
        paddleStartX = paddleX

        // Check win
        if bricks.allSatisfy({ !$0.isAlive }) {
            stopTimer()
            gameState = .won
        }
    }
}

// MARK: - Preview

#Preview {
    BreakoutViewV3()
}
