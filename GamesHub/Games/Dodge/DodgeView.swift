import SwiftUI

// MARK: - Data Models

struct DodgeProjectile: Identifiable {
    let id: UUID = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var radius: CGFloat = 8
}

enum DodgeGameState {
    case waiting
    case playing
    case gameOver
}

// MARK: - Main View

struct DodgeView: View {
    // MARK: Game State
    @State private var gameState: DodgeGameState = .waiting
    @State private var playerPosition: CGPoint = .zero
    @State private var projectiles: [DodgeProjectile] = []
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @AppStorage("dodgeHighScore") private var highScore: Int = 0

    // MARK: Timers
    @State private var gameLoopTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var spawnInterval: Double = 1.5

    // MARK: Screen Size (set once via GeometryReader)
    @State private var screenSize: CGSize = .zero

    private let playerRadius: CGFloat = 20
    private let collisionDistance: CGFloat = 28  // 20 + 8
    private let projectileSpeed: CGFloat = 150
    private let frameInterval: Double = 1.0 / 60.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Projectiles
                ForEach(projectiles) { proj in
                    Circle()
                        .fill(projectileColor(for: proj))
                        .frame(width: proj.radius * 2, height: proj.radius * 2)
                        .position(proj.position)
                }

                // Player
                if gameState == .playing || gameState == .gameOver {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: playerRadius * 2, height: playerRadius * 2)
                        .position(playerPosition)
                        .shadow(color: .cyan.opacity(0.6), radius: 8)
                }

                // HUD
                if gameState == .playing {
                    VStack {
                        HStack {
                            Text("Score: \(score)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                            Spacer()
                            Text("Best: \(highScore)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.trailing, 20)
                        }
                        .padding(.top, 50)
                        Spacer()
                    }
                }

                // Waiting overlay
                if gameState == .waiting {
                    VStack(spacing: 24) {
                        Text("DODGE")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Drag to move your ship")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)

                        Text("Avoid the projectiles!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)

                        Spacer().frame(height: 20)

                        Text("Tap to Start")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .stroke(Color.cyan, lineWidth: 2)
                            )
                    }
                }

                // Game over overlay
                if gameState == .gameOver {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .ignoresSafeArea()

                    VStack(spacing: 24) {
                        Text("GAME OVER")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.red)

                        VStack(spacing: 8) {
                            Text("Score: \(score)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            if score >= highScore {
                                Text("New Best!")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yellow)
                            } else {
                                Text("Best: \(highScore)")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: restartGame) {
                            Text("Play Again")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 44)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.blue))
                        }
                    }
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
                            playerPosition = clampedPosition(value.location, in: screenSize)
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

    // MARK: - Helpers

    private func projectileColor(for proj: DodgeProjectile) -> Color {
        // Alternate between red and orange based on id hash
        let h = abs(proj.id.hashValue) % 2
        return h == 0 ? Color.red : Color.orange
    }

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

        // Update projectile positions
        for i in projectiles.indices {
            projectiles[i].position.x += projectiles[i].velocity.x * CGFloat(dt)
            projectiles[i].position.y += projectiles[i].velocity.y * CGFloat(dt)
        }

        // Remove out-of-bounds projectiles
        let margin: CGFloat = 40
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
            let dist = sqrt(dx * dx + dy * dy)
            if dist < collisionDistance {
                endGame()
                return
            }
        }

        // Update spawn interval every 10 points
        let newInterval = max(0.5, 1.5 - Double(score / 10) * 0.1)
        if abs(newInterval - spawnInterval) > 0.05 {
            spawnInterval = newInterval
            spawnTimer?.invalidate()
            spawnTimer = nil
            scheduleSpawnTimer()
        }
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
        case 0: // top
            spawnPoint = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: -8)
        case 1: // bottom
            spawnPoint = CGPoint(x: CGFloat.random(in: 0...screenSize.width), y: screenSize.height + 8)
        case 2: // left
            spawnPoint = CGPoint(x: -8, y: CGFloat.random(in: 0...screenSize.height))
        default: // right
            spawnPoint = CGPoint(x: screenSize.width + 8, y: CGFloat.random(in: 0...screenSize.height))
        }

        // Aim at current player position with some jitter
        let targetX = playerPosition.x + CGFloat.random(in: -30...30)
        let targetY = playerPosition.y + CGFloat.random(in: -30...30)

        let dx = targetX - spawnPoint.x
        let dy = targetY - spawnPoint.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let velocity = CGPoint(
            x: (dx / length) * projectileSpeed,
            y: (dy / length) * projectileSpeed
        )

        let proj = DodgeProjectile(position: spawnPoint, velocity: velocity)
        projectiles.append(proj)
    }
}

// MARK: - Preview

#Preview {
    DodgeView()
}
