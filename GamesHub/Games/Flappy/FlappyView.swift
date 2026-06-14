import SwiftUI

// MARK: - Game State

enum FlappyGameState {
    case waiting
    case playing
    case gameOver
}

// MARK: - Pipe Model

struct FlappyPipe: Identifiable {
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

// MARK: - Constants

struct FlappyConstants {
    static let birdRadius: CGFloat = 20
    static let pipeWidth: CGFloat = 60
    static let gapHeight: CGFloat = 160
    static let gravity: CGFloat = 0.5
    static let flapImpulse: CGFloat = -10
    static let pipeSpeed: CGFloat = 3
    static let pipeSpawnInterval: TimeInterval = 2.0
    static let frameRate: TimeInterval = 1.0 / 60.0
}

// MARK: - Main View

struct FlappyView: View {
    // Game state
    @State private var gameState: FlappyGameState = .waiting
    @State private var birdY: CGFloat = 0
    @State private var birdVelocity: CGFloat = 0
    @State private var pipes: [FlappyPipe] = []
    @State private var score: Int = 0
    @State private var pipeSpawnTimer: CGFloat = 0

    // Timer
    @State private var gameTimer: Timer? = nil

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Sky background
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.75, blue: 1.0), Color(red: 0.7, green: 0.9, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Ground
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.5, green: 0.8, blue: 0.3))
                        .frame(height: 60)
                }
                .ignoresSafeArea()

                // Pipes
                Canvas { context, size in
                    for pipe in pipes {
                        let topPipeHeight = pipe.gapY - FlappyConstants.gapHeight / 2
                        let bottomPipeY = pipe.gapY + FlappyConstants.gapHeight / 2
                        let bottomPipeHeight = size.height - bottomPipeY

                        // Top pipe
                        let topRect = CGRect(
                            x: pipe.x,
                            y: 0,
                            width: FlappyConstants.pipeWidth,
                            height: max(0, topPipeHeight)
                        )
                        context.fill(Path(topRect), with: .color(.green))
                        context.stroke(Path(topRect), with: .color(Color(red: 0.0, green: 0.55, blue: 0.0)), lineWidth: 2)

                        // Bottom pipe
                        let bottomRect = CGRect(
                            x: pipe.x,
                            y: bottomPipeY,
                            width: FlappyConstants.pipeWidth,
                            height: max(0, bottomPipeHeight)
                        )
                        context.fill(Path(bottomRect), with: .color(.green))
                        context.stroke(Path(bottomRect), with: .color(Color(red: 0.0, green: 0.55, blue: 0.0)), lineWidth: 2)

                        // Pipe caps (slightly wider)
                        let capWidth = FlappyConstants.pipeWidth + 8
                        let capHeight: CGFloat = 20
                        let capX = pipe.x - 4

                        let topCapRect = CGRect(
                            x: capX,
                            y: max(0, topPipeHeight - capHeight),
                            width: capWidth,
                            height: capHeight
                        )
                        context.fill(Path(topCapRect), with: .color(Color(red: 0.1, green: 0.7, blue: 0.1)))

                        let bottomCapRect = CGRect(
                            x: capX,
                            y: bottomPipeY,
                            width: capWidth,
                            height: capHeight
                        )
                        context.fill(Path(bottomCapRect), with: .color(Color(red: 0.1, green: 0.7, blue: 0.1)))
                    }
                }

                // Bird
                Circle()
                    .fill(Color.yellow)
                    .overlay(
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                    )
                    .overlay(
                        // Eye
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .offset(x: 6, y: -5)
                    )
                    .frame(width: FlappyConstants.birdRadius * 2, height: FlappyConstants.birdRadius * 2)
                    .position(x: width * 0.3, y: birdY)

                // HUD - Score
                VStack {
                    HStack {
                        Spacer()
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                        Spacer()
                    }
                    .padding(.top, 60)
                    Spacer()
                }

                // Waiting state overlay
                if gameState == .waiting {
                    FlappyStartOverlay()
                }

                // Game over overlay
                if gameState == .gameOver {
                    FlappyGameOverOverlay(score: score) {
                        resetGame(in: geometry.size)
                    }
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

    // MARK: - Game Logic

    private func handleTap(in size: CGSize) {
        switch gameState {
        case .waiting:
            startGame(in: size)
        case .playing:
            birdVelocity = FlappyConstants.flapImpulse
        case .gameOver:
            break
        }
    }

    private func startGame(in size: CGSize) {
        gameState = .playing
        birdVelocity = FlappyConstants.flapImpulse
        pipes = []
        score = 0
        pipeSpawnTimer = 0
        birdY = size.height / 2

        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: FlappyConstants.frameRate, repeats: true) { _ in
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
        score = 0
        pipeSpawnTimer = 0
    }

    private func updateGame(in size: CGSize) {
        guard gameState == .playing else { return }

        // Update bird physics
        birdVelocity += FlappyConstants.gravity
        birdY += birdVelocity

        // Check top/bottom collision
        let topBound: CGFloat = FlappyConstants.birdRadius
        let bottomBound: CGFloat = size.height - 60 - FlappyConstants.birdRadius

        if birdY < topBound || birdY > bottomBound {
            triggerGameOver()
            return
        }

        // Spawn pipes
        pipeSpawnTimer += CGFloat(FlappyConstants.frameRate)
        if pipeSpawnTimer >= CGFloat(FlappyConstants.pipeSpawnInterval) {
            pipeSpawnTimer = 0
            spawnPipe(in: size)
        }

        // Update pipes
        let birdX = size.width * 0.3

        for i in pipes.indices {
            pipes[i].x -= FlappyConstants.pipeSpeed

            // Score: pipe passed
            if !pipes[i].passed && pipes[i].x + FlappyConstants.pipeWidth < birdX {
                pipes[i].passed = true
                score += 1
            }

            // Collision detection
            let pipeLeft = pipes[i].x
            let pipeRight = pipes[i].x + FlappyConstants.pipeWidth
            let birdLeft = birdX - FlappyConstants.birdRadius
            let birdRight = birdX + FlappyConstants.birdRadius
            let birdTop = birdY - FlappyConstants.birdRadius
            let birdBottom = birdY + FlappyConstants.birdRadius

            if birdRight > pipeLeft && birdLeft < pipeRight {
                let gapTop = pipes[i].gapY - FlappyConstants.gapHeight / 2
                let gapBottom = pipes[i].gapY + FlappyConstants.gapHeight / 2

                if birdTop < gapTop || birdBottom > gapBottom {
                    triggerGameOver()
                    return
                }
            }
        }

        // Remove off-screen pipes
        pipes.removeAll { $0.x + FlappyConstants.pipeWidth < 0 }
    }

    private func spawnPipe(in size: CGSize) {
        let minGapY: CGFloat = FlappyConstants.gapHeight / 2 + 60
        let maxGapY: CGFloat = size.height - 60 - FlappyConstants.gapHeight / 2 - 20
        let gapY = CGFloat.random(in: minGapY...maxGapY)
        let pipe = FlappyPipe(x: size.width, gapY: gapY)
        pipes.append(pipe)
    }

    private func triggerGameOver() {
        gameState = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil
    }
}

// MARK: - Subviews

struct FlappyStartOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
                .frame(width: 280, height: 180)

            VStack(spacing: 16) {
                Text("FLAPPY BIRD")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange, radius: 4, x: 0, y: 2)

                Text("Tap to Start")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

struct FlappyGameOverOverlay: View {
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 1)

                Text("Score: \(score)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Button(action: onRestart) {
                    Text("Restart")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95))
            )
        }
    }
}

#Preview {
    FlappyView()
}
