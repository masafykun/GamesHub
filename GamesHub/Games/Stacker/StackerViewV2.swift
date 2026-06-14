import SwiftUI

// MARK: - Data Models

struct StackerV2Block: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var width: CGFloat
    var colorIndex: Int
    var isPerfect: Bool = false
}

enum StackerV2GameState {
    case playing
    case gameOver
}

enum StackerV2Difficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }
}

// MARK: - StackerViewV2

struct StackerViewV2: View {

    // MARK: Constants
    private let gameWidth: CGFloat = 300
    private let blockHeight: CGFloat = 30
    private let visibleRows: Int = 12
    private let minSpeed: Double = 1.5
    private let maxSpeed: Double = 5.0
    private let speedAdjustStep: Double = 0.3
    private let speedIncreaseEvery: Int = 5
    private let baseSpeedIncrement: Double = 0.2

    private let blockColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink,
        .mint, .teal, .indigo
    ]

    // MARK: AppStorage
    @AppStorage("stackerV2HighScore") private var highScore: Int = 0

    // MARK: Adaptive difficulty state
    @State var roundScores: [Int] = []
    @State private var initialSlideSpeed: Double = 2.0

    // MARK: Game state
    @State private var stackedBlocks: [StackerV2Block] = []
    @State private var slidingBlock: StackerV2Block = StackerV2Block(x: 0, width: 300, colorIndex: 0)
    @State private var slidingDirection: CGFloat = 1.0
    @State private var score: Int = 0
    @State private var gameState: StackerV2GameState = .playing
    @State private var slideSpeed: Double = 2.0
    @State private var timer: Timer? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var perfectGlowId: UUID? = nil
    @State private var placedBlockScale: [UUID: CGFloat] = [:]

    // MARK: Computed Properties

    private var difficulty: StackerV2Difficulty {
        if initialSlideSpeed <= 2.2 {
            return .easy
        } else if initialSlideSpeed <= 3.5 {
            return .medium
        } else {
            return .hard
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(white: 0.05), Color(hue: 0.6, saturation: 0.4, brightness: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // Game area
                ZStack(alignment: .bottom) {
                    // Frosted glass background for game area
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .frame(width: gameWidth + 8)

                    ZStack(alignment: .bottom) {
                        // Stacked blocks
                        ForEach(Array(stackedBlocks.enumerated()), id: \.element.id) { index, block in
                            stackedBlockView(block: block, row: index)
                        }

                        // Sliding block
                        if gameState == .playing {
                            slidingBlockView()
                        }
                    }
                    .offset(y: scrollOffset)
                    .frame(width: gameWidth)
                    .clipped()
                }
                .frame(width: gameWidth + 8)
                .frame(maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
            }

            // Game Over Overlay
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
        HStack(alignment: .center) {
            // High score
            VStack(alignment: .leading, spacing: 2) {
                Text("BEST")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(highScore)")
                    .font(.headline)
                    .foregroundColor(.yellow)
            }

            Spacer()

            // Score (center)
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Difficulty badge
            difficultyBadge()
        }
    }

    @ViewBuilder
    private func difficultyBadge() -> some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.icon)
                .font(.caption)
            Text(difficulty.rawValue)
                .font(.caption.weight(.bold))
        }
        .foregroundColor(difficulty.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(difficulty.color.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Block Views

    @ViewBuilder
    private func stackedBlockView(block: StackerV2Block, row: Int) -> some View {
        let color = blockColor(for: block.colorIndex)
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.25))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.7), lineWidth: 1.5)
                )
                .frame(width: block.width, height: blockHeight - 2)
                // Perfect glow
                .shadow(color: block.isPerfect ? color : .clear, radius: block.isPerfect ? 12 : 0)
                .shadow(color: block.isPerfect ? color.opacity(0.5) : .clear, radius: block.isPerfect ? 20 : 0)
        }
        .scaleEffect(placedBlockScale[block.id] ?? 1.0)
        .offset(
            x: block.x - gameWidth / 2 + block.width / 2,
            y: -CGFloat(row) * blockHeight
        )
    }

    @ViewBuilder
    private func slidingBlockView() -> some View {
        let slidingRow = stackedBlocks.count
        let color = blockColor(for: slidingBlock.colorIndex)

        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.35))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.9), lineWidth: 2)
            )
            .frame(width: slidingBlock.width, height: blockHeight - 2)
            .shadow(color: color.opacity(0.4), radius: 6)
            .offset(
                x: slidingBlock.x - gameWidth / 2 + slidingBlock.width / 2,
                y: -CGFloat(slidingRow) * blockHeight
            )
    }

    // MARK: - Game Over Overlay

    @ViewBuilder
    private func gameOverOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                VStack(spacing: 6) {
                    Text("SCORE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    if score >= highScore && score > 0 {
                        Label("NEW BEST!", systemImage: "star.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.yellow)
                    } else {
                        Text("BEST: \(highScore)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Round history
                if !roundScores.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(roundScores.suffix(5).enumerated()), id: \.offset) { _, s in
                            Text("\(s)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button(action: {
                        startGame()
                    }) {
                        Label("PLAY AGAIN", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .purple.opacity(0.5), radius: 12)
                    }

                    Text("Next speed: \(String(format: "%.1f", computeNextInitialSpeed()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(32)
        }
    }

    // MARK: - Adaptive Difficulty

    private func computeNextInitialSpeed() -> Double {
        let recent = roundScores.suffix(5)
        guard recent.count >= 2 else { return initialSlideSpeed }

        let arr = Array(recent)
        let firstHalf = arr.prefix(arr.count / 2).reduce(0, +)
        let secondHalf = arr.suffix(arr.count - arr.count / 2).reduce(0, +)

        if secondHalf > firstHalf {
            // Improving - increase difficulty
            return min(initialSlideSpeed + speedAdjustStep, maxSpeed)
        } else if secondHalf < firstHalf {
            // Dropping - decrease difficulty
            return max(initialSlideSpeed - speedAdjustStep, minSpeed)
        }
        return initialSlideSpeed
    }

    // MARK: - Game Logic

    private func startGame() {
        stopTimer()

        // Adaptive speed based on round history
        if !roundScores.isEmpty {
            initialSlideSpeed = computeNextInitialSpeed()
        }

        score = 0
        slideSpeed = initialSlideSpeed
        scrollOffset = 0
        slidingDirection = 1.0
        placedBlockScale = [:]

        let base = StackerV2Block(x: 0, width: gameWidth, colorIndex: 0)
        stackedBlocks = [base]
        slidingBlock = StackerV2Block(x: 0, width: gameWidth, colorIndex: 1)
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

        let delta = CGFloat(slideSpeed) * slidingDirection
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

        let isPerfect = abs(overlap - prevWidth) < 1.0

        var newBlock = StackerV2Block(
            x: overlapStart,
            width: overlap,
            colorIndex: slidingBlock.colorIndex,
            isPerfect: isPerfect
        )

        // Spring animation on placement
        placedBlockScale[newBlock.id] = 1.15
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            placedBlockScale[newBlock.id] = 1.0
        }

        stackedBlocks.append(newBlock)
        score += 1

        if score > highScore {
            highScore = score
        }

        adjustScroll()

        // Speed increase every 5 drops
        if score % speedIncreaseEvery == 0 {
            slideSpeed = min(slideSpeed + baseSpeedIncrement, maxSpeed)
        }

        // Next sliding block
        let nextColorIndex = (newBlock.colorIndex + 1) % blockColors.count
        slidingBlock = StackerV2Block(x: 0, width: newBlock.width, colorIndex: nextColorIndex)
        slidingDirection = 1.0
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

        // Record round score
        var updated = roundScores
        updated.append(score)
        if updated.count > 5 {
            updated.removeFirst(updated.count - 5)
        }
        roundScores = updated

        withAnimation(.spring()) {
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
    StackerViewV2()
}
