import SwiftUI

// MARK: - Data Models

struct JumperV2Platform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 12
}

struct JumperV2Player {
    var x: CGFloat
    var y: CGFloat
    let radius: CGFloat = 20
    var velocityY: CGFloat = 0

    var bottom: CGFloat { y + radius }
    var top: CGFloat { y - radius }
    var left: CGFloat { x - radius }
    var right: CGFloat { x + radius }
}

enum JumperV2Difficulty: String {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
}

// MARK: - Main View V2

struct JumperViewV2: View {
    @AppStorage("jumperV2HighScore") private var highScore: Int = 0

    @State private var player = JumperV2Player(x: 0, y: 0)
    @State private var platforms: [JumperV2Platform] = []
    @State private var cameraOffsetY: CGFloat = 0
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var isMovingLeft: Bool = false
    @State private var isMovingRight: Bool = false
    @State private var gameTimer: Timer? = nil
    @State private var screenSize: CGSize = .zero

    // Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var currentPlatformWidth: CGFloat = 70
    @State private var currentSpacing: CGFloat = 0
    @State private var difficulty: JumperV2Difficulty = .medium

    // Trail effect
    @State private var trailPositions: [(x: CGFloat, y: CGFloat, age: CGFloat)] = []
    @State private var glowPulse: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0.6

    private let gravity: CGFloat = 0.3
    private let jumpVelocity: CGFloat = -12
    private let playerSpeed: CGFloat = 3
    private let platformCount: Int = 10

    private let baseSpacingMultiplier: CGFloat = 2.0
    private let minPlatformWidth: CGFloat = 50
    private let maxPlatformWidth: CGFloat = 90
    private let baseWidth: CGFloat = 70

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Glassmorphism: gradient sky background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.03, green: 0.05, blue: 0.25),
                        Color(red: 0.1, green: 0.3, blue: 0.65),
                        Color(red: 0.35, green: 0.65, blue: 0.9)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Stars scattered in background
                starsBackground(size: geo.size)

                // Game canvas with glassmorphism
                glassPlatformCanvas(size: geo.size)

                // Frosted glass HUD
                VStack {
                    HStack(spacing: 12) {
                        frostedHUDItem(label: "Score", value: "\(score)")
                        Spacer()
                        difficultyBadge
                        Spacer()
                        frostedHUDItem(label: "Best", value: "\(highScore)")
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }

                // Game over overlay
                if isGameOver {
                    gameOverOverlay(size: geo.size)
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
                computeAdaptiveDifficulty(size: geo.size)
                startGame(size: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                screenSize = newSize
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = 1.4
                glowOpacity = 1.0
            }
        }
    }

    // MARK: - Stars Background

    @ViewBuilder
    private func starsBackground(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let starPositions: [(CGFloat, CGFloat, CGFloat)] = [
                (0.05, 0.08, 2), (0.15, 0.02, 1.5), (0.25, 0.12, 1),
                (0.4, 0.05, 2.5), (0.55, 0.09, 1.5), (0.65, 0.03, 1),
                (0.75, 0.07, 2), (0.88, 0.11, 1.5), (0.95, 0.04, 1),
                (0.1, 0.18, 1.5), (0.3, 0.22, 2), (0.5, 0.15, 1),
                (0.7, 0.19, 2.5), (0.85, 0.25, 1.5), (0.2, 0.28, 1)
            ]
            for (fx, fy, r) in starPositions {
                let rect = CGRect(
                    x: fx * canvasSize.width - r,
                    y: fy * canvasSize.height - r,
                    width: r * 2,
                    height: r * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
            }
        }
    }

    // MARK: - Glass Platform Canvas

    @ViewBuilder
    private func glassPlatformCanvas(size: CGSize) -> some View {
        ZStack {
            // Platforms with glassmorphism
            ForEach(platforms) { platform in
                let screenY = platform.y - cameraOffsetY
                if screenY > -20 && screenY < size.height + 20 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: platform.width, height: platform.height)
                        .position(x: platform.x, y: screenY + platform.height / 2)
                }
            }

            // Player trail effect
            ForEach(0..<trailPositions.count, id: \.self) { i in
                let trail = trailPositions[i]
                let screenY = trail.y - cameraOffsetY
                let alpha = Double(max(0, 1.0 - trail.age / 12.0)) * 0.4
                let scale = 1.0 - trail.age / 20.0
                Circle()
                    .fill(Color(red: 0.4, green: 0.8, blue: 1.0))
                    .frame(width: 40 * scale, height: 40 * scale)
                    .opacity(alpha)
                    .position(x: trail.x, y: screenY)
            }

            // Player glow
            let playerScreenY = player.y - cameraOffsetY
            Circle()
                .fill(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3))
                .frame(width: player.radius * 2 * glowPulse + 16, height: player.radius * 2 * glowPulse + 16)
                .opacity(glowOpacity * 0.5)
                .position(x: player.x, y: playerScreenY)
                .blur(radius: 8)

            // Player body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.95, blue: 1.0),
                            Color(red: 0.4, green: 0.7, blue: 1.0)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: player.radius * 2, height: player.radius * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .position(x: player.x, y: playerScreenY)
        }
    }

    // MARK: - HUD Components

    @ViewBuilder
    private func frostedHUDItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var difficultyBadge: some View {
        let color: Color = {
            switch difficulty {
            case .easy: return Color(red: 0.2, green: 0.8, blue: 0.4)
            case .medium: return Color(red: 0.9, green: 0.7, blue: 0.1)
            case .hard: return Color(red: 0.95, green: 0.3, blue: 0.2)
            }
        }()

        Text(difficulty.rawValue)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.7))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 1.5)
            )
    }

    // MARK: - Game Over Overlay

    @ViewBuilder
    private func gameOverOverlay(size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                Text("Game Over!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Score: \(score)")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.4, green: 0.9, blue: 1.0))

                if score >= highScore && score > 0 {
                    Text("New High Score!")
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                Text("Best: \(highScore)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                if !roundScores.isEmpty {
                    Text("Recent rounds: \(roundScores.suffix(5).map { String($0) }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Button(action: {
                    computeAdaptiveDifficulty(size: size)
                    startGame(size: size)
                }) {
                    Text("Play Again")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.5, blue: 1.0),
                                    Color(red: 0.4, green: 0.8, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.4), radius: 20)
        }
    }

    // MARK: - Adaptive Difficulty

    private func computeAdaptiveDifficulty(size: CGSize) {
        let recentScores = roundScores.suffix(5)
        guard !recentScores.isEmpty else {
            currentPlatformWidth = baseWidth
            currentSpacing = size.height * baseSpacingMultiplier / CGFloat(platformCount)
            difficulty = .medium
            return
        }

        let avg = CGFloat(recentScores.reduce(0, +)) / CGFloat(recentScores.count)
        let threshold: CGFloat = 300

        if avg > threshold * 1.5 {
            // High scores -> harder
            currentPlatformWidth = minPlatformWidth
            currentSpacing = size.height * baseSpacingMultiplier / CGFloat(platformCount) * 1.3
            difficulty = .hard
        } else if avg > threshold * 0.8 {
            // Medium scores
            currentPlatformWidth = baseWidth
            currentSpacing = size.height * baseSpacingMultiplier / CGFloat(platformCount)
            difficulty = .medium
        } else {
            // Low scores -> easier
            currentPlatformWidth = maxPlatformWidth
            currentSpacing = size.height * baseSpacingMultiplier / CGFloat(platformCount) * 0.8
            difficulty = .easy
        }
    }

    // MARK: - Game Setup

    private func startGame(size: CGSize) {
        gameTimer?.invalidate()
        isGameOver = false
        isMovingLeft = false
        isMovingRight = false
        cameraOffsetY = 0
        score = 0
        trailPositions = []

        let startY = size.height - 100
        platforms = generateInitialPlatforms(size: size, startY: startY)

        if let lowestPlatform = platforms.max(by: { $0.y < $1.y }) {
            player = JumperV2Player(
                x: lowestPlatform.x,
                y: lowestPlatform.y - lowestPlatform.height / 2 - 20
            )
        } else {
            player = JumperV2Player(x: size.width / 2, y: startY - 20)
        }
        player.velocityY = jumpVelocity

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            update(size: size)
        }
    }

    private func generateInitialPlatforms(size: CGSize, startY: CGFloat) -> [JumperV2Platform] {
        var result: [JumperV2Platform] = []
        let spacing = currentSpacing > 0 ? currentSpacing : size.height * baseSpacingMultiplier / CGFloat(platformCount)

        for i in 0..<platformCount {
            let yPos = startY - CGFloat(i) * spacing
            let xPos = CGFloat.random(in: 50...(size.width - 50))
            result.append(JumperV2Platform(x: xPos, y: yPos, width: currentPlatformWidth))
        }
        return result
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

        // Trail effect: record position
        trailPositions.append((x: player.x, y: player.y, age: 0))
        if trailPositions.count > 12 {
            trailPositions.removeFirst()
        }
        for i in 0..<trailPositions.count {
            trailPositions[i].age += 1
        }
        trailPositions.removeAll { $0.age > 12 }

        // Apply gravity
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

        // Add new platforms at top
        let neededCount = platformCount - platforms.count
        if neededCount > 0 {
            let spacing = currentSpacing > 0 ? currentSpacing : size.height * baseSpacingMultiplier / CGFloat(platformCount)
            let highestY = platforms.min(by: { $0.y < $1.y })?.y ?? (cameraOffsetY - 20)
            for i in 1...neededCount {
                let yPos = highestY - spacing * CGFloat(i)
                let xPos = CGFloat.random(in: 50...(size.width - 50))
                platforms.append(JumperV2Platform(x: xPos, y: yPos, width: currentPlatformWidth))
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

        // Record this round's score
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores.removeFirst()
        }
    }
}

#Preview {
    JumperViewV2()
}
