import SwiftUI

// MARK: - LCG Pseudo-random Number Generator

struct StackerV3LCG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }

    mutating func next() -> UInt64 {
        // LCG parameters from Knuth
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// Returns a Double in [0, 1)
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Returns an Int in [0, n)
    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Direction Sequence Generator

struct StackerV3DirectionSequence {
    private var lcg: StackerV3LCG

    init(seed: Int) {
        lcg = StackerV3LCG(seed: seed)
    }

    /// Returns 1.0 (right) or -1.0 (left) for the initial direction of each block
    mutating func nextDirection() -> CGFloat {
        lcg.nextInt(2) == 0 ? 1.0 : -1.0
    }

    /// Returns a speed variation multiplier in [0.85, 1.15]
    mutating func nextSpeedMultiplier() -> Double {
        0.85 + lcg.nextDouble() * 0.30
    }
}

// MARK: - Data Models

struct StackerV3Block: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var width: CGFloat
    var colorIndex: Int
}

enum StackerV3GameState {
    case playing
    case gameOver
}

// MARK: - StackerViewV3

struct StackerViewV3: View {

    // MARK: Constants
    private let gameWidth: CGFloat = 300
    private let blockHeight: CGFloat = 30
    private let visibleRows: Int = 12
    private let baseSpeed: Double = 2.0
    private let maxSpeed: Double = 6.0
    private let speedIncreaseEvery: Int = 5
    private let speedStep: Double = 0.2

    // Muted neumorphic-friendly block colors
    private let blockColors: [Color] = [
        Color(hue: 0.02,  saturation: 0.55, brightness: 0.75),  // Muted red
        Color(hue: 0.08,  saturation: 0.55, brightness: 0.80),  // Muted orange
        Color(hue: 0.15,  saturation: 0.45, brightness: 0.82),  // Muted yellow
        Color(hue: 0.35,  saturation: 0.40, brightness: 0.72),  // Muted green
        Color(hue: 0.53,  saturation: 0.45, brightness: 0.72),  // Muted cyan
        Color(hue: 0.60,  saturation: 0.50, brightness: 0.70),  // Muted blue
        Color(hue: 0.75,  saturation: 0.40, brightness: 0.72),  // Muted purple
        Color(hue: 0.90,  saturation: 0.40, brightness: 0.78),  // Muted pink
        Color(hue: 0.47,  saturation: 0.38, brightness: 0.73),  // Muted teal
        Color(hue: 0.68,  saturation: 0.42, brightness: 0.70),  // Muted indigo
    ]

    // MARK: AppStorage
    @AppStorage("stackerV3HighScore") private var highScore: Int = 0

    // MARK: Seed State
    @State var seedInt: Int = 1
    @State private var directionSequence: StackerV3DirectionSequence = StackerV3DirectionSequence(seed: 1)

    // MARK: Game State
    @State private var stackedBlocks: [StackerV3Block] = []
    @State private var slidingBlock: StackerV3Block = StackerV3Block(x: 0, width: 300, colorIndex: 0)
    @State private var slidingDirection: CGFloat = 1.0
    @State private var currentSpeedMultiplier: Double = 1.0
    @State private var score: Int = 0
    @State private var gameState: StackerV3GameState = .playing
    @State private var slideSpeed: Double = 2.0
    @State private var timer: Timer? = nil
    @State private var scrollOffset: CGFloat = 0

    // MARK: Body

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Seed display
                seedBadge()
                    .padding(.bottom, 8)

                // Game area with neumorphic container
                gameAreaView()
                    .frame(maxHeight: .infinity)
            }

            // Game Over
            if gameState == .gameOver {
                gameOverOverlay()
            }
        }
        .onAppear {
            startGame()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerView() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("BEST")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(highScore)")
                    .font(.headline)
                    .foregroundColor(Color(hue: 0.6, saturation: 0.5, brightness: 0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .neumorphicCard(radius: 12)

            Spacer()

            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(.label))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .neumorphicCard(radius: 14)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SPD")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", slideSpeed * currentSpeedMultiplier))
                    .font(.headline)
                    .foregroundColor(Color(.label))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .neumorphicCard(radius: 12)
        }
    }

    @ViewBuilder
    private func seedBadge() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "dice.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(.callout, design: .monospaced).weight(.bold))
                .foregroundColor(Color(.label))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .neumorphicCard(radius: 10)
    }

    // MARK: - Game Area

    @ViewBuilder
    private func gameAreaView() -> some View {
        ZStack(alignment: .bottom) {
            // Neumorphic game area background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.9), radius: 10, x: -6, y: -6)
                .shadow(color: Color.black.opacity(0.16), radius: 10, x: 6, y: 6)
                .frame(width: gameWidth + 20)

            // Block rendering
            ZStack(alignment: .bottom) {
                ForEach(Array(stackedBlocks.enumerated()), id: \.element.id) { index, block in
                    stackedBlockView(block: block, row: index)
                }

                if gameState == .playing {
                    slidingBlockView()
                }
            }
            .offset(y: scrollOffset)
            .frame(width: gameWidth)
            .clipped()
            .padding(10)
        }
        .frame(width: gameWidth + 20)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Block Views

    @ViewBuilder
    private func stackedBlockView(block: StackerV3Block, row: Int) -> some View {
        let color = blockColor(for: block.colorIndex)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.9), radius: 4, x: -3, y: -3)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 3, y: 3)

            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.30))

            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.45), lineWidth: 1)
        }
        .frame(width: block.width, height: blockHeight - 4)
        .offset(
            x: block.x - gameWidth / 2 + block.width / 2,
            y: -CGFloat(row) * blockHeight
        )
    }

    @ViewBuilder
    private func slidingBlockView() -> some View {
        let slidingRow = stackedBlocks.count
        let color = blockColor(for: slidingBlock.colorIndex)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.9), radius: 4, x: -3, y: -3)
                .shadow(color: Color.black.opacity(0.22), radius: 4, x: 3, y: 3)

            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.45))

            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.7), lineWidth: 1.5)
        }
        .frame(width: slidingBlock.width, height: blockHeight - 4)
        .offset(
            x: slidingBlock.x - gameWidth / 2 + slidingBlock.width / 2,
            y: -CGFloat(slidingRow) * blockHeight
        )
    }

    // MARK: - Game Over Overlay

    @ViewBuilder
    private func gameOverOverlay() -> some View {
        ZStack {
            Color(.systemGray6).opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color(.label))

                // Score card
                VStack(spacing: 8) {
                    Text("FINAL SCORE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 68, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(.label))

                    if score >= highScore && score > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("NEW BEST!")
                                .font(.subheadline.bold())
                                .foregroundColor(Color(.label))
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    } else {
                        Text("BEST: \(highScore)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 40)
                .neumorphicCard(radius: 20)

                // Seed info
                VStack(spacing: 4) {
                    Text("PLAYED WITH")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "dice.fill")
                            .foregroundColor(.secondary)
                        Text("SEED: #\(seedInt)")
                            .font(.system(.callout, design: .monospaced).weight(.bold))
                            .foregroundColor(Color(.label))
                    }
                }

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        seedInt += 1
                        startGame()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("NEW SEED")
                        }
                        .font(.headline)
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        startGame()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("RETRY SEED #\(seedInt)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(36)
            .neumorphicCard(radius: 28)
            .padding(24)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        stopTimer()
        score = 0
        slideSpeed = baseSpeed
        scrollOffset = 0

        // Re-initialize direction sequence from seed
        directionSequence = StackerV3DirectionSequence(seed: seedInt)

        // Base block
        let base = StackerV3Block(x: 0, width: gameWidth, colorIndex: 0)
        stackedBlocks = [base]

        // First sliding block setup
        let firstDir = directionSequence.nextDirection()
        let firstMult = directionSequence.nextSpeedMultiplier()
        slidingDirection = firstDir
        currentSpeedMultiplier = firstMult

        slidingBlock = StackerV3Block(
            x: firstDir > 0 ? 0 : gameWidth - gameWidth,
            width: gameWidth,
            colorIndex: 1
        )
        gameState = .playing

        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateSlider()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateSlider() {
        guard gameState == .playing else { return }

        let effectiveSpeed = slideSpeed * currentSpeedMultiplier
        let delta = CGFloat(effectiveSpeed) * slidingDirection
        var newX = slidingBlock.x + delta
        let maxX = gameWidth - slidingBlock.width

        if newX <= 0 {
            newX = 0
            slidingDirection = 1.0
        } else if newX >= maxX {
            newX = maxX
            slidingDirection = -1.0
        }

        slidingBlock.x = newX
    }

    private func handleTap() {
        guard gameState == .playing else { return }

        let prev = stackedBlocks.last!
        let currX = slidingBlock.x
        let currWidth = slidingBlock.width
        let prevX = prev.x
        let prevWidth = prev.width

        let overlapStart = max(currX, prevX)
        let overlapEnd = min(currX + currWidth, prevX + prevWidth)
        let overlap = overlapEnd - overlapStart

        if overlap <= 0 {
            endGame()
            return
        }

        let newBlock = StackerV3Block(
            x: overlapStart,
            width: overlap,
            colorIndex: slidingBlock.colorIndex
        )
        stackedBlocks.append(newBlock)
        score += 1

        if score > highScore {
            highScore = score
        }

        adjustScroll()

        // Speed increase every 5 drops
        if score % speedIncreaseEvery == 0 {
            slideSpeed = min(slideSpeed + speedStep, maxSpeed)
        }

        // Next block: seeded direction and speed variation
        let nextDir = directionSequence.nextDirection()
        let nextMult = directionSequence.nextSpeedMultiplier()
        slidingDirection = nextDir
        currentSpeedMultiplier = nextMult

        let nextColorIndex = (newBlock.colorIndex + 1) % blockColors.count
        let startX: CGFloat = nextDir > 0 ? 0 : gameWidth - newBlock.width
        slidingBlock = StackerV3Block(x: startX, width: newBlock.width, colorIndex: nextColorIndex)
    }

    private func adjustScroll() {
        let totalRows = stackedBlocks.count
        let rowsAboveVisible = max(0, totalRows - visibleRows + 2)
        withAnimation(.easeOut(duration: 0.2)) {
            scrollOffset = CGFloat(rowsAboveVisible) * blockHeight
        }
    }

    private func endGame() {
        stopTimer()
        if score > highScore {
            highScore = score
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            gameState = .gameOver
        }
    }

    // MARK: - Helpers

    private func blockColor(for index: Int) -> Color {
        blockColors[index % blockColors.count]
    }
}

// MARK: - Preview

#Preview {
    StackerViewV3()
}
