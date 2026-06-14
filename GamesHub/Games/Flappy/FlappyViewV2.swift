import SwiftUI

// MARK: - Game State

enum FlappyV2GameState {
    case waiting
    case playing
    case gameOver
}

// MARK: - Difficulty

enum FlappyV2DifficultyLevel: String {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
    case extreme = "EXTREME"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .extreme: return .red
        }
    }

    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        case .extreme: return "bolt.fill"
        }
    }
}

// MARK: - Pipe Model

struct FlappyV2Pipe: Identifiable {
    let id: UUID
    var x: CGFloat
    let gapY: CGFloat
    var passed: Bool

    init(x: CGFloat, gapY: CGFloat) {
        self.id = UUID()
        self.x = x
        self.gapY = gapY
        self.passed = false
    }
}

// MARK: - Main View

struct FlappyViewV2: View {
    // Game state
    @State private var gameState: FlappyV2GameState = .waiting
    @State private var birdY: CGFloat = 0
    @State private var birdVelocity: CGFloat = 0
    @State private var pipes: [FlappyV2Pipe] = []
    @State private var score: Int = 0
    @State private var pipeSpawnTimer: CGFloat = 0
    @State private var scorePopScale: CGFloat = 1.0

    // Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var pipeSpeed: CGFloat = 3.0
    @State private var gapHeight: CGFloat = 160.0
    @State private var previousAverageScore: Double = 0.0
    @State private var currentDifficulty: FlappyV2DifficultyLevel = .easy

    // Timer
    @State private var gameTimer: Timer? = nil

    // Constants
    private let birdRadius: CGFloat = 20
    private let pipeWidth: CGFloat = 60
    private let gravity: CGFloat = 0.5
    private let flapImpulse: CGFloat = -10
    private let frameRate: TimeInterval = 1.0 / 60.0
    private let pipeSpawnInterval: CGFloat = 2.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Sky gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.35),
                        Color(red: 0.15, green: 0.35, blue: 0.7),
                        Color(red: 0.35, green: 0.65, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Stars (decorative)
                FlappyV2StarsView()

                // Ground with glassmorphism
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .fill(Color(red: 0.3, green: 0.7, blue: 0.2).opacity(0.6))
                        )
                        .frame(height: 60)
                }
                .ignoresSafeArea()

                // Pipes (Canvas)
                Canvas { context, size in
                    for pipe in pipes {
                        let topPipeHeight = pipe.gapY - gapHeight / 2
                        let bottomPipeY = pipe.gapY + gapHeight / 2
                        let bottomPipeHeight = size.height - bottomPipeY

                        // Pipe gradient colors
                        let pipeColor = Color(red: 0.15, green: 0.75, blue: 0.3)
                        let pipeDark = Color(red: 0.05, green: 0.5, blue: 0.15)

                        // Top pipe body
                        let topRect = CGRect(x: pipe.x, y: 0, width: pipeWidth, height: max(0, topPipeHeight))
                        context.fill(Path(topRect), with: .color(pipeColor))
                        context.stroke(Path(topRect), with: .color(pipeDark), lineWidth: 2)

                        // Bottom pipe body
                        let bottomRect = CGRect(x: pipe.x, y: bottomPipeY, width: pipeWidth, height: max(0, bottomPipeHeight))
                        context.fill(Path(bottomRect), with: .color(pipeColor))
                        context.stroke(Path(bottomRect), with: .color(pipeDark), lineWidth: 2)

                        // Caps
                        let capW = pipeWidth + 8
                        let capH: CGFloat = 20
                        let capX = pipe.x - 4

                        let topCapRect = CGRect(x: capX, y: max(0, topPipeHeight - capH), width: capW, height: capH)
                        context.fill(Path(topCapRect), with: .color(Color(red: 0.2, green: 0.85, blue: 0.35)))

                        let bottomCapRect = CGRect(x: capX, y: bottomPipeY, width: capW, height: capH)
                        context.fill(Path(bottomCapRect), with: .color(Color(red: 0.2, green: 0.85, blue: 0.35)))
                    }
                }

                // Bird with glassmorphism overlay
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow, Color.orange],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 22
                            )
                        )
                    Circle()
                        .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                    // Eye
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                        .offset(x: 6, y: -5)
                    // Shine
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .offset(x: -4, y: -6)
                }
                .frame(width: birdRadius * 2, height: birdRadius * 2)
                .position(x: width * 0.3, y: birdY)

                // HUD
                VStack {
                    HStack(alignment: .top) {
                        // Difficulty badge (glassmorphism card)
                        HStack(spacing: 6) {
                            Image(systemName: currentDifficulty.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(currentDifficulty.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(currentDifficulty.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(currentDifficulty.color.opacity(0.4), lineWidth: 1)
                        )

                        Spacer()

                        // Score card (glassmorphism)
                        Text("\(score)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                            .scaleEffect(scorePopScale)
                            .animation(.spring(response: 0.2, dampingFraction: 0.4), value: scorePopScale)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)

                    Spacer()
                }

                // Waiting state
                if gameState == .waiting {
                    FlappyV2StartOverlay(difficulty: currentDifficulty, roundScores: roundScores)
                }

                // Game over overlay
                if gameState == .gameOver {
                    FlappyV2GameOverOverlay(
                        score: score,
                        roundScores: roundScores,
                        difficulty: currentDifficulty,
                        onRestart: { resetGame(in: geometry.size) }
                    )
                }
            }
            .onAppear {
                birdY = height / 2
            }
            .onTapGesture {
                handleTap(in: geometry.size)
            }
        }
    }

    // MARK: - Difficulty Computation

    private func computeDifficulty() {
        currentDifficulty = difficultyLevel(for: pipeSpeed, gap: gapHeight)
    }

    private func difficultyLevel(for speed: CGFloat, gap: CGFloat) -> FlappyV2DifficultyLevel {
        if speed >= 5.5 || gap <= 125 { return .extreme }
        if speed >= 4.5 || gap <= 140 { return .hard }
        if speed >= 3.5 || gap <= 155 { return .medium }
        return .easy
    }

    private func adaptDifficulty() {
        guard !roundScores.isEmpty else { return }
        let recentScores = Array(roundScores.suffix(5))
        let currentAvg = Double(recentScores.reduce(0, +)) / Double(recentScores.count)

        if currentAvg > previousAverageScore && previousAverageScore > 0 {
            // Getting better — increase difficulty
            pipeSpeed = min(6.0, pipeSpeed + 0.3)
            gapHeight = max(120, gapHeight - 5)
        } else if currentAvg < previousAverageScore && previousAverageScore > 0 {
            // Getting worse — decrease difficulty
            pipeSpeed = max(2.0, pipeSpeed - 0.3)
            gapHeight = min(200, gapHeight + 5)
        }

        previousAverageScore = currentAvg
        computeDifficulty()
    }

    // MARK: - Game Logic

    private func handleTap(in size: CGSize) {
        switch gameState {
        case .waiting:
            startGame(in: size)
        case .playing:
            birdVelocity = flapImpulse
        case .gameOver:
            break
        }
    }

    private func startGame(in size: CGSize) {
        gameState = .playing
        birdVelocity = flapImpulse
        pipes = []
        score = 0
        pipeSpawnTimer = 0
        birdY = size.height / 2

        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
            updateGame(in: size)
        }
    }

    private func resetGame(in size: CGSize) {
        gameTimer?.invalidate()
        gameTimer = nil
        gameState = .waiting
        birdY = size.height / 2
        birdVelocity = 0
        pipes = []
        pipeSpawnTimer = 0
    }

    private func updateGame(in size: CGSize) {
        guard gameState == .playing else { return }

        // Bird physics
        birdVelocity += gravity
        birdY += birdVelocity

        // Boundary collision
        let topBound: CGFloat = birdRadius
        let bottomBound: CGFloat = size.height - 60 - birdRadius

        if birdY < topBound || birdY > bottomBound {
            triggerGameOver()
            return
        }

        // Spawn pipes
        pipeSpawnTimer += CGFloat(frameRate)
        if pipeSpawnTimer >= pipeSpawnInterval {
            pipeSpawnTimer = 0
            spawnPipe(in: size)
        }

        // Update pipes
        let birdX = size.width * 0.3

        for i in pipes.indices {
            pipes[i].x -= pipeSpeed

            if !pipes[i].passed && pipes[i].x + pipeWidth < birdX {
                pipes[i].passed = true
                score += 1
                // Score pop animation
                scorePopScale = 1.4
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    scorePopScale = 1.0
                }
            }

            // Collision
            let pipeLeft = pipes[i].x
            let pipeRight = pipes[i].x + pipeWidth
            let birdLeft = birdX - birdRadius
            let birdRight = birdX + birdRadius
            let birdTop = birdY - birdRadius
            let birdBottom = birdY + birdRadius

            if birdRight > pipeLeft && birdLeft < pipeRight {
                let gapTop = pipes[i].gapY - gapHeight / 2
                let gapBottom = pipes[i].gapY + gapHeight / 2

                if birdTop < gapTop || birdBottom > gapBottom {
                    triggerGameOver()
                    return
                }
            }
        }

        pipes.removeAll { $0.x + pipeWidth < 0 }
    }

    private func spawnPipe(in size: CGSize) {
        let minGapY = gapHeight / 2 + 60
        let maxGapY = size.height - 60 - gapHeight / 2 - 20
        let gapY = CGFloat.random(in: minGapY...maxGapY)
        pipes.append(FlappyV2Pipe(x: size.width, gapY: gapY))
    }

    private func triggerGameOver() {
        gameState = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil

        // Record score and adapt
        var updated = roundScores
        updated.append(score)
        if updated.count > 5 { updated = Array(updated.suffix(5)) }
        roundScores = updated
        adaptDifficulty()
    }
}

// MARK: - Stars

struct FlappyV2StarsView: View {
    private let starPositions: [(CGFloat, CGFloat, CGFloat)] = {
        var positions: [(CGFloat, CGFloat, CGFloat)] = []
        var seed: UInt64 = 42
        for _ in 0..<40 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = CGFloat((seed >> 33) & 0xFFFF) / 65535.0
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let y = CGFloat((seed >> 33) & 0xFFFF) / 65535.0 * 0.6
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let size = CGFloat((seed >> 33) & 0x3) + 1.0
            positions.append((x, y, size))
        }
        return positions
    }()

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for (xRatio, yRatio, starSize) in starPositions {
                    let x = xRatio * size.width
                    let y = yRatio * size.height
                    let rect = CGRect(x: x - starSize / 2, y: y - starSize / 2, width: starSize, height: starSize)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Start Overlay

struct FlappyV2StartOverlay: View {
    let difficulty: FlappyV2DifficultyLevel
    let roundScores: [Int]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("FLAPPY BIRD")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 8, x: 0, y: 3)

                // Difficulty badge
                HStack(spacing: 6) {
                    Image(systemName: difficulty.icon)
                        .font(.system(size: 14, weight: .bold))
                    Text(difficulty.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(difficulty.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(difficulty.color.opacity(0.5), lineWidth: 1))

                if !roundScores.isEmpty {
                    VStack(spacing: 4) {
                        Text("Recent Scores")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 8) {
                            ForEach(roundScores.suffix(5), id: \.self) { s in
                                Text("\(s)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                Text("Tap to Start")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Game Over Overlay

struct FlappyV2GameOverOverlay: View {
    let score: Int
    let roundScores: [Int]
    let difficulty: FlappyV2DifficultyLevel
    let onRestart: () -> Void

    private var bestScore: Int { roundScores.max() ?? 0 }
    private var isNewBest: Bool { score == bestScore && roundScores.count > 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 3)

                // Score display
                VStack(spacing: 6) {
                    HStack {
                        Text("Score")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(score)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    HStack {
                        Text("Best")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        HStack(spacing: 4) {
                            if isNewBest {
                                Text("NEW!")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2), in: Capsule())
                            }
                            Text("\(bestScore)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(isNewBest ? .yellow : .white)
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 1))

                // Difficulty
                HStack(spacing: 6) {
                    Image(systemName: difficulty.icon)
                        .font(.system(size: 13, weight: .bold))
                    Text("Difficulty: \(difficulty.rawValue)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(difficulty.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(difficulty.color.opacity(0.4), lineWidth: 1))

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    FlappyViewV2()
}
