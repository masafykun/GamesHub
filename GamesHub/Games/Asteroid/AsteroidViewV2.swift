import SwiftUI

// MARK: - Models

enum AsteroidDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var speedMultiplier: CGFloat {
        switch self {
        case .easy:   return 0.75
        case .medium: return 1.0
        case .hard:   return 1.4
        }
    }

    var spawnMultiplier: Double {
        switch self {
        case .easy:   return 1.4
        case .medium: return 1.0
        case .hard:   return 0.65
        }
    }
}

// MARK: - Main View

struct AsteroidViewV2: View {
    // Game state
    @State private var gameState: AsteroidGameState = .waiting
    @State private var shipPosition: CGPoint = .zero
    @State private var asteroids: [AsteroidRock] = []
    @State private var score: Double = 0
    @State private var timer: Timer? = nil
    @State private var screenSize: CGSize = .zero
    @State private var spawnAccumulator: Double = 0
    @State private var elapsedTime: Double = 0

    // Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var difficulty: AsteroidDifficulty = .medium

    // Stars for background (stable across redraws)
    @State private var stars: [AsteroidStarData] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Space background
                Color.black.ignoresSafeArea()

                // Stars
                AsteroidStarsCanvas(stars: stars, size: geo.size)

                // Asteroids
                ForEach(asteroids) { asteroid in
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.9),
                                    Color.gray.opacity(0.5)
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: asteroid.radius * 2
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .frame(width: asteroid.radius * 2, height: asteroid.radius * 2)
                        .position(asteroid.position)
                }

                // Player ship
                if gameState == .playing || gameState == .waiting {
                    AsteroidShipShape()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cyan, Color.blue]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            AsteroidShipShape()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                        )
                        .frame(width: 36, height: 36)
                        .position(shipPosition)
                        .shadow(color: .cyan.opacity(0.7), radius: 10)
                }

                // HUD top bar
                VStack {
                    HStack(alignment: .center, spacing: 12) {
                        // Difficulty badge
                        Text(difficulty.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(difficulty.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(difficulty.color.opacity(0.5), lineWidth: 1)
                            )

                        Spacer()

                        // Score
                        Text("Time: \(Int(score))s")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 54)

                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    AsteroidWaitingOverlay(
                        difficulty: difficulty,
                        roundScores: roundScores
                    )
                }

                // Game Over overlay
                if gameState == .gameOver {
                    AsteroidGameOverOverlay(
                        score: Int(score),
                        roundScores: roundScores,
                        difficulty: difficulty
                    )
                }
            }
            .onAppear {
                screenSize = geo.size
                shipPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                stars = AsteroidStarData.generate(in: geo.size, count: 90)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if gameState == .waiting {
                            startGame(size: geo.size)
                        }
                        if gameState == .playing {
                            shipPosition = value.location
                        }
                        if gameState == .gameOver {
                            startGame(size: geo.size)
                        }
                    }
            )
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Game Logic

    private func startGame(size: CGSize) {
        asteroids = []
        score = 0
        elapsedTime = 0
        spawnAccumulator = 0
        shipPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        gameState = .playing

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            gameLoop(size: size)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func gameLoop(size: CGSize) {
        guard gameState == .playing else { return }

        let dt = 1.0 / 60.0
        elapsedTime += dt
        score = elapsedTime

        // Move asteroids
        for i in asteroids.indices {
            asteroids[i].position.x += asteroids[i].velocity.dx
            asteroids[i].position.y += asteroids[i].velocity.dy
        }

        // Remove off-screen asteroids
        let margin: CGFloat = 160
        asteroids.removeAll {
            $0.position.x < -margin ||
            $0.position.x > size.width + margin ||
            $0.position.y < -margin ||
            $0.position.y > size.height + margin
        }

        // Spawn asteroids — base interval shrinks over time, scaled by difficulty
        spawnAccumulator += dt
        let baseInterval = max(0.35, 1.5 - elapsedTime * 0.02)
        let spawnInterval = baseInterval * difficulty.spawnMultiplier
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            let extraCount = Int(elapsedTime / 15)
            let count = 1 + extraCount
            for _ in 0..<count {
                spawnAsteroid(size: size)
            }
        }

        // Collision detection
        let shipRadius: CGFloat = 14
        for asteroid in asteroids {
            let dx = asteroid.position.x - shipPosition.x
            let dy = asteroid.position.y - shipPosition.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < shipRadius + asteroid.radius - 4 {
                endGame()
                return
            }
        }
    }

    private func spawnAsteroid(size: CGSize) {
        let edge = Int.random(in: 0..<4)
        var startPos: CGPoint
        let padding: CGFloat = 30

        switch edge {
        case 0:
            startPos = CGPoint(x: CGFloat.random(in: 0...size.width), y: -padding)
        case 1:
            startPos = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + padding)
        case 2:
            startPos = CGPoint(x: -padding, y: CGFloat.random(in: 0...size.height))
        default:
            startPos = CGPoint(x: size.width + padding, y: CGFloat.random(in: 0...size.height))
        }

        let centerVariance: CGFloat = min(size.width, size.height) * 0.3
        let target = CGPoint(
            x: size.width / 2 + CGFloat.random(in: -centerVariance...centerVariance),
            y: size.height / 2 + CGFloat.random(in: -centerVariance...centerVariance)
        )

        let dx = target.x - startPos.x
        let dy = target.y - startPos.y
        let length = sqrt(dx * dx + dy * dy)

        // Base speed scaled by difficulty and time-based progression
        let baseSpeed = CGFloat.random(in: 1.5...3.5)
        let timeBonus = CGFloat(min(elapsedTime * 0.015, 1.5))
        let speed = (baseSpeed + timeBonus) * difficulty.speedMultiplier

        let velocity = CGVector(dx: dx / length * speed, dy: dy / length * speed)
        let radius = CGFloat.random(in: 12...32)

        asteroids.append(AsteroidRock(position: startPos, velocity: velocity, radius: radius))
    }

    private func endGame() {
        gameState = .gameOver
        timer?.invalidate()
        timer = nil

        // Append score and keep last 5
        roundScores.append(Int(score))
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }

        // Compute moving average and adjust difficulty
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg < 10 {
            difficulty = .easy
        } else if avg < 25 {
            difficulty = .medium
        } else {
            difficulty = .hard
        }
    }
}

// MARK: - Supporting Views

struct AsteroidWaitingOverlay: View {
    let difficulty: AsteroidDifficulty
    let roundScores: [Int]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(maxWidth: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(spacing: 18) {
                Text("ASTEROID DODGE")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.8), radius: 10)

                Text("V2 · Adaptive Difficulty")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                Divider().background(Color.white.opacity(0.2))

                HStack(spacing: 8) {
                    Text("Mode:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(difficulty.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(difficulty.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(difficulty.color.opacity(0.15))
                        .clipShape(Capsule())
                }

                if !roundScores.isEmpty {
                    VStack(spacing: 6) {
                        Text("Last Rounds")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 6) {
                            ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                                Text("\(s)s")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Text("Drag to Begin")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.7), radius: 8)
            }
            .padding(28)
        }
        .padding(.horizontal, 30)
    }
}

struct AsteroidGameOverOverlay: View {
    let score: Int
    let roundScores: [Int]
    let difficulty: AsteroidDifficulty

    private var movingAverage: Double {
        guard !roundScores.isEmpty else { return 0 }
        return Double(roundScores.reduce(0, +)) / Double(roundScores.count)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .frame(maxWidth: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.8), radius: 12)

                VStack(spacing: 8) {
                    Text("Survived: \(score)s")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    if roundScores.count > 1 {
                        Text("Avg (last \(roundScores.count)): \(String(format: "%.1f", movingAverage))s")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Divider().background(Color.white.opacity(0.2))

                // Next difficulty preview
                VStack(spacing: 6) {
                    Text("Next Difficulty")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(difficulty.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(difficulty.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(difficulty.color.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(difficulty.color.opacity(0.4), lineWidth: 1)
                        )
                }

                if !roundScores.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                            Text("\(s)s")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }

                Text("Drag to Play Again")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.7), radius: 6)
            }
            .padding(28)
        }
    }
}

// MARK: - Shapes & Background

struct AsteroidStarData: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let opacity: Double

    static func generate(in size: CGSize, count: Int) -> [AsteroidStarData] {
        (0..<count).map { i in
            AsteroidStarData(
                id: i,
                x: CGFloat.random(in: 0...max(size.width, 1)),
                y: CGFloat.random(in: 0...max(size.height, 1)),
                radius: CGFloat.random(in: 0.5...2.2),
                opacity: Double.random(in: 0.3...1.0)
            )
        }
    }
}

struct AsteroidStarsCanvas: View {
    let stars: [AsteroidStarData]
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            for star in stars {
                let rect = CGRect(
                    x: star.x - star.radius,
                    y: star.y - star.radius,
                    width: star.radius * 2,
                    height: star.radius * 2
                )
                context.opacity = star.opacity
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .ignoresSafeArea()
    }
}
