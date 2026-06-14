import SwiftUI

// MARK: - Data Models

struct StackerBlock: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var width: CGFloat
    var colorIndex: Int
}

enum StackerGameState {
    case playing
    case gameOver
}

// MARK: - StackerView

struct StackerView: View {

    // MARK: Constants
    private let gameWidth: CGFloat = 300
    private let blockHeight: CGFloat = 30
    private let visibleRows: Int = 12
    private let startSpeed: Double = 2.0
    private let maxSpeed: Double = 6.0
    private let speedStep: Double = 0.2
    private let speedIncreaseEvery: Int = 5

    private let blockColors: [Color] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink,
        .mint, .teal, .indigo, .brown
    ]

    // MARK: AppStorage
    @AppStorage("stackerHighScore") private var highScore: Int = 0

    // MARK: State
    @State private var stackedBlocks: [StackerBlock] = []
    @State private var slidingBlock: StackerBlock = StackerBlock(x: 0, width: 300, colorIndex: 0)
    @State private var slidingDirection: CGFloat = 1.0
    @State private var score: Int = 0
    @State private var gameState: StackerGameState = .playing
    @State private var slideSpeed: Double = 2.0
    @State private var timer: Timer? = nil
    @State private var scrollOffset: CGFloat = 0

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BEST")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(highScore)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("SCORE")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(score)")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SPEED")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", slideSpeed))
                            .font(.headline)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                // Game Area
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(white: 0.08))
                        .frame(width: gameWidth)
                        .clipped()

                    // Stacked blocks + sliding block, translated by scrollOffset
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
                }
                .frame(width: gameWidth)
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

    // MARK: - Block Views

    @ViewBuilder
    private func stackedBlockView(block: StackerBlock, row: Int) -> some View {
        Rectangle()
            .fill(blockColor(for: block.colorIndex))
            .frame(width: block.width, height: blockHeight)
            .offset(x: block.x - gameWidth / 2 + block.width / 2,
                    y: -CGFloat(row) * blockHeight)
    }

    @ViewBuilder
    private func slidingBlockView() -> some View {
        let slidingRow = stackedBlocks.count
        Rectangle()
            .fill(blockColor(for: slidingBlock.colorIndex))
            .frame(width: slidingBlock.width, height: blockHeight)
            .offset(x: slidingBlock.x - gameWidth / 2 + slidingBlock.width / 2,
                    y: -CGFloat(slidingRow) * blockHeight)
    }

    // MARK: - Overlays

    @ViewBuilder
    private func gameOverOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(score)")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundColor(.yellow)

                    if score >= highScore && score > 0 {
                        Text("NEW BEST!")
                            .font(.headline)
                            .foregroundColor(.orange)
                    } else {
                        Text("BEST: \(highScore)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                Button(action: {
                    startGame()
                }) {
                    Text("PLAY AGAIN")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(12)
                }
            }
            .padding(40)
            .background(Color(white: 0.12))
            .cornerRadius(24)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        stopTimer()
        score = 0
        slideSpeed = startSpeed
        scrollOffset = 0
        slidingDirection = 1.0

        // Base block: full width at bottom
        let base = StackerBlock(x: 0, width: gameWidth, colorIndex: 0)
        stackedBlocks = [base]

        // First sliding block
        slidingBlock = StackerBlock(x: 0, width: gameWidth, colorIndex: 1)
        slidingDirection = 1.0
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

        let step = CGFloat(slideSpeed) / 60.0 * 60.0 * (1.0 / 60.0)
        // step per frame = slideSpeed pt/frame (since timer fires 60/s, slideSpeed is in pt/frame)
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

        // Overlap calculation
        let overlapStart = max(currX, prevX)
        let overlapEnd = min(currX + currWidth, prevX + prevWidth)
        let overlap = overlapEnd - overlapStart

        if overlap <= 0 {
            // Missed - game over
            endGame()
            return
        }

        // Successful drop
        let newBlock = StackerBlock(
            x: overlapStart,
            width: overlap,
            colorIndex: slidingBlock.colorIndex
        )
        stackedBlocks.append(newBlock)
        score += 1

        if score > highScore {
            highScore = score
        }

        // Adjust scroll so stack stays in view
        adjustScroll()

        // Increase speed every 5 successful drops
        if score % speedIncreaseEvery == 0 {
            slideSpeed = min(slideSpeed + speedStep, maxSpeed)
        }

        // Prepare next sliding block
        let nextColorIndex = (newBlock.colorIndex + 1) % blockColors.count
        slidingBlock = StackerBlock(x: 0, width: newBlock.width, colorIndex: nextColorIndex)
        slidingDirection = 1.0
    }

    private func adjustScroll() {
        // Keep the top of the stack visible; scroll up as blocks accumulate
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
        withAnimation {
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
    StackerView()
}
