import SwiftUI

// MARK: - Data Models

enum RunnerV3GameState {
    case waiting
    case playing
    case gameOver
}

struct RunnerV3Obstacle: Identifiable {
    let id = UUID()
    var lane: Int
    var yPosition: CGFloat
}

// MARK: - LCG RNG

struct RunnerV3LCG {
    var state: Int

    init(seed: Int) {
        state = seed
    }

    mutating func next(mod: Int) -> Int {
        state = (state &* 1664525 &+ 1013904223) & 0x7FFFFFFF
        return state % mod
    }
}

// MARK: - Main View

struct RunnerViewV3: View {
    // MARK: Game State
    @State private var gameState: RunnerV3GameState = .waiting
    @State private var playerLane: Int = 1
    @State private var obstacles: [RunnerV3Obstacle] = []
    @State private var score: Int = 0
    @State private var obstacleSpeed: CGFloat = 180
    @AppStorage("runnerV3HighScore") private var highScore: Int = 0

    // MARK: Procedural Seed
    @State private var seedInt: Int = 1
    @State private var rng: RunnerV3LCG = RunnerV3LCG(seed: 1)

    // MARK: Timers
    @State private var scoreTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil

    // MARK: Layout Constants
    private let laneCount: Int = 3
    private let playerHeight: CGFloat = 48
    private let playerWidth: CGFloat = 38
    private let obstacleHeight: CGFloat = 28
    private let obstacleWidth: CGFloat = 52
    private let spawnInterval: TimeInterval = 1.5
    private let frameRate: TimeInterval = 1.0 / 60.0

    // MARK: Neumorphic Colors
    private let bgColor = Color(.systemGray6)
    private let obstacleColor = Color(red: 0.55, green: 0.60, blue: 0.68)
    private let playerColor = Color(red: 0.35, green: 0.50, blue: 0.85)
    private let accentColor = Color(red: 0.40, green: 0.55, blue: 0.90)

    var body: some View {
        GeometryReader { geo in
            let laneWidth = geo.size.width / CGFloat(laneCount)
            let playerY = geo.size.height * 0.75

            ZStack {
                // Neumorphic background
                bgColor.ignoresSafeArea()

                // Lane panels
                HStack(spacing: 0) {
                    ForEach(0..<laneCount, id: \.self) { i in
                        RunnerV3LanePanel(
                            width: laneWidth,
                            height: geo.size.height,
                            isCenter: i == 1
                        )
                    }
                }

                // Obstacles — neumorphic rectangles with muted color
                ForEach(obstacles) { obstacle in
                    RunnerV3ObstacleView(
                        width: obstacleWidth,
                        height: obstacleHeight,
                        color: obstacleColor
                    )
                    .position(
                        x: laneX(lane: obstacle.lane, laneWidth: laneWidth),
                        y: obstacle.yPosition
                    )
                }

                // Player — neumorphic circle with accent
                RunnerV3PlayerView(
                    size: playerWidth,
                    color: playerColor,
                    accentColor: accentColor
                )
                .position(
                    x: laneX(lane: playerLane, laneWidth: laneWidth),
                    y: playerY
                )
                .animation(.easeInOut(duration: 0.16), value: playerLane)

                // HUD
                VStack {
                    RunnerV3HUD(score: score, highScore: highScore, seedInt: seedInt, accentColor: accentColor)
                        .padding(.horizontal, 16)
                        .padding(.top, 52)
                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    RunnerV3WaitingOverlay(accentColor: accentColor, seedInt: seedInt)
                        .onTapGesture { startGame(geo: geo) }
                }

                // Game over overlay
                if gameState == .gameOver {
                    RunnerV3GameOverOverlay(
                        score: score,
                        highScore: highScore,
                        seedInt: seedInt,
                        accentColor: accentColor,
                        onRestart: { restartGame(geo: geo) }
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if gameState == .playing {
                            handleSwipe(value: value)
                        }
                    }
            )
            .onTapGesture {
                if gameState == .waiting {
                    startGame(geo: geo)
                }
            }
            .onDisappear { stopAllTimers() }
        }
    }

    // MARK: - Helpers

    private func laneX(lane: Int, laneWidth: CGFloat) -> CGFloat {
        laneWidth * CGFloat(lane) + laneWidth / 2
    }

    // MARK: - Gesture

    private func handleSwipe(value: DragGesture.Value) {
        let tx = value.translation.width
        if tx < -30 && playerLane > 0 {
            playerLane -= 1
        } else if tx > 30 && playerLane < laneCount - 1 {
            playerLane += 1
        }
    }

    // MARK: - Game Control

    private func startGame(geo: GeometryProxy) {
        gameState = .playing
        playerLane = 1
        obstacles = []
        score = 0
        obstacleSpeed = 180
        rng = RunnerV3LCG(seed: seedInt)
        startTimers(geo: geo)
    }

    private func restartGame(geo: GeometryProxy) {
        stopAllTimers()
        seedInt += 1
        startGame(geo: geo)
    }

    private func endGame() {
        gameState = .gameOver
        if score > highScore { highScore = score }
        stopAllTimers()
    }

    // MARK: - Timers

    private func startTimers(geo: GeometryProxy) {
        scoreTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            score += 1
            if score % 10 == 0 { obstacleSpeed += 20 }
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnObstacle()
        }

        moveTimer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
            updateObstacles(geo: geo)
        }
    }

    private func stopAllTimers() {
        scoreTimer?.invalidate(); scoreTimer = nil
        spawnTimer?.invalidate(); spawnTimer = nil
        moveTimer?.invalidate();  moveTimer = nil
    }

    // MARK: - Obstacle Management (Seeded)

    private func spawnObstacle() {
        let lane = rng.next(mod: laneCount)
        obstacles.append(RunnerV3Obstacle(lane: lane, yPosition: -obstacleHeight / 2))
    }

    private func updateObstacles(geo: GeometryProxy) {
        let playerY = geo.size.height * 0.75
        let delta = obstacleSpeed * CGFloat(frameRate)

        for i in obstacles.indices {
            obstacles[i].yPosition += delta
        }

        for obstacle in obstacles {
            let yDiff = abs(obstacle.yPosition - playerY)
            if yDiff < (playerHeight / 2 + obstacleHeight / 2) && obstacle.lane == playerLane {
                endGame()
                return
            }
        }

        obstacles.removeAll { $0.yPosition > geo.size.height + obstacleHeight }
    }
}

// MARK: - Lane Panel

struct RunnerV3LanePanel: View {
    let width: CGFloat
    let height: CGFloat
    let isCenter: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(width: width, height: height)
                .shadow(color: .white.opacity(0.8), radius: 6, x: -3, y: -3)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 3, y: 3)

            if isCenter {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: width - 8, height: height - 8)
                    .cornerRadius(10)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Obstacle View

struct RunnerV3ObstacleView: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: width, height: height)
            .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
    }
}

// MARK: - Player View

struct RunnerV3PlayerView: View {
    let size: CGFloat
    let color: Color
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: size + 12, height: size + 12)
                .shadow(color: .white.opacity(0.9), radius: 6, x: -3, y: -3)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 3, y: 3)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.9), color],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)
        }
    }
}

// MARK: - HUD

struct RunnerV3HUD: View {
    let score: Int
    let highScore: Int
    let seedInt: Int
    let accentColor: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(accentColor)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(highScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .neumorphicCard(radius: 16)
    }
}

// MARK: - Waiting Overlay

struct RunnerV3WaitingOverlay: View {
    let accentColor: Color
    let seedInt: Int

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("LANE RUNNER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("Swipe left/right to change lanes")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Text("Tap to Start")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 13)
                    .neumorphicCard(radius: 14)
            }
            .padding(36)
            .neumorphicCard(radius: 24)
        }
    }
}

// MARK: - Game Over Overlay

struct RunnerV3GameOverOverlay: View {
    let score: Int
    let highScore: Int
    let seedInt: Int
    let accentColor: Color
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("GAME OVER")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Score: \(score)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor)
                    Text("Best: \(highScore)")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button(action: onRestart) {
                    Text("New Game")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 13)
                        .neumorphicCard(radius: 14)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(36)
            .neumorphicCard(radius: 26)
        }
    }
}

#Preview {
    RunnerViewV3()
}
