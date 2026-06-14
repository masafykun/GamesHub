import SwiftUI

// MARK: - Models

enum SpaceShooterDifficulty: String {
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

// MARK: - Main View

struct SpaceShooterViewV2: View {

    // MARK: Persistent difficulty tracking
    @State var roundScores: [Int] = []

    // MARK: Game state
    @State private var gameState: SpaceShooterGameState = .idle
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var wave: Int = 1

    // MARK: Entities
    @State private var playerX: CGFloat = 0
    @State private var bullets: [SpaceShooterBullet] = []
    @State private var enemies: [SpaceShooterEnemy] = []

    // MARK: Timers
    @State private var gameTimer: Timer? = nil
    @State private var fireTimer: Timer? = nil
    @State private var waveTimer: Timer? = nil

    // MARK: Adaptive difficulty parameters
    @State private var enemySpeed: CGFloat = 80          // pts per second
    @State private var fireInterval: Double = 0.5        // seconds between shots
    @State private var spawnInterval: Double = 2.0       // seconds between enemy spawns
    @State private var enemiesPerWave: Int = 3

    // MARK: Wave tracking
    @State private var frameCount: Int = 0
    @State private var waveEnemiesSpawned: Int = 0
    @State private var waveEnemiesRequired: Int = 3
    @State private var waveCooldown: Bool = false

    // MARK: Layout
    private let playerSize: CGFloat = 36
    private let bulletSize: CGFloat = 8
    private let bulletSpeed: CGFloat = 400  // pts per second

    // MARK: Computed difficulty
    private var difficulty: SpaceShooterDifficulty {
        computeDifficulty(from: roundScores)
    }

    private func computeDifficulty(from scores: [Int]) -> SpaceShooterDifficulty {
        guard !scores.isEmpty else { return .easy }
        let avg = scores.reduce(0, +) / scores.count
        if avg >= 150 { return .hard }
        if avg >= 60  { return .medium }
        return .easy
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Starfield background
                SpaceShooterStarfield()
                    .ignoresSafeArea()

                // Game entities
                if gameState == .playing || gameState == .gameOver {
                    // Bullets
                    ForEach(bullets) { bullet in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: bulletSize, height: bulletSize * 2.5)
                            .position(bullet.position)
                    }

                    // Enemies
                    ForEach(enemies) { enemy in
                        SpaceShooterEnemyView(radius: enemy.radius)
                            .position(enemy.position)
                    }

                    // Player ship
                    SpaceShooterShipView(size: playerSize)
                        .position(x: playerX, y: height - 60)
                }

                // HUD overlay
                if gameState == .playing {
                    VStack {
                        SpaceShooterHUD(
                            score: score,
                            lives: lives,
                            wave: wave,
                            difficulty: difficulty
                        )
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                }

                // Idle screen
                if gameState == .idle {
                    SpaceShooterStartScreen {
                        startGame(in: geo.size)
                    }
                }

                // Game over screen
                if gameState == .gameOver {
                    SpaceShooterGameOverScreen(
                        score: score,
                        wave: wave
                    ) {
                        startGame(in: geo.size)
                    }
                }
            }
            .frame(width: width, height: height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard gameState == .playing else { return }
                        let newX = value.location.x
                        playerX = min(max(newX, playerSize / 2), width - playerSize / 2)
                    }
            )
            .onAppear {
                playerX = width / 2
            }
            .onDisappear {
                stopAllTimers()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Game Lifecycle

    private func startGame(in size: CGSize) {
        score = 0
        lives = 3
        wave = 1
        bullets = []
        enemies = []
        frameCount = 0
        waveEnemiesSpawned = 0
        waveCooldown = false
        playerX = size.width / 2

        applyAdaptiveDifficulty()

        waveEnemiesRequired = enemiesPerWave

        gameState = .playing
        startTimers(in: size)
    }

    private func applyAdaptiveDifficulty() {
        let diff = computeDifficulty(from: roundScores)
        switch diff {
        case .easy:
            enemySpeed = 80
            fireInterval = 0.5
            spawnInterval = 2.2
            enemiesPerWave = 3
        case .medium:
            enemySpeed = 120
            fireInterval = 0.38
            spawnInterval = 1.6
            enemiesPerWave = 5
        case .hard:
            enemySpeed = 180
            fireInterval = 0.28
            spawnInterval = 1.1
            enemiesPerWave = 7
        }
    }

    private func stopAllTimers() {
        gameTimer?.invalidate()
        gameTimer = nil
        fireTimer?.invalidate()
        fireTimer = nil
        waveTimer?.invalidate()
        waveTimer = nil
    }

    private func startTimers(in size: CGSize) {
        stopAllTimers()

        // Main game loop at 60fps
        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame(in: size)
        }
        RunLoop.main.add(gameTimer!, forMode: .common)

        // Fire timer
        scheduleFireTimer(in: size)

        // Spawn timer
        scheduleSpawnTimer(in: size)
    }

    private func scheduleFireTimer(in size: CGSize) {
        fireTimer?.invalidate()
        fireTimer = Timer(timeInterval: fireInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            fireBullet(in: size)
        }
        RunLoop.main.add(fireTimer!, forMode: .common)
    }

    private func scheduleSpawnTimer(in size: CGSize) {
        waveTimer?.invalidate()
        waveTimer = Timer(timeInterval: spawnInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            spawnEnemy(in: size)
        }
        RunLoop.main.add(waveTimer!, forMode: .common)
    }

    private func fireBullet(in size: CGSize) {
        let bullet = SpaceShooterBullet(position: CGPoint(x: playerX, y: size.height - 80))
        bullets.append(bullet)
    }

    private func spawnEnemy(in size: CGSize) {
        guard gameState == .playing else { return }

        if waveCooldown { return }

        if waveEnemiesSpawned >= waveEnemiesRequired {
            // All enemies for this wave are spawned; next wave starts when enemies list clears
            if enemies.isEmpty {
                advanceWave(in: size)
            }
            return
        }

        let x = CGFloat.random(in: 30...(size.width - 30))
        let enemy = SpaceShooterEnemy(position: CGPoint(x: x, y: -20), speed: 60 + CGFloat(wave) * 10)
        enemies.append(enemy)
        waveEnemiesSpawned += 1
    }

    private func advanceWave(in size: CGSize) {
        wave += 1
        waveEnemiesSpawned = 0
        waveCooldown = false

        // Increase difficulty per wave
        enemySpeed = min(enemySpeed + 15, 320)
        spawnInterval = max(spawnInterval - 0.1, 0.6)
        enemiesPerWave = min(enemiesPerWave + 2, 15)
        waveEnemiesRequired = enemiesPerWave

        scheduleSpawnTimer(in: size)
    }

    // MARK: - Game Loop

    private func updateGame(in size: CGSize) {
        guard gameState == .playing else { return }

        let dt: CGFloat = 1.0 / 60.0

        // Move bullets upward
        bullets = bullets.compactMap { bullet in
            var b = bullet
            b.position.y -= bulletSpeed * dt
            if b.position.y < -20 { return nil }
            return b
        }

        // Move enemies downward
        enemies = enemies.compactMap { enemy in
            var e = enemy
            e.position.y += enemySpeed * dt

            // Enemy reached bottom — lose a life
            if e.position.y > size.height + 20 {
                lives -= 1
                if lives <= 0 {
                    triggerGameOver()
                }
                return nil
            }
            return e
        }

        // Collision detection: bullet vs enemy
        var bulletsToRemove = Set<UUID>()
        var enemiesToRemove = Set<UUID>()

        for bullet in bullets {
            for enemy in enemies {
                let dx = bullet.position.x - enemy.position.x
                let dy = bullet.position.y - enemy.position.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < enemy.radius + bulletSize / 2 {
                    bulletsToRemove.insert(bullet.id)
                    enemiesToRemove.insert(enemy.id)
                    score += 10
                }
            }
        }

        if !bulletsToRemove.isEmpty || !enemiesToRemove.isEmpty {
            bullets.removeAll { bulletsToRemove.contains($0.id) }
            enemies.removeAll { enemiesToRemove.contains($0.id) }
        }

        // Check if wave is cleared and all have been spawned
        if waveEnemiesSpawned >= waveEnemiesRequired && enemies.isEmpty && !waveCooldown {
            waveCooldown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard gameState == .playing else { return }
                advanceWave(in: size)
            }
        }

        frameCount += 1
    }

    private func triggerGameOver() {
        gameState = .gameOver
        stopAllTimers()

        // Append score, keep last 5
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
    }
}

// MARK: - HUD

struct SpaceShooterHUD: View {
    let score: Int
    let lives: Int
    let wave: Int
    let difficulty: SpaceShooterDifficulty

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Score
            SpaceShooterGlassCard {
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(score)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Spacer()

            // Wave
            SpaceShooterGlassCard {
                VStack(spacing: 2) {
                    Text("WAVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(wave)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Spacer()

            // Lives
            SpaceShooterGlassCard {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(i < lives ? Color.red : Color.gray.opacity(0.3))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer()

            // Difficulty badge
            SpaceShooterGlassCard {
                Text(difficulty.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(difficulty.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Glass Card

struct SpaceShooterGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Ship View

struct SpaceShooterShipView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Engine glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.8), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.2, height: size * 0.5)
                .offset(y: size * 0.45)
                .blur(radius: 4)

            // Ship body
            Path { path in
                let w = size
                let h = size
                path.move(to: CGPoint(x: w / 2, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.75))
                path.addLine(to: CGPoint(x: w / 2, y: h * 0.85))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.75))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [.cyan, .blue, .indigo],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)

            // Cockpit
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), .cyan.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(y: -size * 0.1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Enemy View

struct SpaceShooterEnemyView: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.red.opacity(0.4), .clear],
                        center: .center,
                        startRadius: radius * 0.5,
                        endRadius: radius * 1.4
                    )
                )
                .frame(width: radius * 2.8, height: radius * 2.8)

            // Main body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange, .red, .purple.opacity(0.8)],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle()
                        .strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5)
                )

            // Highlight
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: radius * 0.6, height: radius * 0.6)
                .offset(x: -radius * 0.25, y: -radius * 0.25)
        }
    }
}

// MARK: - Starfield

// MARK: - Start Screen

// MARK: - Game Over Screen

