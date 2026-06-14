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

    // MARK: Gesture State
    @State private var dragStartX: CGFloat = 0

    // MARK: Layout Constants
    private let laneCount: Int = 3
    private let playerHeight: CGFloat = 50
    private let playerWidth: CGFloat = 40
    private let obstacleHeight: CGFloat = 30
    private let obstacleWidth: CGFloat = 50
    private let spawnInterval: TimeInterval = 1.5
    private let frameRate: TimeInterval = 1.0 / 60.0

    var body: some View {
        GeometryReader { geo in
            let laneWidth = geo.size.width / CGFloat(laneCount)
            let playerY = geo.size.height * 0.75

            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Lane separators
                ForEach(1..<laneCount, id: \.self) { i in
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 2, height: geo.size.height)
                        .position(x: laneWidth * CGFloat(i), y: geo.size.height / 2)
                }

                // Lane backgrounds
                ForEach(0..<laneCount, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(width: laneWidth - 2, height: geo.size.height)
                        .position(x: laneX(lane: i, laneWidth: laneWidth), y: geo.size.height / 2)
                }

                // Obstacles
                ForEach(obstacles) { obstacle in
                    Rectangle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: obstacleWidth, height: obstacleHeight)
                        .cornerRadius(6)
                        .position(
                            x: laneX(lane: obstacle.lane, laneWidth: laneWidth),
                            y: obstacle.yPosition
                        )
                }

                // Player
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cyan)
                    .frame(width: playerWidth, height: playerHeight)
                    .position(
                        x: laneX(lane: playerLane, laneWidth: laneWidth),
                        y: playerY
                    )
                    .animation(.easeInOut(duration: 0.15), value: playerLane)

                // HUD
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Best: \(highScore)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    RunnerWaitingOverlay()
                }

                // Game over overlay
                if gameState == .gameOver {
                    RunnerGameOverOverlay(
                        score: score,
                        highScore: highScore,
                        onRestart: { restartGame(geo: geo) }
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if gameState == .playing {
                            handleDrag(value: value)
                        }
                    }
                    .onEnded { _ in
                        dragStartX = 0
                    }
            )
            .onTapGesture {
                if gameState == .waiting {
                    startGame(geo: geo)
                }
            }
            .onDisappear {
                stopAllTimers()
            }
        }
    }

    // MARK: - Helpers

    private func laneX(lane: Int, laneWidth: CGFloat) -> CGFloat {
        laneWidth * CGFloat(lane) + laneWidth / 2
    }

    // MARK: - Gesture

    private func handleDrag(value: DragGesture.Value) {
        let translationX = value.translation.width
        if abs(translationX) > 30 {
            if translationX < 0 && playerLane > 0 {
                playerLane -= 1
                dragStartX = value.location.x
            } else if translationX > 0 && playerLane < laneCount - 1 {
                playerLane += 1
                dragStartX = value.location.x
            }
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
        if score > highScore {
            highScore = score
        }
        stopAllTimers()
    }

    // MARK: - Timers

    private func startTimers(geo: GeometryProxy) {
        // Score timer — 1 point per second
        scoreTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            score += 1
            // Increase speed every 10 points
            if score % 10 == 0 {
                obstacleSpeed += 20
            }
        }

        // Spawn timer
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnObstacle()
        }

        // Move / collision timer at ~60fps
        moveTimer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
            updateObstacles(geo: geo)
        }
    }

    private func stopAllTimers() {
        scoreTimer?.invalidate()
        scoreTimer = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
    }

    // MARK: - Obstacle Management

    private func spawnObstacle() {
        let lane = Int.random(in: 0..<laneCount)
        let obstacle = RunnerObstacle(lane: lane, yPosition: -obstacleHeight / 2)
        obstacles.append(obstacle)
    }

    private func updateObstacles(geo: GeometryProxy) {
        let playerY = geo.size.height * 0.75
        let delta = obstacleSpeed * CGFloat(frameRate)

        // Move obstacles downward
        for i in obstacles.indices {
            obstacles[i].yPosition += delta
        }

        // Collision detection
        for obstacle in obstacles {
            let yDiff = abs(obstacle.yPosition - playerY)
            if yDiff < (playerHeight / 2 + obstacleHeight / 2) && obstacle.lane == playerLane {
                endGame()
                return
            }
        }

        // Remove off-screen obstacles
        obstacles.removeAll { $0.yPosition > geo.size.height + obstacleHeight }
    }
}

// MARK: - Supporting Views

struct RunnerWaitingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("LANE RUNNER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Swipe left/right to switch lanes")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                Text("Tap to Start")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(12)
            }
        }
    }
}

struct RunnerGameOverOverlay: View {
    let score: Int
    let highScore: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.red)

                VStack(spacing: 8) {
                    Text("Score: \(score)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Best: \(highScore)")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                Button(action: onRestart) {
                    Text("Restart")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .cornerRadius(14)
                }
            }
            .padding(36)
            .background(Color.white.opacity(0.07))
            .cornerRadius(24)
        }
    }
}

#Preview {
    RunnerView()
}
