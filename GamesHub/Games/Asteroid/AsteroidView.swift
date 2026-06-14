import SwiftUI

struct AsteroidRock: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
}

enum AsteroidGameState {
    case waiting
    case playing
    case gameOver
}

struct AsteroidView: View {
    @State private var gameState: AsteroidGameState = .waiting
    @State private var shipPosition: CGPoint = .zero
    @State private var asteroids: [AsteroidRock] = []
    @State private var score: Double = 0
    @State private var timer: Timer? = nil
    @State private var screenSize: CGSize = .zero
    @State private var spawnAccumulator: Double = 0
    @State private var elapsedTime: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Space background
                Color.black.ignoresSafeArea()

                // Stars background
                AsteroidStarsView(size: geo.size)

                // Asteroids
                ForEach(asteroids) { asteroid in
                    Circle()
                        .fill(Color.gray.opacity(0.85))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                        )
                        .frame(width: asteroid.radius * 2, height: asteroid.radius * 2)
                        .position(asteroid.position)
                }

                // Player ship
                if gameState == .playing || gameState == .waiting {
                    AsteroidShipShape()
                        .fill(Color.cyan)
                        .overlay(
                            AsteroidShipShape()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                        .frame(width: 36, height: 36)
                        .position(shipPosition)
                        .shadow(color: .cyan.opacity(0.6), radius: 8)
                }

                // HUD
                VStack {
                    HStack {
                        Spacer()
                        Text("Time: \(Int(score))s")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.trailing, 20)
                            .padding(.top, 50)
                    }
                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    VStack(spacing: 20) {
                        Text("ASTEROID DODGE")
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan, radius: 10)

                        Text("Drag to move your ship")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Tap to Start")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.8), radius: 8)
                    }
                    .onTapGesture {
                        startGame(size: geo.size)
                    }
                }

                // Game Over overlay
                if gameState == .gameOver {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()

                        VStack(spacing: 24) {
                            Text("GAME OVER")
                                .font(.system(size: 36, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                                .shadow(color: .red, radius: 12)

                            Text("Survived: \(Int(score))s")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Text("Tap to Play Again")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.8), radius: 8)
                        }
                    }
                    .onTapGesture {
                        startGame(size: geo.size)
                    }
                }
            }
            .onAppear {
                screenSize = geo.size
                shipPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
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
                    }
            )
        }
    }

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

        // Remove off-screen asteroids (with margin)
        let margin: CGFloat = 150
        asteroids.removeAll { asteroid in
            asteroid.position.x < -margin ||
            asteroid.position.x > size.width + margin ||
            asteroid.position.y < -margin ||
            asteroid.position.y > size.height + margin
        }

        // Spawn asteroids
        spawnAccumulator += dt
        let spawnInterval = max(0.4, 1.5 - elapsedTime * 0.02)
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
        case 0: // top
            startPos = CGPoint(x: CGFloat.random(in: 0...size.width), y: -padding)
        case 1: // bottom
            startPos = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + padding)
        case 2: // left
            startPos = CGPoint(x: -padding, y: CGFloat.random(in: 0...size.height))
        default: // right
            startPos = CGPoint(x: size.width + padding, y: CGFloat.random(in: 0...size.height))
        }

        // Aim toward a random point near center
        let centerVariance: CGFloat = min(size.width, size.height) * 0.3
        let target = CGPoint(
            x: size.width / 2 + CGFloat.random(in: -centerVariance...centerVariance),
            y: size.height / 2 + CGFloat.random(in: -centerVariance...centerVariance)
        )

        let dx = target.x - startPos.x
        let dy = target.y - startPos.y
        let length = sqrt(dx * dx + dy * dy)
        let speed = CGFloat.random(in: 1.5...3.5)
        let velocity = CGVector(dx: dx / length * speed, dy: dy / length * speed)
        let radius = CGFloat.random(in: 12...32)

        let asteroid = AsteroidRock(position: startPos, velocity: velocity, radius: radius)
        asteroids.append(asteroid)
    }

    private func endGame() {
        gameState = .gameOver
        timer?.invalidate()
        timer = nil
    }
}

struct AsteroidShipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Triangle pointing up
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

struct AsteroidStarsView: View {
    let size: CGSize

    private struct AsteroidStar: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let opacity: Double
    }

    private let stars: [AsteroidStar]

    init(size: CGSize) {
        self.size = size
        var generated: [AsteroidStar] = []
        for i in 0..<80 {
            generated.append(AsteroidStar(
                id: i,
                x: CGFloat.random(in: 0...max(size.width, 1)),
                y: CGFloat.random(in: 0...max(size.height, 1)),
                radius: CGFloat.random(in: 0.5...2.0),
                opacity: Double.random(in: 0.3...1.0)
            ))
        }
        stars = generated
    }

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
