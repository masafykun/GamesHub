import SwiftUI

// MARK: - Data Models

struct JumperPlatform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let width: CGFloat = 80
    let height: CGFloat = 12
}

struct JumperPlayer {
    var x: CGFloat
    var y: CGFloat
    let radius: CGFloat = 20
    var velocityY: CGFloat = 0

    var bottom: CGFloat { y + radius }
    var top: CGFloat { y - radius }
    var left: CGFloat { x - radius }
    var right: CGFloat { x + radius }
}

// MARK: - Main View

struct JumperView: View {
    @AppStorage("jumperHighScore") private var highScore: Int = 0

    @State private var player = JumperPlayer(x: 0, y: 0)
    @State private var platforms: [JumperPlatform] = []
    @State private var cameraOffsetY: CGFloat = 0
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var isMovingLeft: Bool = false
    @State private var isMovingRight: Bool = false
    @State private var gameTimer: Timer? = nil
    @State private var screenSize: CGSize = .zero

    private let gravity: CGFloat = 0.3
    private let jumpVelocity: CGFloat = -12
    private let playerSpeed: CGFloat = 3
    private let platformCount: Int = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(red: 0.53, green: 0.81, blue: 0.98)
                    .ignoresSafeArea()

                // Game content
                gameCanvas(size: geo.size)

                // HUD
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                        Spacer()
                        Text("Best: \(highScore)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }

                // Game over overlay
                if isGameOver {
                    gameOverOverlay
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

    // MARK: - Game Canvas

    @ViewBuilder
    private func gameCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Draw platforms
            for platform in platforms {
                let screenY = platform.y - cameraOffsetY
                guard screenY > -20 && screenY < canvasSize.height + 20 else { continue }

                let rect = CGRect(
                    x: platform.x - platform.width / 2,
                    y: screenY,
                    width: platform.width,
                    height: platform.height
                )
                let path = Path(roundedRect: rect, cornerRadius: 6)
                context.fill(path, with: .color(Color(red: 0.2, green: 0.75, blue: 0.3)))
                context.stroke(path, with: .color(Color(red: 0.1, green: 0.55, blue: 0.2)), lineWidth: 2)
            }

            // Draw player
            let playerScreenY = player.y - cameraOffsetY
            let playerRect = CGRect(
                x: player.x - player.radius,
                y: playerScreenY - player.radius,
                width: player.radius * 2,
                height: player.radius * 2
            )
            let playerPath = Path(ellipseIn: playerRect)
            context.fill(playerPath, with: .color(Color(red: 0.95, green: 0.35, blue: 0.3)))

            // Eyes
            let leftEyeRect = CGRect(
                x: player.x - 8,
                y: playerScreenY - 8,
                width: 6,
                height: 6
            )
            let rightEyeRect = CGRect(
                x: player.x + 2,
                y: playerScreenY - 8,
                width: 6,
                height: 6
            )
            context.fill(Path(ellipseIn: leftEyeRect), with: .color(.white))
            context.fill(Path(ellipseIn: rightEyeRect), with: .color(.white))
            let leftPupilRect = CGRect(x: player.x - 6, y: playerScreenY - 6, width: 3, height: 3)
            let rightPupilRect = CGRect(x: player.x + 4, y: playerScreenY - 6, width: 3, height: 3)
            context.fill(Path(ellipseIn: leftPupilRect), with: .color(.black))
            context.fill(Path(ellipseIn: rightPupilRect), with: .color(.black))
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Game Over!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Score: \(score)")
                    .font(.title2)
                    .foregroundColor(.yellow)

                if score >= highScore && score > 0 {
                    Text("New High Score!")
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                Text("Best: \(highScore)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Button(action: {
                    startGame(size: screenSize)
                }) {
                    Text("Restart")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.2, green: 0.6, blue: 0.9))
                        .cornerRadius(14)
                }
            }
            .padding(32)
            .background(Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.9))
            .cornerRadius(24)
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

        let startY = size.height - 100
        platforms = generateInitialPlatforms(size: size, startY: startY)

        // Place player on the first platform (lowest one)
        if let lowestPlatform = platforms.max(by: { $0.y < $1.y }) {
            player = JumperPlayer(
                x: lowestPlatform.x,
                y: lowestPlatform.y - lowestPlatform.height / 2 - 20
            )
        } else {
            player = JumperPlayer(x: size.width / 2, y: startY - 20)
        }
        player.velocityY = jumpVelocity

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            update(size: size)
        }
    }

    private func generateInitialPlatforms(size: CGSize, startY: CGFloat) -> [JumperPlatform] {
        var result: [JumperPlatform] = []
        let spacingBase: CGFloat = size.height * 2 / CGFloat(platformCount)

        for i in 0..<platformCount {
            let yPos = startY - CGFloat(i) * spacingBase
            let xPos = CGFloat.random(in: 50...(size.width - 50))
            result.append(JumperPlatform(x: xPos, y: yPos))
        }
        return result
    }

    // MARK: - Game Update Loop

    private func update(size: CGSize) {
        guard !isGameOver else { return }

        // Horizontal movement
        if isMovingLeft {
            player.x -= playerSpeed
        }
        if isMovingRight {
            player.x += playerSpeed
        }

        // Screen wrap
        if player.x < -player.radius {
            player.x = size.width + player.radius
        } else if player.x > size.width + player.radius {
            player.x = -player.radius
        }

        // Apply gravity
        player.velocityY += gravity

        // Store old bottom for platform collision
        let oldBottom = player.bottom
        player.y += player.velocityY
        let newBottom = player.bottom

        // Platform collision (only when falling down)
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

        // Camera scrolling: follow player up when player reaches top 40% of screen
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

        // Remove platforms that scrolled off the bottom
        let bottomCull = cameraOffsetY + size.height + 20
        platforms.removeAll { $0.y > bottomCull }

        // Add new platforms at the top
        let topEdge = cameraOffsetY - 20
        let neededCount = platformCount - platforms.count
        if neededCount > 0 {
            let highestY = platforms.min(by: { $0.y < $1.y })?.y ?? topEdge
            let spacing = size.height * 2 / CGFloat(platformCount)
            for i in 1...neededCount {
                let yPos = highestY - spacing * CGFloat(i)
                let xPos = CGFloat.random(in: 50...(size.width - 50))
                platforms.append(JumperPlatform(x: xPos, y: yPos))
            }
        }

        // Game over: player fell below bottom of screen
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
    JumperView()
}
