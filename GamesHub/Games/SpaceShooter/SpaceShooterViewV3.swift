import SwiftUI

// MARK: - Models

struct SpaceShooterV3Bullet: Identifiable {
    let id = UUID()
    var position: CGPoint
}

struct SpaceShooterV3Enemy: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: CGFloat
    var speed: CGFloat
    var color: Color
}

struct SpaceShooterV3Formation {
    let positions: [CGPoint]  // normalized x: 0..1, y: 0..1 (used as spawn offsets)
    let speeds: [CGFloat]
    let radii: [CGFloat]
    let colors: [Color]
}

enum SpaceShooterV3State {
    case idle
    case playing
    case gameOver
}

// MARK: - LCG RNG

struct SpaceShooterV3LCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    // Returns a CGFloat in [0, 1)
    mutating func nextFloat() -> CGFloat {
        return CGFloat(next() >> 11) / CGFloat(1 << 53)
    }

    // Returns a CGFloat in [lo, hi]
    mutating func nextFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        return range.lowerBound + nextFloat() * (range.upperBound - range.lowerBound)
    }

    // Returns an Int in [0, n)
    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Formation Generator

func spaceShooterV3GenerateFormation(wave: Int, seed: Int, canvasWidth: CGFloat) -> SpaceShooterV3Formation {
    var rng = SpaceShooterV3LCG(seed: seed &+ wave &* 31337)

    let enemyCount = 5 + wave * 2
    let patternType = rng.nextInt(5)  // 0..4 different patterns

    var xPositions: [CGFloat] = []
    let margin: CGFloat = 30

    switch patternType {
    case 0:
        // Line formation — evenly spaced across width
        for i in 0..<enemyCount {
            let t = CGFloat(i) / CGFloat(max(enemyCount - 1, 1))
            xPositions.append(margin + t * (canvasWidth - margin * 2))
        }
    case 1:
        // V-shape formation
        for i in 0..<enemyCount {
            let t = CGFloat(i) / CGFloat(max(enemyCount - 1, 1))
            xPositions.append(margin + t * (canvasWidth - margin * 2))
        }
    case 2:
        // Random scatter — seeded
        for _ in 0..<enemyCount {
            xPositions.append(rng.nextFloat(in: margin...(canvasWidth - margin)))
        }
    case 3:
        // Two clusters
        let half = enemyCount / 2
        let c1 = canvasWidth * rng.nextFloat(in: 0.2...0.4)
        let c2 = canvasWidth * rng.nextFloat(in: 0.6...0.8)
        for _ in 0..<half {
            xPositions.append(c1 + rng.nextFloat(in: -25...25))
        }
        for _ in half..<enemyCount {
            xPositions.append(c2 + rng.nextFloat(in: -25...25))
        }
    default:
        // Diamond / arch
        for i in 0..<enemyCount {
            let t = CGFloat(i) / CGFloat(max(enemyCount - 1, 1))
            let arch = sin(t * .pi)
            let x = margin + t * (canvasWidth - margin * 2)
            xPositions.append(x + arch * 0 ) // arch used for y stagger below
            _ = arch
        }
        // Fallback to random
        xPositions = []
        for _ in 0..<enemyCount {
            xPositions.append(rng.nextFloat(in: margin...(canvasWidth - margin)))
        }
    }

    let baseSpeed = CGFloat(1.5) + CGFloat(wave) * 0.3
    var speeds: [CGFloat] = []
    var radii: [CGFloat] = []
    var colors: [Color] = []

    let palette: [Color] = [.orange, .red, .purple, .pink, .yellow, .green, .cyan]

    for _ in 0..<enemyCount {
        speeds.append(baseSpeed + rng.nextFloat(in: 0...0.8))
        radii.append(rng.nextFloat(in: 14...24))
        colors.append(palette[rng.nextInt(palette.count)])
    }

    // Build normalized formation positions — x from computed, y slightly staggered
    var positions: [CGPoint] = []
    var rng2 = SpaceShooterV3LCG(seed: seed &+ wave &* 99991)
    for i in 0..<enemyCount {
        let yOffset = rng2.nextFloat(in: 0...40)
        positions.append(CGPoint(x: xPositions[i], y: yOffset))
    }

    return SpaceShooterV3Formation(positions: positions, speeds: speeds, radii: radii, colors: colors)
}

// MARK: - ViewModel

class SpaceShooterV3ViewModel: ObservableObject {
    @Published var playerX: CGFloat = 200
    @Published var bullets: [SpaceShooterV3Bullet] = []
    @Published var enemies: [SpaceShooterV3Enemy] = []
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var wave: Int = 1
    @Published var gameState: SpaceShooterV3State = .idle
    @Published var seedInt: Int = 1

    var canvasSize: CGSize = .zero

    private var gameTimer: Timer?
    private var fireTimer: Timer?
    private var frameCount: Int = 0
    private var currentFormation: SpaceShooterV3Formation?
    private var formationIndex: Int = 0
    private var spawnQueue: [SpaceShooterV3Enemy] = []
    private var spawnFrameInterval: Int = 30
    private var lastSpawnFrame: Int = 0
    private var waveEnemiesTotal: Int = 0
    private var waveEnemiesDefeated: Int = 0

    func startGame(size: CGSize, seed: Int) {
        canvasSize = size
        seedInt = seed
        playerX = size.width / 2
        bullets = []
        enemies = []
        spawnQueue = []
        score = 0
        lives = 3
        wave = 1
        frameCount = 0
        waveEnemiesDefeated = 0
        gameState = .playing

        prepareWave()

        gameTimer?.invalidate()
        fireTimer?.invalidate()

        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(gameTimer!, forMode: .common)

        fireTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.fireBullet()
        }
        RunLoop.main.add(fireTimer!, forMode: .common)
    }

    func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        fireTimer?.invalidate()
        fireTimer = nil
    }

    private func prepareWave() {
        guard canvasSize.width > 0 else { return }
        let formation = spaceShooterV3GenerateFormation(wave: wave, seed: seedInt, canvasWidth: canvasSize.width)
        currentFormation = formation
        formationIndex = 0
        lastSpawnFrame = frameCount
        spawnFrameInterval = max(20, 70 - wave * 4)
        waveEnemiesTotal = formation.positions.count
        waveEnemiesDefeated = 0
        spawnQueue = []
        enemies = []
    }

    private func fireBullet() {
        guard gameState == .playing else { return }
        let bulletY = canvasSize.height - 80
        bullets.append(SpaceShooterV3Bullet(position: CGPoint(x: playerX, y: bulletY)))
    }

    func update() {
        guard gameState == .playing else { return }
        frameCount += 1

        // Spawn next enemy from formation queue
        if let formation = currentFormation,
           formationIndex < formation.positions.count,
           frameCount - lastSpawnFrame >= spawnFrameInterval {
            let i = formationIndex
            let pos = formation.positions[i]
            let enemy = SpaceShooterV3Enemy(
                position: CGPoint(x: pos.x, y: -formation.radii[i] - pos.y),
                radius: formation.radii[i],
                speed: formation.speeds[i],
                color: formation.colors[i]
            )
            enemies.append(enemy)
            formationIndex += 1
            lastSpawnFrame = frameCount
        }

        // Move bullets upward
        bullets = bullets.map {
            var b = $0; b.position.y -= 9; return b
        }.filter { $0.position.y > -20 }

        // Move enemies downward
        enemies = enemies.map {
            var e = $0; e.position.y += e.speed; return e
        }

        // Enemies reaching bottom
        var survivingEnemies: [SpaceShooterV3Enemy] = []
        for enemy in enemies {
            if enemy.position.y > canvasSize.height + enemy.radius {
                lives -= 1
                if lives <= 0 {
                    gameState = .gameOver
                    stopGame()
                    return
                }
            } else {
                survivingEnemies.append(enemy)
            }
        }
        enemies = survivingEnemies

        // Collision detection
        var bulletsToRemove = Set<UUID>()
        var enemiesToRemove = Set<UUID>()

        for bullet in bullets {
            for enemy in enemies {
                guard !enemiesToRemove.contains(enemy.id) else { continue }
                let dx = bullet.position.x - enemy.position.x
                let dy = bullet.position.y - enemy.position.y
                if sqrt(dx * dx + dy * dy) < enemy.radius + 5 {
                    bulletsToRemove.insert(bullet.id)
                    enemiesToRemove.insert(enemy.id)
                    score += 10
                    waveEnemiesDefeated += 1
                }
            }
        }

        bullets = bullets.filter { !bulletsToRemove.contains($0.id) }
        enemies = enemies.filter { !enemiesToRemove.contains($0.id) }

        // Advance wave when all spawned & all defeated/escaped
        let allSpawned = formationIndex >= (currentFormation?.positions.count ?? 0)
        if allSpawned && enemies.isEmpty && waveEnemiesDefeated > 0 {
            wave += 1
            prepareWave()
        }
    }

    func movePlayer(to x: CGFloat) {
        playerX = max(25, min(canvasSize.width - 25, x))
    }
}

// MARK: - Main View

struct SpaceShooterViewV3: View {
    @StateObject private var viewModel = SpaceShooterV3ViewModel()
    @State private var seedInt: Int = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                // Starfield
                SpaceShooterV3Starfield(seed: seedInt)

                // Game objects
                if viewModel.gameState != .idle {
                    // Bullets
                    ForEach(viewModel.bullets) { bullet in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5, height: 16)
                            .shadow(color: .cyan.opacity(0.8), radius: 4)
                            .position(bullet.position)
                    }

                    // Enemies
                    ForEach(viewModel.enemies) { enemy in
                        SpaceShooterV3EnemyView(enemy: enemy)
                            .position(enemy.position)
                    }

                    // Player ship
                    SpaceShooterV3Ship()
                        .frame(width: 54, height: 54)
                        .position(x: viewModel.playerX, y: geo.size.height - 72)
                }

                // HUD overlay
                VStack(spacing: 0) {
                    SpaceShooterV3HUD(
                        score: viewModel.score,
                        lives: viewModel.lives,
                        wave: viewModel.wave,
                        seed: viewModel.gameState == .playing ? viewModel.seedInt : seedInt
                    )
                    Spacer()
                }

                // State overlays
                if viewModel.gameState == .idle {
                    SpaceShooterV3StartOverlay(seed: seedInt) {
                        viewModel.startGame(size: geo.size, seed: seedInt)
                    }
                } else if viewModel.gameState == .gameOver {
                    SpaceShooterV3GameOverOverlay(
                        score: viewModel.score,
                        wave: viewModel.wave,
                        seed: viewModel.seedInt
                    ) {
                        seedInt += 1
                        viewModel.startGame(size: geo.size, seed: seedInt)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if viewModel.gameState == .playing {
                            viewModel.movePlayer(to: value.location.x)
                        }
                    }
            )
            .onAppear {
                viewModel.canvasSize = geo.size
            }
            .onChange(of: geo.size) { newSize in
                viewModel.canvasSize = newSize
            }
        }
    }
}

// MARK: - HUD

struct SpaceShooterV3HUD: View {
    let score: Int
    let lives: Int
    let wave: Int
    let seed: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("SEED: #\(seed)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                    Text("WAVE \(wave)")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("LIVES")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(i < lives ? .red : Color(.systemGray4))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .neumorphicCard(radius: 0)
    }
}

// MARK: - Enemy View

struct SpaceShooterV3EnemyView: View {
    let enemy: SpaceShooterV3Enemy

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: enemy.radius * 2, height: enemy.radius * 2)
                .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                .shadow(color: Color(.systemGray4).opacity(0.9), radius: 4, x: 2, y: 2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [enemy.color.opacity(0.9), enemy.color.opacity(0.4)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: enemy.radius
                    )
                )
                .frame(width: enemy.radius * 1.6, height: enemy.radius * 1.6)

            Circle()
                .stroke(enemy.color.opacity(0.6), lineWidth: 1.5)
                .frame(width: enemy.radius * 1.6, height: enemy.radius * 1.6)

            // Core highlight
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: enemy.radius * 0.5, height: enemy.radius * 0.5)
                .offset(x: -enemy.radius * 0.2, y: -enemy.radius * 0.2)
        }
    }
}

// MARK: - Ship

struct SpaceShooterV3Ship: View {
    var body: some View {
        ZStack {
            // Engine glow
            Ellipse()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 22, height: 10)
                .offset(y: 20)
                .blur(radius: 5)

            // Neumorphic body base
            Path { path in
                path.move(to: CGPoint(x: 27, y: 2))
                path.addLine(to: CGPoint(x: 44, y: 44))
                path.addLine(to: CGPoint(x: 36, y: 38))
                path.addLine(to: CGPoint(x: 27, y: 42))
                path.addLine(to: CGPoint(x: 18, y: 38))
                path.addLine(to: CGPoint(x: 10, y: 44))
                path.closeSubpath()
            }
            .fill(Color(.systemGray6))
            .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
            .shadow(color: Color(.systemGray3), radius: 4, x: 2, y: 2)

            // Ship gradient overlay
            Path { path in
                path.move(to: CGPoint(x: 27, y: 2))
                path.addLine(to: CGPoint(x: 44, y: 44))
                path.addLine(to: CGPoint(x: 36, y: 38))
                path.addLine(to: CGPoint(x: 27, y: 42))
                path.addLine(to: CGPoint(x: 18, y: 38))
                path.addLine(to: CGPoint(x: 10, y: 44))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Cockpit
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 13, height: 13)
                .offset(y: 6)
                .shadow(color: .white.opacity(0.8), radius: 2, x: -1, y: -1)
                .shadow(color: Color(.systemGray3), radius: 2, x: 1, y: 1)

            Circle()
                .fill(Color.cyan.opacity(0.85))
                .frame(width: 9, height: 9)
                .offset(y: 6)
        }
    }
}

// MARK: - Starfield

struct SpaceShooterV3Starfield: View {
    let seed: Int

    private struct Star {
        let xRatio: CGFloat
        let yRatio: CGFloat
        let size: CGFloat
        let opacity: CGFloat
    }

    private func makeStars() -> [Star] {
        var rng = SpaceShooterV3LCG(seed: seed &* 999983)
        return (0..<70).map { _ in
            Star(
                xRatio: rng.nextFloat(),
                yRatio: rng.nextFloat(),
                size: rng.nextFloat(in: 1.0...2.8),
                opacity: rng.nextFloat(in: 0.2...0.7)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let stars = makeStars()
            ZStack {
                ForEach(0..<stars.count, id: \.self) { i in
                    let s = stars[i]
                    Circle()
                        .fill(Color(.systemGray2).opacity(Double(s.opacity)))
                        .frame(width: s.size, height: s.size)
                        .position(
                            x: s.xRatio * geo.size.width,
                            y: s.yRatio * geo.size.height
                        )
                }
            }
        }
    }
}

// MARK: - Start Overlay

struct SpaceShooterV3StartOverlay: View {
    let seed: Int
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("SPACE SHOOTER")
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundColor(.primary)

                    Text("V3 — PROCEDURAL")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.purple)
                }

                VStack(spacing: 10) {
                    Text("SEED: #\(seed)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .neumorphicCard()

                    Text("Each seed = unique formations")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 6) {
                    Label("Drag to move ship", systemImage: "hand.draw")
                    Label("Auto-fires every 0.5s", systemImage: "bolt.fill")
                    Label("Don't let enemies through!", systemImage: "exclamationmark.triangle")
                }
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)

                Button(action: onStart) {
                    Text("LAUNCH")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(.systemGray6))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .cyan.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
            .padding(24)
        }
        .onTapGesture { onStart() }
    }
}

// MARK: - Game Over Overlay

struct SpaceShooterV3GameOverOverlay: View {
    let score: Int
    let wave: Int
    let seed: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.93)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)

                VStack(spacing: 10) {
                    HStack {
                        Text("SCORE")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(score)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Divider()
                    HStack {
                        Text("WAVE")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(wave)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    Divider()
                    HStack {
                        Text("SEED")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("#\(seed)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                    }
                }
                .padding(16)
                .neumorphicCard()

                Text("Next seed: #\(seed + 1)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: onRestart) {
                    Text("NEW SEED")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(.systemGray6))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(28)
            .neumorphicCard(radius: 24)
            .padding(24)
        }
        .onTapGesture { onRestart() }
    }
}
