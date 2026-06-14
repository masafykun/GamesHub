import SwiftUI

// MARK: - Data Models

struct DodgeV2Projectile: Identifiable {
    let id: UUID = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var radius: CGFloat = 8
    var color: Color
}

enum DodgeV2GameState {
    case waiting
    case playing
    case gameOver
}

enum DodgeV2Difficulty: String {
    case easy = "EASY"
    case normal = "NORMAL"
    case hard = "HARD"
    case expert = "EXPERT"

    var badgeColor: Color {
        switch self {
        case .easy: return .green
        case .normal: return .yellow
        case .hard: return .orange
        case .expert: return .red
        }
    }
}

// MARK: - Main View

struct DodgeViewV2: View {
    // MARK: Game State
    @State private var gameState: DodgeV2GameState = .waiting
    @State private var playerPosition: CGPoint = .zero
    @State private var projectiles: [DodgeV2Projectile] = []
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @AppStorage("dodgeV2HighScore") private var highScore: Int = 0

    // MARK: Adaptive Difficulty
    @State private var roundScores: [Int] = []
    @State private var baseSpeed: CGFloat = 150
    @State private var spawnInterval: Double = 1.5
    @State private var difficulty: DodgeV2Difficulty = .normal

    // MARK: Timers
    @State private var gameLoopTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil

    // MARK: Screen Size
    @State private var screenSize: CGSize = .zero

    private let playerRadius: CGFloat = 20
    private let collisionDistance: CGFloat = 28
    private let frameInterval: Double = 1.0 / 60.0

    // Neon colors for projectiles
    private let neonColors: [Color] = [
        Color(red: 1.0, green: 0.2, blue: 0.2),
        Color(red: 1.0, green: 0.5, blue: 0.0),
        Color(red: 1.0, green: 0.0, blue: 0.8),
        Color(red: 0.8, green: 0.0, blue: 1.0),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: Glassmorphism Background
                darkGradientBackground

                // MARK: Projectiles with glow
                ForEach(projectiles) { proj in
                    Circle()
                        .fill(proj.color)
                        .frame(width: proj.radius * 2, height: proj.radius * 2)
                        .shadow(color: proj.color, radius: 8)
                        .shadow(color: proj.color.opacity(0.4), radius: 16)
                        .position(proj.position)
                }

                // MARK: Player with ultraThinMaterial shield
                if gameState == .playing || gameState == .gameOver {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                            .frame(width: (playerRadius + 8) * 2, height: (playerRadius + 8) * 2)
                            .shadow(color: .cyan, radius: 6)

                        // Frosted shield
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: playerRadius * 2, height: playerRadius * 2)

                        // Core
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.cyan, Color.blue],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: playerRadius * 2
                                )
                            )
                            .frame(width: playerRadius * 1.4, height: playerRadius * 1.4)
                    }
                    .position(playerPosition)
                }

                // MARK: Frosted HUD
                if gameState == .playing {
                    VStack {
                        frostedHUD
                        Spacer()
                    }
                }

                // MARK: Difficulty Badge
                if gameState == .playing {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            difficultyBadge
                                .padding(.trailing, 20)
                                .padding(.bottom, 40)
                        }
                    }
                }

                // MARK: Waiting Overlay
                if gameState == .waiting {
                    waitingOverlay
                }

                // MARK: Game Over Overlay
                if gameState == .gameOver {
                    gameOverOverlay
                }
            }
            .onAppear {
                screenSize = geometry.size
                playerPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .onChange(of: geometry.size) { newSize in
                screenSize = newSize
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if gameState == .playing {
                            let loc = value.location
                            playerPosition = clampedPosition(loc, in: screenSize)
                        }
                    }
            )
            .onTapGesture {
                if gameState == .waiting {
                    startGame()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - UI Components

    private var darkGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.04, blue: 0.12),
                Color(red: 0.08, green: 0.04, blue: 0.16),
                Color(red: 0.04, green: 0.08, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var frostedHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                Text("\(highScore)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    private var difficultyBadge: some View {
        Text(difficulty.rawValue)
            .font(.system(size: 12, weight: .bold))
            .tracking(2)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(difficulty.badgeColor.opacity(0.3))
                    .overlay(Capsule().stroke(difficulty.badgeColor, lineWidth: 1))
            )
            .shadow(color: difficulty.badgeColor, radius: 6)
    }

    private var waitingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 28) {
                Text("DODGE")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .cyan, radius: 12)

                Text("V2 — ADAPTIVE MODE")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.cyan.opacity(0.8))

                VStack(spacing: 10) {
                    Text("Drag to move • Avoid projectiles")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Difficulty adapts to your performance")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }

                if !roundScores.isEmpty {
                    Text("Last rounds: \(roundScores.map { "\($0)s" }.joined(separator: ", "))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text("Tap to Start")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
                    .shadow(color: .cyan.opacity(0.4), radius: 10)
            }
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .red, radius: 10)

                VStack(spacing: 8) {
                    Text("Score: \(score)s")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if score >= highScore && score > 0 {
                        Text("New Best!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow, radius: 6)
                    } else {
                        Text("Best: \(highScore)s")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Text("Difficulty: \(difficulty.rawValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(difficulty.badgeColor)

                Button(action: restartGame) {
                    Text("Play Again")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.5), radius: 12)
                }
            }
        }
    }

    // MARK: - Helpers

    private func clampedPosition(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let x = max(playerRadius, min(size.width - playerRadius, point.x))
        let y = max(playerRadius, min(size.height - playerRadius, point.y))
        return CGPoint(x: x, y: y)
    }

    private func neonColor(for id: UUID) -> Color {
        let idx = abs(id.hashValue) % neonColors.count
        return neonColors[idx]
    }

    // MARK: - Adaptive Difficulty

    private func computeAdaptiveDifficulty() {
        let recent = roundScores.suffix(5)
        guard !recent.isEmpty else {
            baseSpeed = 150
            spawnInterval = 1.5
            difficulty = .normal
            return
        }

        let avg = Double(recent.reduce(0, +)) / Double(recent.count)

        if avg >= 30 {
            baseSpeed = min(250, baseSpeed + 20)
            spawnInterval = max(0.4, spawnInterval - 0.15)
            difficulty = avg >= 60 ? .expert : .hard
        } else if avg >= 15 {
            difficulty = .normal
        } else {
            baseSpeed = max(100, baseSpeed - 20)
            spawnInterval = min(2.0, spawnInterval + 0.15)
            difficulty = .easy
        }
    }

    // MARK: - Game Lifecycle

    private func startGame() {
        projectiles = []
        score = 0
        elapsedTime = 0
        playerPosition = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        gameState = .playing

        startGameLoop()
        scheduleSpawnTimer()
    }

    private func restartGame() {
        stopAllTimers()
        startGame()
    }

    private func endGame() {
        stopAllTimers()
        if score > highScore {
            highScore = score
        }

        // Record score and compute next difficulty
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores.removeFirst()
        }
        computeAdaptiveDifficulty()

        gameState = .gameOver
    }

    private func stopAllTimers() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    // MARK: - Game Loop

    private func startGameLoop() {
        gameLoopTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            updateGame()
        }
    }

    private func updateGame() {
        let dt = frameInterval
        elapsedTime += dt
        score = Int(elapsedTime)

        // Move projectiles
        for i in projectiles.indices {
            projectiles[i].position.x += projectiles[i].velocity.x * CGFloat(dt)
            projectiles[i].position.y += projectiles[i].velocity.y * CGFloat(dt)
        }

        // Remove out-of-bounds
        let margin: CGFloat = 50
        projectiles.removeAll { proj in
            proj.position.x < -margin ||
            proj.position.x > screenSize.width + margin ||
            proj.position.y < -margin ||
            proj.position.y > screenSize.height + margin
        }

        // Collision detection
        for proj in projectiles {
            let dx = proj.position.x - playerPosition.x
            let dy = proj.position.y - playerPosition.y
            if sqrt(dx * dx + dy * dy) < collisionDistance {
                endGame()
                return
            }
        }

        // Dynamic spawn rate based on score
        let scoreBasedInterval = max(spawnInterval * 0.5, spawnInterval - Double(score / 10) * 0.05)
        let _ = scoreBasedInterval // Used conceptually; spawn timer handles interval
    }

    // MARK: - Spawning

    private func scheduleSpawnTimer() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            spawnProjectile()
        }
    }

    private func spawnProjectile() {
        guard screenSize != .zero else { return }

        let edge = Int.random(in: 0..<4)
        let spawnPoint: CGPoint
        switch edge {
        case 0:
            spawnPoint = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: -8)
        case 1:
            spawnPoint = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: screenSize.height + 8)
        case 2:
            spawnPoint = CGPoint(x: -8, y: CGFloat.random(in: 0...screenSize.height))
        default:
            spawnPoint = CGPoint(x: screenSize.width + 8, y: CGFloat.random(in: 0...screenSize.height))
        }

        let targetX = playerPosition.x + CGFloat.random(in: -40...40)
        let targetY = playerPosition.y + CGFloat.random(in: -40...40)

        let dx = targetX - spawnPoint.x
        let dy = targetY - spawnPoint.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let color = neonColors[Int.random(in: 0..<neonColors.count)]
        let velocity = CGPoint(
            x: (dx / length) * baseSpeed,
            y: (dy / length) * baseSpeed
        )

        let proj = DodgeV2Projectile(position: spawnPoint, velocity: velocity, color: color)
        projectiles.append(proj)
    }
}

// MARK: - Preview

#Preview {
    DodgeViewV2()
}
