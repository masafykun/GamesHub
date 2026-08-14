import SwiftUI

// MARK: - Models

struct SpaceShooterBullet: Identifiable {
    let id = UUID()
    var position: CGPoint
}

struct SpaceShooterEnemy: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: CGFloat
    var speedFactor: CGFloat
    var color: Color
}

enum SpaceShooterGameState {
    case idle, playing, gameOver
}

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

struct SpaceShooterView: View {
    @AppStorage("spaceShooterBestScore") private var bestScore: Int = 0

    @State private var roundScores: [Int] = []
    @State private var gameState: SpaceShooterGameState = .idle
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var wave: Int = 1

    @State private var playerX: CGFloat = 0
    @State private var bullets: [SpaceShooterBullet] = []
    @State private var enemies: [SpaceShooterEnemy] = []

    @State private var gameTimer: Timer? = nil
    @State private var fireTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil

    // Adaptive parameters
    @State private var enemySpeed: CGFloat = 80
    @State private var fireInterval: Double = 0.5
    @State private var spawnInterval: Double = 2.0
    @State private var enemiesPerWave: Int = 3

    @State private var waveEnemiesSpawned: Int = 0
    @State private var waveEnemiesRequired: Int = 3
    @State private var waveCooldown: Bool = false

    private let playerSize: CGFloat = 36
    private let bulletSize: CGFloat = 8
    private let bulletSpeed: CGFloat = 460

    private let palette: [Color] = [.orange, .red, .pink, .purple, .yellow]

    private var difficulty: SpaceShooterDifficulty {
        computeDifficulty(from: roundScores)
    }

    private func computeDifficulty(from scores: [Int]) -> SpaceShooterDifficulty {
        guard !scores.isEmpty else { return .easy }
        let avg = scores.reduce(0, +) / scores.count
        if avg >= 300 { return .hard }
        if avg >= 120 { return .medium }
        return .easy
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                SpaceShooterStarfield()
                    .ignoresSafeArea()

                if gameState != .idle {
                    ForEach(bullets) { bullet in
                        Capsule()
                            .fill(LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom))
                            .frame(width: bulletSize, height: bulletSize * 2.5)
                            .shadow(color: .cyan.opacity(0.8), radius: 4)
                            .position(bullet.position)
                    }

                    ForEach(enemies) { enemy in
                        SpaceShooterEnemyView(radius: enemy.radius, color: enemy.color)
                            .position(enemy.position)
                    }

                    SpaceShooterShipView(size: playerSize)
                        .position(x: playerX, y: height - 70)
                }

                if gameState == .playing {
                    VStack {
                        hud
                        Spacer()
                    }
                    .padding(.top, 6)
                }

                if gameState == .idle {
                    startScreen { startGame(in: geo.size) }
                } else if gameState == .gameOver {
                    gameOverScreen { startGame(in: geo.size) }
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard gameState == .playing else { return }
                        playerX = min(max(value.location.x, playerSize / 2), width - playerSize / 2)
                    }
            )
            .onAppear { playerX = width / 2 }
            .onDisappear { stopAllTimers() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(spacing: 10) {
            glassCard {
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(score)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            glassCard {
                VStack(spacing: 2) {
                    Text("WAVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(wave)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }

            glassCard {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(i < lives ? Color.red : Color.gray.opacity(0.3))
                    }
                }
            }

            glassCard {
                Text(difficulty.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(difficulty.color)
            }
        }
        .padding(.horizontal, 14)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    // MARK: - Overlays

    private func startScreen(_ action: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("SPACE SHOOTER")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))

                Text("Drag to fly · your cannon fires by itself\nDon't let them slip past you")
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.65))

                if bestScore > 0 {
                    Text("Best: \(bestScore)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Button(action: action) {
                    Text("LAUNCH")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.cyan))
                        .shadow(color: .cyan.opacity(0.6), radius: 12)
                }
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func gameOverScreen(_ action: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))

                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("Wave \(wave) · best \(bestScore)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 6) {
                    Text("NEXT:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(difficulty.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(difficulty.color)
                }

                Button(action: action) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white))
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Lifecycle

    private func startGame(in size: CGSize) {
        score = 0
        lives = 3
        wave = 1
        bullets = []
        enemies = []
        waveEnemiesSpawned = 0
        waveCooldown = false
        playerX = size.width / 2

        applyAdaptiveDifficulty()
        waveEnemiesRequired = enemiesPerWave

        gameState = .playing
        startTimers(in: size)
    }

    private func applyAdaptiveDifficulty() {
        switch computeDifficulty(from: roundScores) {
        case .easy:
            enemySpeed = 85
            fireInterval = 0.45
            spawnInterval = 1.6
            enemiesPerWave = 4
        case .medium:
            enemySpeed = 120
            fireInterval = 0.36
            spawnInterval = 1.2
            enemiesPerWave = 6
        case .hard:
            enemySpeed = 165
            fireInterval = 0.28
            spawnInterval = 0.9
            enemiesPerWave = 8
        }
    }

    private func stopAllTimers() {
        gameTimer?.invalidate(); gameTimer = nil
        fireTimer?.invalidate(); fireTimer = nil
        spawnTimer?.invalidate(); spawnTimer = nil
    }

    private func startTimers(in size: CGSize) {
        stopAllTimers()

        let loop = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame(in: size)
        }
        gameTimer = loop
        RunLoop.main.add(loop, forMode: .common)

        scheduleFireTimer(in: size)
        scheduleSpawnTimer(in: size)
    }

    private func scheduleFireTimer(in size: CGSize) {
        fireTimer?.invalidate()
        let t = Timer(timeInterval: fireInterval, repeats: true) { _ in
            guard gameState == .playing else { return }
            bullets.append(SpaceShooterBullet(position: CGPoint(x: playerX, y: size.height - 95)))
        }
        fireTimer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func scheduleSpawnTimer(in size: CGSize) {
        spawnTimer?.invalidate()
        let t = Timer(timeInterval: spawnInterval, repeats: true) { _ in
            spawnEnemy(in: size)
        }
        spawnTimer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func spawnEnemy(in size: CGSize) {
        guard gameState == .playing, !waveCooldown else { return }
        guard waveEnemiesSpawned < waveEnemiesRequired else { return }

        let x = CGFloat.random(in: 32...(size.width - 32))
        let radius = CGFloat.random(in: 15...23)
        enemies.append(
            SpaceShooterEnemy(
                position: CGPoint(x: x, y: -radius),
                radius: radius,
                // Smaller ships dive faster, so the wave has some texture.
                speedFactor: 1.25 - (radius - 15) / 20,
                color: palette[Int.random(in: 0..<palette.count)]
            )
        )
        waveEnemiesSpawned += 1
    }

    private func advanceWave(in size: CGSize) {
        wave += 1
        waveEnemiesSpawned = 0
        waveCooldown = false
        score += 25 * wave

        enemySpeed = min(enemySpeed + 12, 300)
        spawnInterval = max(spawnInterval - 0.08, 0.5)
        enemiesPerWave = min(enemiesPerWave + 2, 16)
        waveEnemiesRequired = enemiesPerWave

        scheduleSpawnTimer(in: size)
    }

    // MARK: - Loop

    private func updateGame(in size: CGSize) {
        guard gameState == .playing else { return }
        let dt: CGFloat = 1.0 / 60.0

        bullets = bullets.compactMap { bullet in
            var b = bullet
            b.position.y -= bulletSpeed * dt
            return b.position.y < -20 ? nil : b
        }

        let shipY = size.height - 70
        var lostLife = false

        enemies = enemies.compactMap { enemy in
            var e = enemy
            e.position.y += enemySpeed * e.speedFactor * dt

            // Crashing into the ship costs a life too — dodging matters.
            let dx = e.position.x - playerX
            let dy = e.position.y - shipY
            if sqrt(dx * dx + dy * dy) < e.radius + playerSize * 0.4 {
                lostLife = true
                return nil
            }

            if e.position.y > size.height + 20 {
                lostLife = true
                return nil
            }
            return e
        }

        if lostLife {
            lives -= 1
            if lives <= 0 {
                triggerGameOver()
                return
            }
        }

        var bulletsToRemove = Set<UUID>()
        var enemiesToRemove = Set<UUID>()

        for bullet in bullets {
            for enemy in enemies {
                guard !enemiesToRemove.contains(enemy.id),
                      !bulletsToRemove.contains(bullet.id) else { continue }
                let dx = bullet.position.x - enemy.position.x
                let dy = bullet.position.y - enemy.position.y
                if sqrt(dx * dx + dy * dy) < enemy.radius + bulletSize / 2 {
                    bulletsToRemove.insert(bullet.id)
                    enemiesToRemove.insert(enemy.id)
                    // Small, fast ships are worth more.
                    score += enemy.radius < 19 ? 15 : 10
                }
            }
        }

        if !bulletsToRemove.isEmpty || !enemiesToRemove.isEmpty {
            bullets.removeAll { bulletsToRemove.contains($0.id) }
            enemies.removeAll { enemiesToRemove.contains($0.id) }
        }

        if waveEnemiesSpawned >= waveEnemiesRequired && enemies.isEmpty && !waveCooldown {
            waveCooldown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard gameState == .playing else { return }
                advanceWave(in: size)
            }
        }
    }

    private func triggerGameOver() {
        gameState = .gameOver
        stopAllTimers()
        bestScore = max(bestScore, score)
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
    }
}

// MARK: - Ship

struct SpaceShooterShipView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.orange.opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: size * 0.6))
                .frame(width: size * 1.2, height: size * 0.5)
                .offset(y: size * 0.45)
                .blur(radius: 4)

            Path { path in
                let w = size, h = size
                path.move(to: CGPoint(x: w / 2, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.75))
                path.addLine(to: CGPoint(x: w / 2, y: h * 0.85))
                path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.75))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [.cyan, .blue, .indigo], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)

            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.9), .cyan.opacity(0.3)], center: .center, startRadius: 0, endRadius: size * 0.18))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(y: -size * 0.1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Enemy

struct SpaceShooterEnemyView: View {
    let radius: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.45), .clear], center: .center, startRadius: radius * 0.5, endRadius: radius * 1.4))
                .frame(width: radius * 2.8, height: radius * 2.8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.95), color.opacity(0.6), .black.opacity(0.7)],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .overlay(Circle().strokeBorder(color.opacity(0.7), lineWidth: 1.5))

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: radius * 0.5, height: radius * 0.5)
                .offset(x: -radius * 0.25, y: -radius * 0.25)
        }
    }
}

// MARK: - Starfield

struct SpaceShooterStarfield: View {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private let stars: [Star] = (0..<70).map { _ in
        Star(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 1...2.6),
            opacity: Double.random(in: 0.25...0.9)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.02, blue: 0.09), Color(red: 0.06, green: 0.03, blue: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Canvas { context, size in
                    for star in stars {
                        let rect = CGRect(
                            x: star.x * size.width,
                            y: star.y * size.height,
                            width: star.size,
                            height: star.size
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

#Preview {
    SpaceShooterView()
}
