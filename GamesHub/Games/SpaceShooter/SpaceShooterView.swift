import SwiftUI

// MARK: - Models

struct SpaceShooterBullet: Identifiable {
    let id = UUID()
    var position: CGPoint
}

struct SpaceShooterEnemy: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: CGFloat = 20
    var speed: CGFloat
}

enum SpaceShooterGameState {
    case idle
    case playing
    case gameOver
}

// MARK: - ViewModel

class SpaceShooterViewModel: ObservableObject {
    @Published var playerX: CGFloat = 200
    @Published var bullets: [SpaceShooterBullet] = []
    @Published var enemies: [SpaceShooterEnemy] = []
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var wave: Int = 1
    @Published var gameState: SpaceShooterGameState = .idle

    var canvasSize: CGSize = .zero

    private var gameTimer: Timer?
    private var fireTimer: Timer?
    private var frameCount: Int = 0
    private var enemiesDefeatedInWave: Int = 0
    private var enemiesPerWave: Int = 5
    private var enemiesSpawnedInWave: Int = 0

    func startGame(size: CGSize) {
        canvasSize = size
        playerX = size.width / 2
        bullets = []
        enemies = []
        score = 0
        lives = 3
        wave = 1
        frameCount = 0
        enemiesDefeatedInWave = 0
        enemiesSpawnedInWave = 0
        enemiesPerWave = 5
        gameState = .playing

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

    func fireBullet() {
        guard gameState == .playing else { return }
        let bulletY = canvasSize.height - 80
        let bullet = SpaceShooterBullet(position: CGPoint(x: playerX, y: bulletY))
        bullets.append(bullet)
    }

    func update() {
        guard gameState == .playing else { return }
        frameCount += 1

        // Move bullets upward
        bullets = bullets.map {
            var b = $0
            b.position.y -= 8
            return b
        }.filter { $0.position.y > -10 }

        // Spawn enemies
        let spawnInterval = max(30, 90 - wave * 5)
        if frameCount % spawnInterval == 0 && enemiesSpawnedInWave < enemiesPerWave {
            spawnEnemy()
            enemiesSpawnedInWave += 1
        }

        // Move enemies downward
        let baseSpeed: CGFloat = 1.5 + CGFloat(wave) * 0.3
        enemies = enemies.map {
            var e = $0
            e.position.y += e.speed
            return e
        }

        // Check enemies reaching bottom
        var survivingEnemies: [SpaceShooterEnemy] = []
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

        // Collision detection: bullets vs enemies
        var bulletsToRemove = Set<UUID>()
        var enemiesToRemove = Set<UUID>()

        for bullet in bullets {
            for enemy in enemies {
                if enemiesToRemove.contains(enemy.id) { continue }
                let dx = bullet.position.x - enemy.position.x
                let dy = bullet.position.y - enemy.position.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < enemy.radius + 5 {
                    bulletsToRemove.insert(bullet.id)
                    enemiesToRemove.insert(enemy.id)
                    score += 10
                    enemiesDefeatedInWave += 1
                }
            }
        }

        bullets = bullets.filter { !bulletsToRemove.contains($0.id) }
        enemies = enemies.filter { !enemiesToRemove.contains($0.id) }

        // Advance wave
        if enemiesDefeatedInWave >= enemiesPerWave && enemiesSpawnedInWave >= enemiesPerWave && enemies.isEmpty {
            wave += 1
            enemiesDefeatedInWave = 0
            enemiesSpawnedInWave = 0
            enemiesPerWave = 5 + wave * 2
        }
    }

    private func spawnEnemy() {
        guard canvasSize.width > 0 else { return }
        let x = CGFloat.random(in: 25...(canvasSize.width - 25))
        let speed: CGFloat = CGFloat.random(in: 1.0...2.0) + CGFloat(wave) * 0.2
        let enemy = SpaceShooterEnemy(position: CGPoint(x: x, y: -25), speed: speed)
        enemies.append(enemy)
    }

    func movePlayer(to x: CGFloat) {
        let clamped = max(25, min(canvasSize.width - 25, x))
        playerX = clamped
    }
}

// MARK: - View

struct SpaceShooterView: View {
    @StateObject private var viewModel = SpaceShooterViewModel()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                // Starfield decoration (static dots)
                SpaceShooterStarfield()

                // Game objects
                if viewModel.gameState != .idle {
                    // Bullets
                    ForEach(viewModel.bullets) { bullet in
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: 4, height: 14)
                            .position(bullet.position)
                    }

                    // Enemies
                    ForEach(viewModel.enemies) { enemy in
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.orange, Color.red],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: enemy.radius
                                    )
                                )
                                .frame(width: enemy.radius * 2, height: enemy.radius * 2)
                            Circle()
                                .stroke(Color.yellow, lineWidth: 1.5)
                                .frame(width: enemy.radius * 2, height: enemy.radius * 2)
                        }
                        .position(enemy.position)
                    }

                    // Player ship
                    SpaceShooterShip()
                        .frame(width: 50, height: 50)
                        .position(x: viewModel.playerX, y: geo.size.height - 70)
                }

                // HUD
                VStack {
                    HStack {
                        Text("SCORE: \(viewModel.score)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("WAVE: \(viewModel.wave)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: "heart.fill")
                                    .foregroundColor(i < viewModel.lives ? .red : .gray.opacity(0.3))
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }

                // Overlay screens
                if viewModel.gameState == .idle {
                    SpaceShooterStartScreen {
                        viewModel.startGame(size: geo.size)
                    }
                } else if viewModel.gameState == .gameOver {
                    SpaceShooterGameOverScreen(score: viewModel.score, wave: viewModel.wave) {
                        viewModel.startGame(size: geo.size)
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
                canvasSize = geo.size
                viewModel.canvasSize = geo.size
            }
            .onChange(of: geo.size) { newSize in
                canvasSize = newSize
                viewModel.canvasSize = newSize
            }
        }
    }
}

// MARK: - Subviews

struct SpaceShooterStarfield: View {
    // Fixed star positions generated once
    private let stars: [(CGFloat, CGFloat, CGFloat)] = {
        var s: [(CGFloat, CGFloat, CGFloat)] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<80 {
            let x = CGFloat.random(in: 0...400, using: &rng)
            let y = CGFloat.random(in: 0...800, using: &rng)
            let size = CGFloat.random(in: 1...3, using: &rng)
            s.append((x, y, size))
        }
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                let (xRatio, yRatio, size) = stars[i]
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.9)))
                    .frame(width: size, height: size)
                    .position(
                        x: xRatio / 400 * geo.size.width,
                        y: yRatio / 800 * geo.size.height
                    )
            }
        }
    }
}

struct SpaceShooterShip: View {
    var body: some View {
        ZStack {
            // Engine glow
            Ellipse()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 20, height: 10)
                .offset(y: 18)
                .blur(radius: 4)

            // Body
            Path { path in
                path.move(to: CGPoint(x: 25, y: 2))
                path.addLine(to: CGPoint(x: 42, y: 42))
                path.addLine(to: CGPoint(x: 35, y: 36))
                path.addLine(to: CGPoint(x: 25, y: 40))
                path.addLine(to: CGPoint(x: 15, y: 36))
                path.addLine(to: CGPoint(x: 8, y: 42))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.white, Color.blue],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Cockpit
            Circle()
                .fill(Color.cyan.opacity(0.8))
                .frame(width: 10, height: 10)
                .offset(y: 4)
        }
    }
}

struct SpaceShooterStartScreen: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("SPACE SHOOTER")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan, radius: 8)

                VStack(spacing: 8) {
                    Text("Drag to move your ship")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Auto-fire destroys enemies")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Don't let enemies reach bottom!")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.orange)
                }

                Button(action: onStart) {
                    Text("TAP TO START")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onTapGesture {
            onStart()
        }
    }
}

struct SpaceShooterGameOverScreen: View {
    let score: Int
    let wave: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .red, radius: 10)

                VStack(spacing: 8) {
                    Text("SCORE: \(score)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("WAVE: \(wave)")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                Button(action: onRestart) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onTapGesture {
            onRestart()
        }
    }
}
