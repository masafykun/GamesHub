import SwiftUI

// MARK: - LCG Procedural Generator

struct JumperV3LCG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        // Warm up the generator
        for _ in 0..<10 { _ = next() }
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let raw = next()
        let normalized = CGFloat(raw) / CGFloat(UInt64.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Data Models

struct JumperV3Platform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let width: CGFloat = 80
    let height: CGFloat = 12
}

struct JumperV3Player {
    var x: CGFloat
    var y: CGFloat
    let radius: CGFloat = 20
    var velocityY: CGFloat = 0

    var bottom: CGFloat { y + radius }
    var top: CGFloat { y - radius }
}

// MARK: - Main View V3

struct JumperViewV3: View {
    @AppStorage("jumperV3HighScore") private var highScore: Int = 0

    @State private var player = JumperV3Player(x: 0, y: 0)
    @State private var platforms: [JumperV3Platform] = []
    @State private var cameraOffsetY: CGFloat = 0
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var isMovingLeft: Bool = false
    @State private var isMovingRight: Bool = false
    @State private var gameTimer: Timer? = nil
    @State private var screenSize: CGSize = .zero

    @State var seedInt: Int = 1
    @State private var rng = JumperV3LCG(seed: 1)

    private let gravity: CGFloat = 0.3
    private let jumpVelocity: CGFloat = -12
    private let playerSpeed: CGFloat = 3
    private let platformCount: Int = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Neumorphism: systemGray6 background, muted sky
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.82, green: 0.86, blue: 0.92),
                        Color(.systemGray6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Game canvas
                neumorphicGameCanvas(size: geo.size)

                // HUD
                VStack {
                    HStack(spacing: 12) {
                        neumorphicHUDItem(label: "Score", value: "\(score)")
                        Spacer()
                        neumorphicHUDItem(label: "SEED: #\(seedInt)", value: "")
                        Spacer()
                        neumorphicHUDItem(label: "Best", value: "\(highScore)")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }

                // Game over overlay
                if isGameOver {
                    neumorphicGameOverOverlay(size: geo.size)
                }

                // Input gesture layer
                if !isGameOver {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if value.location.x < geo.size.width / 2 {
                                        isMovingLeft = true
                                        isMovingRight = false
                                    } else {
                                        isMovingLeft = false
                                        isMovingRight = true
                                    }
                                }
                                .onEnded { _ in
                                    isMovingLeft = false
                                    isMovingRight = false
                                }
                        )
                }
            }
            .onAppear {
                screenSize = geo.size
                startGame(size: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                screenSize = newSize
            }
        }
    }

    // MARK: - Neumorphic Game Canvas

    @ViewBuilder
    private func neumorphicGameCanvas(size: CGSize) -> some View {
        ZStack {
            // Platforms with neumorphic cards
            ForEach(platforms) { platform in
                let screenY = platform.y - cameraOffsetY
                if screenY > -20 && screenY < size.height + 20 {
                    neumorphicPlatform(platform: platform, screenY: screenY)
                }
            }

            // Player: soft shadow neumorphic circle
            let playerScreenY = player.y - cameraOffsetY
            neumorphicPlayer(screenY: playerScreenY)
        }
    }

    @ViewBuilder
    private func neumorphicPlatform(platform: JumperV3Platform, screenY: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.9), radius: 4, x: -3, y: -3)
                .shadow(color: Color(.systemGray4).opacity(0.7), radius: 4, x: 3, y: 3)
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.78, blue: 0.86).opacity(0.5),
                            Color(.systemGray5).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: platform.width, height: platform.height)
        .position(x: platform.x, y: screenY + platform.height / 2)
    }

    @ViewBuilder
    private func neumorphicPlayer(screenY: CGFloat) -> some View {
        ZStack {
            // Outer soft shadow circle
            Circle()
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.95), radius: 8, x: -5, y: -5)
                .shadow(color: Color(.systemGray4).opacity(0.7), radius: 8, x: 5, y: 5)
                .frame(width: player.radius * 2 + 8, height: player.radius * 2 + 8)

            // Inner gradient fill
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.75, green: 0.80, blue: 0.90),
                            Color(red: 0.58, green: 0.64, blue: 0.74)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: player.radius * 2, height: player.radius * 2)

            // Eyes
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.3, green: 0.35, blue: 0.45))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color(red: 0.3, green: 0.35, blue: 0.45))
                    .frame(width: 6, height: 6)
            }
            .offset(y: -4)
        }
        .position(x: player.x, y: screenY)
    }

    // MARK: - Neumorphic HUD Components

    @ViewBuilder
    private func neumorphicHUDItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(Color(red: 0.45, green: 0.5, blue: 0.58))
            if !value.isEmpty {
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(Color(red: 0.35, green: 0.4, blue: 0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .neumorphicCard(radius: 10)
    }

    // MARK: - Game Over Overlay (Neumorphic)

    @ViewBuilder
    private func neumorphicGameOverOverlay(size: CGSize) -> some View {
        ZStack {
            Color(.systemGray6).opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Game Over!")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color(red: 0.35, green: 0.4, blue: 0.52))

                Text("Score: \(score)")
                    .font(.title2.bold())
                    .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.7))

                if score >= highScore && score > 0 {
                    Text("New High Score!")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.3))
                }

                Text("Best: \(highScore)")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.65))

                Text("Seed was: #\(seedInt)")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.55, green: 0.6, blue: 0.7))

                Button(action: {
                    seedInt += 1
                    rng = JumperV3LCG(seed: seedInt)
                    startGame(size: size)
                }) {
                    Text("New Seed")
                        .font(.title3.bold())
                        .foregroundColor(Color(red: 0.35, green: 0.42, blue: 0.58))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                }

                Button(action: {
                    rng = JumperV3LCG(seed: seedInt)
                    startGame(size: size)
                }) {
                    Text("Replay Seed #\(seedInt)")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.65))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .neumorphicCard(radius: 12)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
        }
    }

    // MARK: - Procedural Platform Generation

    private func generatePlatformsWithSeed(size: CGSize, startY: CGFloat, count: Int, topY: CGFloat? = nil) -> [JumperV3Platform] {
        var result: [JumperV3Platform] = []
        let spacing = size.height * 2.0 / CGFloat(count)
        let baseY = topY ?? startY

        for i in 0..<count {
            let yPos = baseY - CGFloat(i) * spacing
            let xPos = rng.nextCGFloat(in: 50...(size.width - 50))
            result.append(JumperV3Platform(x: xPos, y: yPos))
        }
        return result
    }

    // MARK: - Game Setup

    private func startGame(size: CGSize) {
        gameTimer?.invalidate()
        isGameOver = false
        isMovingLeft = false
        isMovingRight = false
        cameraOffsetY = 0
        score = 0

        rng = JumperV3LCG(seed: seedInt)

        let startY = size.height - 100
        platforms = generatePlatformsWithSeed(size: size, startY: startY, count: platformCount)

        if let lowestPlatform = platforms.max(by: { $0.y < $1.y }) {
            player = JumperV3Player(
                x: lowestPlatform.x,
                y: lowestPlatform.y - lowestPlatform.height / 2 - 20
            )
        } else {
            player = JumperV3Player(x: size.width / 2, y: startY - 20)
        }
        player.velocityY = jumpVelocity

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            update(size: size)
        }
    }

    // MARK: - Game Update Loop

    private func update(size: CGSize) {
        guard !isGameOver else { return }

        // Horizontal movement
        if isMovingLeft { player.x -= playerSpeed }
        if isMovingRight { player.x += playerSpeed }

        // Screen wrap
        if player.x < -player.radius {
            player.x = size.width + player.radius
        } else if player.x > size.width + player.radius {
            player.x = -player.radius
        }

        // Gravity
        player.velocityY += gravity
        let oldBottom = player.bottom
        player.y += player.velocityY
        let newBottom = player.bottom

        // Platform collision
        if player.velocityY > 0 {
            for platform in platforms {
                let platTop = platform.y
                let platLeft = platform.x - platform.width / 2
                let platRight = platform.x + platform.width / 2

                if oldBottom <= platTop &&
                    newBottom >= platTop &&
                    newBottom <= platTop + 10 &&
                    player.x >= platLeft &&
                    player.x <= platRight {
                    player.y = platTop - player.radius
                    player.velocityY = jumpVelocity
                    break
                }
            }
        }

        // Camera scrolling
        let playerScreenY = player.y - cameraOffsetY
        let scrollThreshold = size.height * 0.4
        if playerScreenY < scrollThreshold {
            let delta = scrollThreshold - playerScreenY
            cameraOffsetY -= delta
            score += Int(delta / 10)
            if score > highScore {
                highScore = score
            }
        }

        // Cull platforms off bottom
        let bottomCull = cameraOffsetY + size.height + 20
        platforms.removeAll { $0.y > bottomCull }

        // Add new platforms seeded at top
        let neededCount = platformCount - platforms.count
        if neededCount > 0 {
            let spacing = size.height * 2.0 / CGFloat(platformCount)
            let highestY = platforms.min(by: { $0.y < $1.y })?.y ?? (cameraOffsetY - 20)
            for i in 1...neededCount {
                let yPos = highestY - spacing * CGFloat(i)
                let xPos = rng.nextCGFloat(in: 50...(size.width - 50))
                platforms.append(JumperV3Platform(x: xPos, y: yPos))
            }
        }

        // Game over
        let playerScreenBottom = player.bottom - cameraOffsetY
        if playerScreenBottom > size.height + 50 {
            endGame()
        }
    }

    private func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        isGameOver = true
        isMovingLeft = false
        isMovingRight = false
    }
}

#Preview {
    JumperViewV3()
}
