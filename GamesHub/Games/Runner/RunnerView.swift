import SwiftUI

// MARK: - Data Models

enum RunnerGameState {
    case waiting
    case playing
    case gameOver
}

struct RunnerObstacle: Identifiable {
    let id = UUID()
    var lane: Int
    var yPosition: CGFloat
}

enum RunnerDifficulty {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var labelColor: Color {
        switch self {
        case .easy:   return Color.green
        case .medium: return Color.orange
        case .hard:   return Color.red
        }
    }
}

// MARK: - Main View

struct RunnerView: View {
    // MARK: Game State
    @State private var gameState: RunnerGameState = .waiting
    @State private var playerLane: Int = 1
    @State private var obstacles: [RunnerObstacle] = []
    @State private var score: Int = 0
    @State private var obstacleSpeed: CGFloat = 180
    @AppStorage("runnerHighScore") private var highScore: Int = 0

    // MARK: Timers
    @State private var scoreTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil

    // MARK: Layout Constants
    private let laneCount: Int = 3
    private let playerHeight: CGFloat = 50
    private let playerWidth: CGFloat = 40
    private let obstacleHeight: CGFloat = 30
    private let obstacleWidth: CGFloat = 54
    private let spawnInterval: TimeInterval = 1.5
    private let frameRate: TimeInterval = 1.0 / 60.0

    // MARK: Neon Colors
    private let neonBlue   = Color(red: 0.0,  green: 0.8,  blue: 1.0)
    private let neonPurple = Color(red: 0.6,  green: 0.0,  blue: 1.0)
    private let neonPink   = Color(red: 1.0,  green: 0.0,  blue: 0.6)
    private let neonGreen  = Color(red: 0.0,  green: 1.0,  blue: 0.5)

    // MARK: Computed Difficulty
    private var currentDifficulty: RunnerDifficulty {
        if obstacleSpeed >= 240 { return .hard }
        if obstacleSpeed >= 200 { return .medium }
        return .easy
    }

    var body: some View {
        GeometryReader { geo in
            let laneWidth = geo.size.width / CGFloat(laneCount)
            let playerY = geo.size.height * 0.75

            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Lane backgrounds with subtle gradient
                ForEach(0..<laneCount, id: \.self) { i in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: laneWidth - 2, height: geo.size.height)
                        .position(x: laneX(lane: i, laneWidth: laneWidth), y: geo.size.height / 2)
                }

                // Neon lane separators
                ForEach(1..<laneCount, id: \.self) { i in
                    neonSeparator(at: laneWidth * CGFloat(i), height: geo.size.height)
                }

                // Obstacles with gradient + glow
                ForEach(obstacles) { obstacle in
                    RunnerObstacleView(
                        width: obstacleWidth,
                        height: obstacleHeight,
                        neonPink: neonPink,
                        neonPurple: neonPurple
                    )
                    .position(
                        x: laneX(lane: obstacle.lane, laneWidth: laneWidth),
                        y: obstacle.yPosition
                    )
                }

                // Player with accent glow
                Circle()
                    .fill(neonBlue)
                    .frame(width: playerWidth, height: playerWidth)
                    .shadow(color: neonBlue.opacity(0.8), radius: 14)
                    .shadow(color: neonBlue.opacity(0.4), radius: 28)
                    .position(
                        x: laneX(lane: playerLane, laneWidth: laneWidth),
                        y: playerY
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.62, blendDuration: 0), value: playerLane)

                // Glassmorphism HUD
                VStack {
                    RunnerHUDCard(
                        score: score,
                        highScore: highScore,
                        difficulty: currentDifficulty,
                        neonBlue: neonBlue,
                        neonGreen: neonGreen
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 52)
                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    RunnerWaitingOverlay(neonBlue: neonBlue, neonPurple: neonPurple)
                        .onTapGesture { startGame(geo: geo) }
                }

                // Game over overlay
                if gameState == .gameOver {
                    RunnerGameOverOverlay(
                        score: score,
                        highScore: highScore,
                        neonBlue: neonBlue,
                        neonPink: neonPink,
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

    // MARK: - Sub-views

    @ViewBuilder
    private func neonSeparator(at x: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(neonPurple.opacity(0.6))
                .frame(width: 2, height: height)
                .blur(radius: 3)
            Rectangle()
                .fill(neonPurple.opacity(0.9))
                .frame(width: 1, height: height)
        }
        .position(x: x, y: height / 2)
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
        startTimers(geo: geo)
    }

    private func restartGame(geo: GeometryProxy) {
        stopAllTimers()
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

    // MARK: - Obstacle Management

    private func spawnObstacle() {
        let lane = Int.random(in: 0..<laneCount)
        obstacles.append(RunnerObstacle(lane: lane, yPosition: -obstacleHeight / 2))
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

// MARK: - Obstacle View

struct RunnerObstacleView: View {
    let width: CGFloat
    let height: CGFloat
    let neonPink: Color
    let neonPurple: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: [neonPink, neonPurple], startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: height)
            .shadow(color: neonPink.opacity(0.7), radius: 8)
            .shadow(color: neonPurple.opacity(0.4), radius: 16)
    }
}

// MARK: - HUD Card

struct RunnerHUDCard: View {
    let score: Int
    let highScore: Int
    let difficulty: RunnerDifficulty
    let neonBlue: Color
    let neonGreen: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(score)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(neonBlue)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Difficulty: \(difficulty.label)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(difficulty.labelColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(difficulty.labelColor.opacity(0.15))
                    .cornerRadius(8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(highScore)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(neonGreen)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Waiting Overlay

struct RunnerWaitingOverlay: View {
    let neonBlue: Color
    let neonPurple: Color

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("LANE RUNNER")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [neonBlue, neonPurple], startPoint: .leading, endPoint: .trailing))

                Text("Swipe left/right to switch lanes")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text("Tap to Start")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 13)
                    .background(neonBlue)
                    .cornerRadius(14)
                    .shadow(color: neonBlue.opacity(0.6), radius: 12)
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
    }
}

// MARK: - Game Over Overlay

struct RunnerGameOverOverlay: View {
    let score: Int
    let highScore: Int
    let neonBlue: Color
    let neonPink: Color
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("GAME OVER")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [neonPink, Color.red], startPoint: .leading, endPoint: .trailing))

                VStack(spacing: 8) {
                    Text("Score: \(score)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Best: \(highScore)")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(neonBlue)
                }

                Button(action: onRestart) {
                    Text("Restart")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(neonBlue)
                        .cornerRadius(14)
                        .shadow(color: neonBlue.opacity(0.7), radius: 10)
                }
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .cornerRadius(26)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

#Preview {
    RunnerView()
}
