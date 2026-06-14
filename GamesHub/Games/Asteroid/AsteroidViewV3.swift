import SwiftUI

// MARK: - Data Models

struct AsteroidRockV3: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
}

enum AsteroidGameStateV3 {
    case waiting
    case playing
    case gameOver
}

// MARK: - LCG Random Number Generator

struct AsteroidLCG {
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

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(nextDouble()) * (range.upperBound - range.lowerBound) + range.lowerBound
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        Int(next() % UInt64(range.count)) + range.lowerBound
    }
}

// MARK: - Main View

struct AsteroidViewV3: View {
    // Seed state — incremented on each restart
    @State var seedInt: Int = 1

    @State private var gameState: AsteroidGameStateV3 = .waiting
    @State private var shipPosition: CGPoint = .zero
    @State private var rocks: [AsteroidRockV3] = []
    @State private var score: Double = 0
    @State private var gameTimer: Timer? = nil
    @State private var screenSize: CGSize = .zero
    @State private var spawnAccumulator: Double = 0
    @State private var elapsedTime: Double = 0
    @State private var lcg: AsteroidLCG = AsteroidLCG(seed: 1)

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Neumorphic background
                Color(.systemGray6)
                    .ignoresSafeArea()

                // Stars layer
                AsteroidStarsV3(size: geo.size, seed: seedInt)

                // Asteroids
                ForEach(rocks) { rock in
                    AsteroidRockShapeV3(radius: rock.radius)
                        .position(rock.position)
                }

                // Player ship
                if gameState == .playing || gameState == .waiting {
                    AsteroidShipV3()
                        .frame(width: 38, height: 38)
                        .position(shipPosition)
                }

                // HUD — score + seed always visible during play/game-over
                VStack {
                    HStack {
                        // Seed badge
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .neumorphicCard()
                            .padding(.leading, 20)
                            .padding(.top, 52)

                        Spacer()

                        // Score badge
                        Text("TIME: \(Int(score))s")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .neumorphicCard()
                            .padding(.trailing, 20)
                            .padding(.top, 52)
                    }
                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    AsteroidWaitingOverlayV3(seedInt: seedInt)
                }

                // Game Over overlay
                if gameState == .gameOver {
                    AsteroidGameOverOverlayV3(score: score, seedInt: seedInt)
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
            // Tap to restart after game over (separate overlay handles visual, this catches tap)
            .onTapGesture {
                if gameState == .gameOver {
                    seedInt += 1
                    startGame(size: geo.size)
                }
            }
        }
    }

    // MARK: - Game Logic

    private func startGame(size: CGSize) {
        rocks = []
        score = 0
        elapsedTime = 0
        spawnAccumulator = 0
        shipPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        lcg = AsteroidLCG(seed: seedInt)
        gameState = .playing

        gameTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            gameLoop(size: size)
        }
        RunLoop.main.add(t, forMode: .common)
        gameTimer = t
    }

    private func gameLoop(size: CGSize) {
        guard gameState == .playing else { return }

        let dt = 1.0 / 60.0
        elapsedTime += dt
        score = elapsedTime

        // Move rocks
        for i in rocks.indices {
            rocks[i].position.x += rocks[i].velocity.dx
            rocks[i].position.y += rocks[i].velocity.dy
        }

        // Remove off-screen rocks
        let margin: CGFloat = 160
        rocks.removeAll { r in
            r.position.x < -margin ||
            r.position.x > size.width + margin ||
            r.position.y < -margin ||
            r.position.y > size.height + margin
        }

        // Spawn rocks using seeded LCG
        spawnAccumulator += dt
        let spawnInterval = max(0.35, 1.5 - elapsedTime * 0.025)
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            let extraCount = Int(elapsedTime / 12)
            let count = 1 + extraCount
            for _ in 0..<count {
                spawnRock(size: size)
            }
        }

        // Collision detection
        let shipRadius: CGFloat = 14
        for rock in rocks {
            let dx = rock.position.x - shipPosition.x
            let dy = rock.position.y - shipPosition.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < shipRadius + rock.radius - 5 {
                endGame()
                return
            }
        }
    }

    private func spawnRock(size: CGSize) {
        // Seeded edge selection
        let edge = lcg.nextInt(in: 0..<4)
        var startPos: CGPoint
        let padding: CGFloat = 30

        switch edge {
        case 0: // top
            startPos = CGPoint(
                x: lcg.nextCGFloat(in: 0...size.width),
                y: -padding
            )
        case 1: // bottom
            startPos = CGPoint(
                x: lcg.nextCGFloat(in: 0...size.width),
                y: size.height + padding
            )
        case 2: // left
            startPos = CGPoint(
                x: -padding,
                y: lcg.nextCGFloat(in: 0...size.height)
            )
        default: // right
            startPos = CGPoint(
                x: size.width + padding,
                y: lcg.nextCGFloat(in: 0...size.height)
            )
        }

        // Seeded angle: aim toward a random point near center
        let centerVariance: CGFloat = min(size.width, size.height) * 0.3
        let target = CGPoint(
            x: size.width / 2 + lcg.nextCGFloat(in: -centerVariance...centerVariance),
            y: size.height / 2 + lcg.nextCGFloat(in: -centerVariance...centerVariance)
        )

        let dx = target.x - startPos.x
        let dy = target.y - startPos.y
        let length = sqrt(dx * dx + dy * dy)
        // Seeded speed
        let speed = lcg.nextCGFloat(in: 1.4...3.8)
        let velocity = CGVector(dx: dx / length * speed, dy: dy / length * speed)
        // Seeded size
        let radius = lcg.nextCGFloat(in: 10...34)

        let rock = AsteroidRockV3(position: startPos, velocity: velocity, radius: radius)
        rocks.append(rock)
    }

    private func endGame() {
        gameState = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil
    }
}

// MARK: - Rock Shape

struct AsteroidRockShapeV3: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray3),
                            Color(.systemGray5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 3, y: 3)
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: -2, y: -2)

            Circle()
                .stroke(Color(.systemGray4), lineWidth: 1)
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// MARK: - Ship

struct AsteroidShipV3: View {
    var body: some View {
        ZStack {
            AsteroidShipShapeV3()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan, Color.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            AsteroidShipShapeV3()
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
        }
        .shadow(color: .cyan.opacity(0.7), radius: 8)
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 2, y: 2)
    }
}

struct AsteroidShipShapeV3: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Stars

struct AsteroidStarsV3: View {
    let size: CGSize
    let seed: Int

    private struct AsteroidStarDataV3: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let opacity: Double
    }

    private let stars: [AsteroidStarDataV3]

    init(size: CGSize, seed: Int) {
        self.size = size
        self.seed = seed
        var lcg = AsteroidLCG(seed: seed &+ 9999)
        var generated: [AsteroidStarDataV3] = []
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        for i in 0..<80 {
            generated.append(AsteroidStarDataV3(
                id: i,
                x: lcg.nextCGFloat(in: 0...w),
                y: lcg.nextCGFloat(in: 0...h),
                radius: lcg.nextCGFloat(in: 0.5...2.0),
                opacity: Double(lcg.nextCGFloat(in: 0.2...0.9))
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
                // Tint stars slightly blue for dark-mode contrast against systemGray6
                context.fill(Path(ellipseIn: rect), with: .color(Color(.systemGray)))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Overlays

struct AsteroidWaitingOverlayV3: View {
    let seedInt: Int

    var body: some View {
        VStack(spacing: 28) {
            Text("ASTEROID DODGE")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(.primary)

            Text("V3 · SEED: #\(seedInt)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)

            Text("Drag to move your ship")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text("TAP TO START")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .neumorphicCard()
        }
        .padding(32)
        .neumorphicCard()
    }
}

struct AsteroidGameOverOverlayV3: View {
    let score: Double
    let seedInt: Int

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.65)
                .ignoresSafeArea()
                .blur(radius: 2)

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.red)

                VStack(spacing: 8) {
                    Text("SURVIVED: \(Int(score))s")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .neumorphicCard()

                Text("TAP TO PLAY AGAIN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .neumorphicCard()
            }
            .padding(36)
            .neumorphicCard()
        }
    }
}
