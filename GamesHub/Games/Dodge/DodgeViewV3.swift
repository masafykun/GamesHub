import SwiftUI

// MARK: - LCG Pseudo-Random Generator

struct DodgeV3LCG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }

    mutating func next() -> UInt64 {
        // Knuth multiplicative hash LCG
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

struct DodgeV3Projectile: Identifiable {
    let id: UUID = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var radius: CGFloat = 8
}

enum DodgeV3GameState {
    case waiting
    case playing
    case gameOver
}

// MARK: - Neumorphic Components

struct DodgeV3NeumorphicCircle: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.white.opacity(0.85), radius: 8, x: -5, y: -5)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 5, y: 5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: diameter * 0.8
                    )
                )
                .frame(width: diameter * 0.75, height: diameter * 0.75)

            // Subtle inner highlight
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: diameter * 0.55, height: diameter * 0.55)
                .offset(x: -3, y: -3)
        }
    }
}

struct DodgeV3ProjectileShape: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.5), radius: 3, x: -1, y: -1)

            Circle()
                .fill(Color(red: 0.4, green: 0.45, blue: 0.55).opacity(0.8))
                .frame(width: radius * 1.4, height: radius * 1.4)
        }
    }
}

// MARK: - Main View

struct DodgeViewV3: View {
    // MARK: Game State
    @State private var gameState: DodgeV3GameState = .waiting
    @State private var playerPosition: CGPoint = .zero
    @State private var projectiles: [DodgeV3Projectile] = []
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @AppStorage("dodgeV3HighScore") private var highScore: Int = 0

    // MARK: Seed State
    @State private var seedInt: Int = 1
    @State private var lcg: DodgeV3LCG = DodgeV3LCG(seed: 1)

    // MARK: Timers
    @State private var gameLoopTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var spawnInterval: Double = 1.5

    // MARK: Screen Size
    @State private var screenSize: CGSize = .zero

    private let playerRadius: CGFloat = 20
    private let collisionDistance: CGFloat = 28
    private let projectileSpeed: CGFloat = 150
    private let frameInterval: Double = 1.0 / 60.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: Neumorphic Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                // MARK: Projectiles — neumorphic soft-shadow style
                ForEach(projectiles) { proj in
                    DodgeV3ProjectileShape(radius: proj.radius)
                        .position(proj.position)
                }

                // MARK: Player — neumorphic orb
                if gameState == .playing || gameState == .gameOver {
                    DodgeV3NeumorphicCircle(diameter: playerRadius * 2)
                        .position(playerPosition)
                }

                // MARK: HUD
                if gameState == .playing {
                    VStack {
                        neumorphicHUD
                        Spacer()
                    }
                }

                // MARK: Seed Badge
                if gameState == .playing {
                    VStack {
                        Spacer()
                        HStack {
                            seedBadge
                                .padding(.leading, 20)
                                .padding(.bottom, 40)
                            Spacer()
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
    }

    // MARK: - UI Components

    private var neumorphicHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .tracking(2)
                Text("\(score)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                    .tracking(2)
                Text("\(highScore)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.35, green: 0.45, blue: 0.65))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .neumorphicCard(radius: 20)
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    private var seedBadge: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(Color(.systemGray))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .neumorphicCard(radius: 10)
    }

    private var waitingOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.8).ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("DODGE")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))

                    Text("V3 — SEEDED MODE")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(Color(.systemGray))
                }

                VStack(spacing: 10) {
                    Text("Drag to move • Avoid projectiles")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.secondaryLabel))
                    Text("Each run uses a unique procedural seed")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.tertiaryLabel))
                }

                Text("Current Seed: #\(seedInt)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.35, green: 0.45, blue: 0.65))

                Text("Tap to Start")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.55, green: 0.25, blue: 0.25))

                VStack(spacing: 8) {
                    Text("Score: \(score)s")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))

                    if score >= highScore && score > 0 {
                        Text("New Best!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.2))
                    } else {
                        Text("Best: \(highScore)s")
                            .font(.system(size: 18))
                            .foregroundColor(Color(.systemGray))
                    }
                }

                Text("Seed #\(seedInt)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(.systemGray2))

                Button(action: restartGame) {
                    Text("Next Seed")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 30)
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

    // MARK: - Game Lifecycle

    private func startGame() {
        projectiles = []
        score = 0
        elapsedTime = 0
        spawnInterval = 1.5
        lcg = DodgeV3LCG(seed: seedInt)
        playerPosition = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        gameState = .playing

        startGameLoop()
        scheduleSpawnTimer()
    }

    private func restartGame() {
        stopAllTimers()
        seedInt += 1
        startGame()
    }

    private func endGame() {
        stopAllTimers()
        if score > highScore {
            highScore = score
        }
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

        // Update spawn interval (score-based)
        let newInterval = max(0.5, 1.5 - Double(score / 10) * 0.1)
        if abs(newInterval - spawnInterval) > 0.05 {
            spawnInterval = newInterval
            spawnTimer?.invalidate()
            spawnTimer = nil
            scheduleSpawnTimer()
        }
    }

    // MARK: - Seeded Spawning

    private func scheduleSpawnTimer() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            spawnProjectile()
        }
    }

    private func spawnProjectile() {
        guard screenSize != .zero else { return }

        // Use LCG for deterministic spawn angles based on seed
        let edge = lcg.nextInt(4)
        let spawnPoint: CGPoint

        switch edge {
        case 0: // top
            let x = CGFloat(lcg.nextInRange(0, Double(screenSize.width)))
            spawnPoint = CGPoint(x: x, y: -8)
        case 1: // bottom
            let x = CGFloat(lcg.nextInRange(0, Double(screenSize.width)))
            spawnPoint = CGPoint(x: x, y: screenSize.height + 8)
        case 2: // left
            let y = CGFloat(lcg.nextInRange(0, Double(screenSize.height)))
            spawnPoint = CGPoint(x: -8, y: y)
        default: // right
            let y = CGFloat(lcg.nextInRange(0, Double(screenSize.height)))
            spawnPoint = CGPoint(x: screenSize.width + 8, y: y)
        }

        // Seeded jitter on target
        let jitterX = CGFloat(lcg.nextInRange(-35, 35))
        let jitterY = CGFloat(lcg.nextInRange(-35, 35))
        let targetX = playerPosition.x + jitterX
        let targetY = playerPosition.y + jitterY

        let dx = targetX - spawnPoint.x
        let dy = targetY - spawnPoint.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let velocity = CGPoint(
            x: (dx / length) * projectileSpeed,
            y: (dy / length) * projectileSpeed
        )

        let proj = DodgeV3Projectile(position: spawnPoint, velocity: velocity)
        projectiles.append(proj)
    }
}

// MARK: - Preview

#Preview {
    DodgeViewV3()
}
