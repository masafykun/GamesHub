import SwiftUI

// MARK: - Obstacle Model

struct GravitySwitchObstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var gapY: CGFloat
    var gapHeight: CGFloat
}


// MARK: - Models

extension GravitySwitchObstacle {
    var gapSize: CGFloat { gapHeight }
    var barWidth: CGFloat { 22 }
}

enum GravitySwitchDifficulty: String {
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

    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }
}

enum GravitySwitchGameState {
    case idle, playing, gameOver
}

// MARK: - Main View

struct GravitySwitchView: View {

    // MARK: Persistent difficulty tracking
    @State var roundScores: [Int] = []
    @AppStorage("gravitySwitchBestScore") private var bestScore: Int = 0

    // MARK: Game state
    @State private var gameState: GravitySwitchGameState = .idle
    @State private var score: Int = 0
    @State private var frameCount: Int = 0

    // MARK: Player
    @State private var playerY: CGFloat = 0
    @State private var playerVelocity: CGFloat = 0
    @State private var gravityDown: Bool = true      // true = falls down, false = falls up

    // MARK: Obstacles
    @State private var obstacles: [GravitySwitchObstacle] = []
    @State private var nextObstacleX: CGFloat = 0

    // MARK: Timer
    @State private var gameTimer: Timer? = nil

    // MARK: Adaptive difficulty parameters
    @State private var baseSpeed: CGFloat = 140       // pts/sec horizontal scroll
    @State private var gapSize: CGFloat = 180         // gap height in pts
    @State private var obstacleSpacing: CGFloat = 300 // horizontal distance between obstacles

    // MARK: Physics constants
    private let gravityStrength: CGFloat = 900
    private let flipImpulse: CGFloat = 480
    private let playerSize: CGFloat = 28
    private let wallMargin: CGFloat = 50              // safe zone from top/bottom edges

    // MARK: Computed difficulty
    private var difficulty: GravitySwitchDifficulty {
        computeDifficulty(from: roundScores)
    }

    private func computeDifficulty(from scores: [Int]) -> GravitySwitchDifficulty {
        guard !scores.isEmpty else { return .easy }
        let avg = scores.reduce(0, +) / scores.count
        if avg >= 300 { return .hard }
        if avg >= 120 { return .medium }
        return .easy
    }

    private var currentSpeed: CGFloat {
        // Speed ramps up with distance
        let ramp = CGFloat(score) / 600.0
        return baseSpeed + ramp * 100
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Animated gradient background
                GravitySwitchBackground(gravityDown: gravityDown)
                    .ignoresSafeArea()

                // Game entities
                if gameState == .playing || gameState == .gameOver {
                    // Obstacles
                    ForEach(obstacles) { obs in
                        GravitySwitchObstacleView(
                            obstacle: obs,
                            height: height
                        )
                    }

                    // Player
                    GravitySwitchPlayerView(
                        size: playerSize,
                        gravityDown: gravityDown
                    )
                    .position(x: width * 0.25, y: playerY)
                }

                // HUD
                if gameState == .playing {
                    VStack {
                        GravitySwitchHUD(
                            score: score,
                            difficulty: difficulty,
                            gravityDown: gravityDown
                        )
                        Spacer()
                        GravitySwitchTapHint()
                            .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                }

                // Idle screen
                if gameState == .idle {
                    GravitySwitchStartScreen(
                        difficulty: difficulty,
                        roundScores: roundScores,
                        onStart: { startGame(in: geo.size) }
                    )
                }

                // Game over screen
                if gameState == .gameOver {
                    GravitySwitchGameOverScreen(
                        score: score,
                        difficulty: difficulty,
                        roundScores: roundScores
                    ) {
                        startGame(in: geo.size)
                    }
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        guard gameState == .playing else { return }
                        flipGravity()
                    }
            )
            .onAppear {
                playerY = height / 2
            }
            .onDisappear {
                stopTimer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Gravity Flip

    private func flipGravity() {
        gravityDown.toggle()
        // Give an impulse in the new gravity direction
        playerVelocity = gravityDown ? flipImpulse * 0.4 : -flipImpulse * 0.4
    }

    // MARK: - Game Lifecycle

    private func startGame(in size: CGSize) {
        score = 0
        frameCount = 0
        playerY = size.height / 2
        playerVelocity = 0
        gravityDown = true
        obstacles = []
        nextObstacleX = size.width + 80

        applyAdaptiveDifficulty()

        // Seed first 3 obstacles
        for i in 0..<3 {
            spawnObstacle(atX: nextObstacleX + CGFloat(i) * obstacleSpacing, in: size)
        }

        gameState = .playing
        startTimer(in: size)
    }

    private func applyAdaptiveDifficulty() {
        let diff = computeDifficulty(from: roundScores)
        switch diff {
        case .easy:
            baseSpeed = 130
            gapSize = 190
            obstacleSpacing = 310
        case .medium:
            baseSpeed = 170
            gapSize = 155
            obstacleSpacing = 270
        case .hard:
            baseSpeed = 220
            gapSize = 125
            obstacleSpacing = 230
        }
    }

    private func spawnObstacle(atX x: CGFloat, in size: CGSize) {
        let minGapCenter = wallMargin + gapSize / 2
        let maxGapCenter = size.height - wallMargin - gapSize / 2
        let gapCenter = CGFloat.random(in: minGapCenter...max(minGapCenter + 1, maxGapCenter))
        let obs = GravitySwitchObstacle(x: x, gapY: gapCenter, gapHeight: gapSize)
        obstacles.append(obs)
        nextObstacleX = x + obstacleSpacing
    }

    private func startTimer(in size: CGSize) {
        stopTimer()
        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame(in: size)
        }
        RunLoop.main.add(gameTimer!, forMode: .common)
    }

    private func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    // MARK: - Game Loop

    private func updateGame(in size: CGSize) {
        guard gameState == .playing else { return }

        let dt: CGFloat = 1.0 / 60.0
        frameCount += 1

        // Score = distance traveled (in points)
        score = Int(CGFloat(frameCount) * currentSpeed * dt)

        // Apply gravity to velocity
        let gravDir: CGFloat = gravityDown ? 1 : -1
        playerVelocity += gravityStrength * gravDir * dt

        // Clamp velocity so it doesn't go too fast
        let maxVel: CGFloat = 700
        playerVelocity = min(max(playerVelocity, -maxVel), maxVel)

        // Move player vertically
        playerY += playerVelocity * dt

        // Wall collision (top/bottom)
        let halfP = playerSize / 2
        if playerY < halfP {
            playerY = halfP
            triggerGameOver()
            return
        }
        if playerY > size.height - halfP {
            playerY = size.height - halfP
            triggerGameOver()
            return
        }

        // Move obstacles left
        let speed = currentSpeed
        obstacles = obstacles.map { obs in
            var o = obs
            o.x -= speed * dt
            return o
        }

        // Remove off-screen obstacles and spawn new ones
        obstacles.removeAll { $0.x < -50 }
        while nextObstacleX < size.width + obstacleSpacing * 2 {
            spawnObstacle(atX: nextObstacleX, in: size)
        }

        // Collision detection: player rect vs obstacle bars
        let playerRect = CGRect(
            x: size.width * 0.25 - halfP + 4,
            y: playerY - halfP + 4,
            width: playerSize - 8,
            height: playerSize - 8
        )

        for obs in obstacles {
            let barX = obs.x - obs.barWidth / 2
            let barW = obs.barWidth

            // Top bar: from 0 to gapY - gapSize/2
            let topBarHeight = obs.gapY - obs.gapSize / 2
            if topBarHeight > 0 {
                let topRect = CGRect(x: barX, y: 0, width: barW, height: topBarHeight)
                if playerRect.intersects(topRect) {
                    triggerGameOver()
                    return
                }
            }

            // Bottom bar: from gapY + gapSize/2 to screen bottom
            let bottomBarTop = obs.gapY + obs.gapSize / 2
            let bottomBarHeight = size.height - bottomBarTop
            if bottomBarHeight > 0 {
                let bottomRect = CGRect(x: barX, y: bottomBarTop, width: barW, height: bottomBarHeight)
                if playerRect.intersects(bottomRect) {
                    triggerGameOver()
                    return
                }
            }
        }
    }

    private func triggerGameOver() {
        gameState = .gameOver
        stopTimer()
        bestScore = max(bestScore, score)

        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
    }
}

// MARK: - Background

struct GravitySwitchBackground: View {
    let gravityDown: Bool

    var body: some View {
        LinearGradient(
            colors: gravityDown
                ? [Color(red: 0.05, green: 0.05, blue: 0.18), Color(red: 0.12, green: 0.04, blue: 0.25)]
                : [Color(red: 0.04, green: 0.15, blue: 0.22), Color(red: 0.04, green: 0.22, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.35), value: gravityDown)
    }
}

// MARK: - Player View

struct GravitySwitchPlayerView: View {
    let size: CGFloat
    let gravityDown: Bool

    var body: some View {
        ZStack {
            // Glow
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: 6)

            // Body
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        colors: gravityDown
                            ? [Color.cyan, Color.blue]
                            : [Color.mint, Color.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                )

            // Direction arrow
            Image(systemName: gravityDown ? "arrow.down" : "arrow.up")
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(.white.opacity(0.85))
        }
        .animation(.easeInOut(duration: 0.15), value: gravityDown)
    }
}

// MARK: - Obstacle View

struct GravitySwitchObstacleView: View {
    let obstacle: GravitySwitchObstacle
    let height: CGFloat

    var body: some View {
        let topHeight = obstacle.gapY - obstacle.gapSize / 2
        let bottomTop = obstacle.gapY + obstacle.gapSize / 2
        let bottomHeight = height - bottomTop

        ZStack(alignment: .topLeading) {
            // Top bar
            if topHeight > 0 {
                GravitySwitchBar(width: obstacle.barWidth, height: topHeight)
                    .position(x: obstacle.x, y: topHeight / 2)
            }

            // Bottom bar
            if bottomHeight > 0 {
                GravitySwitchBar(width: obstacle.barWidth, height: bottomHeight)
                    .position(x: obstacle.x, y: bottomTop + bottomHeight / 2)
            }

            // Gap indicator line (subtle)
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: obstacle.barWidth + 4, height: obstacle.gapSize)
                .position(x: obstacle.x, y: obstacle.gapY)
        }
    }
}

struct GravitySwitchBar: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.2, blue: 0.85),
                            Color(red: 0.3, green: 0.1, blue: 0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.purple.opacity(0.5), lineWidth: 1)
                )

            // Edge glow
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width + 8, height: height)
                .blur(radius: 4)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - HUD

struct GravitySwitchHUD: View {
    let score: Int
    let difficulty: GravitySwitchDifficulty
    let gravityDown: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Score
            GravitySwitchGlassCard {
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(score)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            Spacer()

            // Gravity indicator
            GravitySwitchGlassCard {
                HStack(spacing: 5) {
                    Image(systemName: gravityDown ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(gravityDown ? Color.cyan : Color.mint)
                    Text(gravityDown ? "DOWN" : "UP")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(gravityDown ? Color.cyan : Color.mint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer()

            // Difficulty badge
            GravitySwitchGlassCard {
                HStack(spacing: 5) {
                    Image(systemName: difficulty.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(difficulty.color)
                    Text(difficulty.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(difficulty.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Tap Hint

struct GravitySwitchTapHint: View {
    var body: some View {
        Text("TAP anywhere to flip gravity")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Glass Card

struct GravitySwitchGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

// MARK: - Start Screen

struct GravitySwitchStartScreen: View {
    let difficulty: GravitySwitchDifficulty
    let roundScores: [Int]
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("GRAVITY")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("SWITCH")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 1.0))
                }
                Text("Tap to flip gravity\nAvoid the bars")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                if !roundScores.isEmpty {
                    Text("Avg score: \(roundScores.reduce(0,+)/roundScores.count)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Button(action: onStart) {
                    Text("START")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.purple.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(40)
        }
    }
}

// MARK: - Game Over Screen

struct GravitySwitchGameOverScreen: View {
    let score: Int
    let difficulty: GravitySwitchDifficulty
    let roundScores: [Int]
    let onRestart: () -> Void

    var movingAverage: Int {
        guard !roundScores.isEmpty else { return 0 }
        return roundScores.reduce(0, +) / roundScores.count
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 22) {

                // Title
                VStack(spacing: 4) {
                    Text("CRASHED")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("gravity switch v2")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }

                // Stats panel
                VStack(spacing: 14) {

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SCORE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("\(score)")
                                .font(.system(size: 44, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        Spacer()
                    }

                    Divider().background(Color.white.opacity(0.12))

                    // Moving average row
                    HStack {
                        Text("5-ROUND AVG")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(movingAverage)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }

                    // Next difficulty
                    HStack {
                        Text("NEXT DIFFICULTY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: difficulty.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(difficulty.color)
                            Text(difficulty.rawValue.uppercased())
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(difficulty.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(difficulty.color.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(difficulty.color.opacity(0.4), lineWidth: 1))
                    }

                    // Score history
                    if !roundScores.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ROUND HISTORY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(2)
                            HStack(spacing: 6) {
                                ForEach(Array(roundScores.enumerated()), id: \.offset) { i, s in
                                    Text("\(s)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(i == roundScores.count - 1 ? Color.cyan : Color.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            i == roundScores.count - 1
                                                ? Color.cyan.opacity(0.15)
                                                : Color.white.opacity(0.07),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Restart button
                Button(action: onRestart) {
                    Text("TRY AGAIN")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 12, x: 0, y: 4)
                }
            }
            .padding(28)
        }
    }
}
