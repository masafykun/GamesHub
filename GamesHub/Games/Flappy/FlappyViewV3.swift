import SwiftUI

// MARK: - Seed Generator

struct FlappyV3SeedGenerator {
    var seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let raw = next()
        let normalized = CGFloat((raw >> 11) & 0x1FFFFF) / CGFloat(0x1FFFFF)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }

    // Generate a 4-char alphanumeric code from a seed value
    static func seedCode(from value: UInt64) -> String {
        let chars: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var v = value
        var code: [Character] = []
        for _ in 0..<4 {
            code.append(chars[Int(v % UInt64(chars.count))])
            v = v &* 6364136223846793005 &+ 1442695040888963407
        }
        return String(code)
    }

    static func initialSeed() -> UInt64 {
        return UInt64.random(in: 1...UInt64.max)
    }
}

// MARK: - Game State

enum FlappyV3GameState {
    case waiting
    case playing
    case gameOver
}

// MARK: - Pipe Model

struct FlappyV3Pipe: Identifiable {
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

struct FlappyViewV3: View {
    // Game state
    @State private var gameState: FlappyV3GameState = .waiting
    @State private var birdY: CGFloat = 0
    @State private var birdVelocity: CGFloat = 0
    @State private var pipes: [FlappyV3Pipe] = []
    @State private var score: Int = 0
    @State private var pipeSpawnTimer: CGFloat = 0

    // Seed
    @State private var currentSeedValue: UInt64 = 0
    @State private var currentSeedCode: String = "????"
    @State private var seedGenerator: FlappyV3SeedGenerator = FlappyV3SeedGenerator(seed: 1)

    // Timer
    @State private var gameTimer: Timer? = nil

    // Constants
    private let birdRadius: CGFloat = 20
    private let pipeWidth: CGFloat = 60
    private let gapHeight: CGFloat = 160
    private let gravity: CGFloat = 0.5
    private let flapImpulse: CGFloat = -10
    private let pipeSpeed: CGFloat = 3
    private let frameRate: TimeInterval = 1.0 / 60.0
    private let pipeSpawnInterval: CGFloat = 2.0

    // Neumorphic colors
    private let bgColor = Color(.systemGray6)
    private let pipeColor = Color(red: 0.45, green: 0.72, blue: 0.45)
    private let pipeDark = Color(red: 0.3, green: 0.55, blue: 0.3)
    private let pipeLight = Color(red: 0.6, green: 0.85, blue: 0.6)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Neumorphic background
                bgColor
                    .ignoresSafeArea()

                // Subtle texture grid lines
                Canvas { context, size in
                    let spacing: CGFloat = 40
                    var x: CGFloat = 0
                    while x <= size.width {
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        context.stroke(path, with: .color(Color(.systemGray5).opacity(0.5)), lineWidth: 0.5)
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(path, with: .color(Color(.systemGray5).opacity(0.5)), lineWidth: 0.5)
                        y += spacing
                    }
                }
                .ignoresSafeArea()

                // Ground
                VStack {
                    Spacer()
                    ZStack {
                        Rectangle()
                            .fill(bgColor)
                            .frame(height: 64)
                            .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                            .shadow(color: Color(.systemGray4), radius: 4, x: 2, y: 2)
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                            .offset(y: -31)
                    }
                }
                .ignoresSafeArea()

                // Pipes (Canvas)
                Canvas { context, size in
                    for pipe in pipes {
                        let topH = pipe.gapY - gapHeight / 2
                        let bottomY = pipe.gapY + gapHeight / 2
                        let bottomH = size.height - bottomY

                        // Top pipe shadow
                        let topShadowRect = CGRect(x: pipe.x + 4, y: 4, width: pipeWidth, height: max(0, topH))
                        context.fill(Path(topShadowRect), with: .color(Color(.systemGray4).opacity(0.6)))

                        // Top pipe body
                        let topRect = CGRect(x: pipe.x, y: 0, width: pipeWidth, height: max(0, topH))
                        context.fill(Path(topRect), with: .color(pipeColor))

                        // Top pipe highlight
                        let topHighlight = CGRect(x: pipe.x + 4, y: 0, width: 8, height: max(0, topH))
                        context.fill(Path(topHighlight), with: .color(pipeLight.opacity(0.5)))

                        // Bottom pipe shadow
                        let bottomShadowRect = CGRect(x: pipe.x + 4, y: bottomY + 4, width: pipeWidth, height: max(0, bottomH))
                        context.fill(Path(bottomShadowRect), with: .color(Color(.systemGray4).opacity(0.6)))

                        // Bottom pipe body
                        let bottomRect = CGRect(x: pipe.x, y: bottomY, width: pipeWidth, height: max(0, bottomH))
                        context.fill(Path(bottomRect), with: .color(pipeColor))

                        // Bottom pipe highlight
                        let bottomHighlight = CGRect(x: pipe.x + 4, y: bottomY, width: 8, height: max(0, bottomH))
                        context.fill(Path(bottomHighlight), with: .color(pipeLight.opacity(0.5)))

                        // Caps
                        let capW = pipeWidth + 10
                        let capH: CGFloat = 22
                        let capX = pipe.x - 5

                        // Top cap shadow
                        let topCapShadow = CGRect(x: capX + 4, y: max(0, topH - capH) + 4, width: capW, height: capH)
                        context.fill(Path(topCapShadow), with: .color(Color(.systemGray4).opacity(0.5)))

                        let topCapRect = CGRect(x: capX, y: max(0, topH - capH), width: capW, height: capH)
                        context.fill(Path(topCapRect), with: .color(pipeColor))
                        context.stroke(Path(topCapRect), with: .color(pipeDark.opacity(0.4)), lineWidth: 1)

                        // Bottom cap shadow
                        let bottomCapShadow = CGRect(x: capX + 4, y: bottomY + 4, width: capW, height: capH)
                        context.fill(Path(bottomCapShadow), with: .color(Color(.systemGray4).opacity(0.5)))

                        let bottomCapRect = CGRect(x: capX, y: bottomY, width: capW, height: capH)
                        context.fill(Path(bottomCapRect), with: .color(pipeColor))
                        context.stroke(Path(bottomCapRect), with: .color(pipeDark.opacity(0.4)), lineWidth: 1)
                    }
                }

                // Bird (neumorphic circle)
                ZStack {
                    // Outer neumorphic shadow
                    Circle()
                        .fill(bgColor)
                        .shadow(color: .white.opacity(0.8), radius: 6, x: -4, y: -4)
                        .shadow(color: Color(.systemGray4), radius: 6, x: 4, y: 4)

                    // Bird fill
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.85, blue: 0.3),
                                    Color(red: 0.8, green: 0.6, blue: 0.15)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 20
                            )
                        )
                        .padding(3)

                    // Eye
                    Circle()
                        .fill(Color(.label).opacity(0.8))
                        .frame(width: 7, height: 7)
                        .offset(x: 6, y: -4)

                    // Shine
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 9, height: 9)
                        .offset(x: -4, y: -5)
                }
                .frame(width: birdRadius * 2, height: birdRadius * 2)
                .position(x: width * 0.3, y: birdY)

                // HUD
                VStack {
                    HStack(alignment: .top) {
                        // Seed display (neumorphic card)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SEED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(.secondaryLabel))
                            Text(currentSeedCode)
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(Color(.label))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .neumorphicCard(radius: 14)

                        Spacer()

                        // Score (neumorphic card)
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(Color(.label))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .neumorphicCard(radius: 14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)

                    Spacer()
                }

                // Waiting overlay
                if gameState == .waiting {
                    FlappyV3StartOverlay(seedCode: currentSeedCode) {
                        startGame(in: geometry.size)
                    }
                }

                // Game over overlay
                if gameState == .gameOver {
                    FlappyV3GameOverOverlay(
                        score: score,
                        seedCode: currentSeedCode,
                        onRestart: { resetGame(in: geometry.size) }
                    )
                }
            }
            .onAppear {
                birdY = height / 2
                generateNewSeed()
            }
        }
    }

    // MARK: - Seed

    private func generateNewSeed() {
        let seedVal = FlappyV3SeedGenerator.initialSeed()
        currentSeedValue = seedVal
        currentSeedCode = FlappyV3SeedGenerator.seedCode(from: seedVal)
        seedGenerator = FlappyV3SeedGenerator(seed: seedVal)
    }

    // MARK: - Game Logic

    private func startGame(in size: CGSize) {
        gameState = .playing
        birdVelocity = flapImpulse
        pipes = []
        score = 0
        pipeSpawnTimer = 0
        birdY = size.height / 2
        // Reset seed generator so pipes are deterministic for this seed
        seedGenerator = FlappyV3SeedGenerator(seed: currentSeedValue)

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
        score = 0
        pipeSpawnTimer = 0
        // Generate a fresh seed for the next round
        generateNewSeed()
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
        var gen = seedGenerator
        let gapY = gen.nextCGFloat(in: minGapY...maxGapY)
        seedGenerator = gen
        pipes.append(FlappyV3Pipe(x: size.width, gapY: gapY))
    }

    private func triggerGameOver() {
        gameState = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil
    }
}

// MARK: - Start Overlay

struct FlappyV3StartOverlay: View {
    let seedCode: String
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                VStack(spacing: 4) {
                    Text("FLAPPY BIRD")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))

                    Text("V3 — PROCEDURAL")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(.secondaryLabel))
                        .tracking(2)
                }

                // Seed card
                VStack(spacing: 6) {
                    Text("SEED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                        .tracking(3)
                    Text(seedCode)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(Color(.label))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .neumorphicCard(radius: 18)

                Text("Same seed = same pipes")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(.secondaryLabel))

                // Start button
                Button(action: onStart) {
                    Text("TAP TO START")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .tracking(1)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .neumorphicCard(radius: 28)
            .padding(.horizontal, 36)
        }
    }
}

// MARK: - Game Over Overlay

struct FlappyV3GameOverOverlay: View {
    let score: Int
    let seedCode: String
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))

                // Score
                VStack(spacing: 4) {
                    Text("SCORE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                        .tracking(3)
                    Text("\(score)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .neumorphicCard(radius: 18)

                // Seed display
                VStack(spacing: 4) {
                    Text("SEED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                        .tracking(3)
                    Text(seedCode)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .neumorphicCard(radius: 14)

                Text("New game = new seed")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(.tertiaryLabel))

                // Restart button
                Button(action: onRestart) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .tracking(1)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(30)
            .neumorphicCard(radius: 28)
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    FlappyViewV3()
}
