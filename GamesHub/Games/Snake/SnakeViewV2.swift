import SwiftUI

// MARK: - Models

enum SnakeDifficultyLevel: String {
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
}

// MARK: - Main View

struct SnakeViewV2: View {
    @StateObject private var gameState = SnakeGameState()
    @State private var timer: Timer? = nil
    @State private var roundScores: [Int] = []
    @State private var currentInterval: Double = SnakeGameState.moveInterval
    @State private var difficultyLevel: SnakeDifficultyLevel = .easy
    @State private var isStarted: Bool = false

    private let gridSize = SnakeGameState.gridSize

    var body: some View {
        GeometryReader { geo in
            let boardSize = min(geo.size.width, geo.size.height - 80)
            let cellSize = boardSize / CGFloat(gridSize)

            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                        Color(red: 0.08, green: 0.12, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header
                    headerView

                    // Board
                    boardView(boardSize: boardSize, cellSize: cellSize)
                        .frame(width: boardSize, height: boardSize)

                    Spacer()
                }
                .padding(.top, 8)

                // Overlays
                if !isStarted {
                    startOverlay
                } else if gameState.isGameOver {
                    gameOverOverlay
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    handleSwipe(translation: value.translation)
                }
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Score badge
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(gameState.score)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(minWidth: 70)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            // Difficulty badge
            VStack(spacing: 2) {
                Text("LEVEL")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text(difficultyLevel.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(difficultyLevel.color)
            }
            .frame(minWidth: 70)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Board

    private func boardView(boardSize: CGFloat, cellSize: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Grid background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            // Grid lines
            Canvas { context, size in
                let cw = size.width / CGFloat(gridSize)
                let ch = size.height / CGFloat(gridSize)
                var path = Path()
                for i in 1..<gridSize {
                    path.move(to: CGPoint(x: CGFloat(i) * cw, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(i) * cw, y: size.height))
                    path.move(to: CGPoint(x: 0, y: CGFloat(i) * ch))
                    path.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * ch))
                }
                context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Food
            let foodX = CGFloat(gameState.food.col) * cellSize
            let foodY = CGFloat(gameState.food.row) * cellSize
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1, green: 0.4, blue: 0.3), Color(red: 0.9, green: 0.15, blue: 0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: cellSize * 0.5
                        )
                    )
                    .shadow(color: Color.red.opacity(0.7), radius: 6)
            }
            .frame(width: cellSize - 2, height: cellSize - 2)
            .offset(x: foodX + 1, y: foodY + 1)

            // Snake
            ForEach(Array(gameState.snake.enumerated()), id: \.offset) { index, cell in
                let isHead = index == 0
                let fraction = gameState.snake.count > 1 ? Double(index) / Double(gameState.snake.count - 1) : 0
                let snakeColor = snakeSegmentColor(fraction: fraction, isHead: isHead)

                RoundedRectangle(cornerRadius: isHead ? 5 : 3)
                    .fill(snakeColor)
                    .overlay(
                        isHead ? RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1) : nil
                    )
                    .shadow(color: snakeColor.opacity(0.5), radius: isHead ? 4 : 1)
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .offset(
                        x: CGFloat(cell.col) * cellSize + 1,
                        y: CGFloat(cell.row) * cellSize + 1
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func snakeSegmentColor(fraction: Double, isHead: Bool) -> Color {
        if isHead {
            return Color(red: 0.2, green: 0.95, blue: 0.5)
        }
        // Gradient from bright green to teal
        let r = 0.1 + fraction * 0.05
        let g = 0.85 - fraction * 0.35
        let b = 0.3 + fraction * 0.35
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("SNAKE")
                    .font(.system(size: 42, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .green.opacity(0.8), radius: 12)

                Text("Swipe to move")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: startGame) {
                    Text("Start Game")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.95, blue: 0.5), Color(red: 0.1, green: 0.75, blue: 0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .green.opacity(0.5), radius: 10)
                }
            }
            .padding(36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .red.opacity(0.8), radius: 10)

                VStack(spacing: 6) {
                    Text("Score: \(gameState.score)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    if !roundScores.isEmpty {
                        let avg = movingAverage(roundScores)
                        Text("Avg (last \(roundScores.count)): \(String(format: "%.1f", avg))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Difficulty badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(difficultyLevel.color)
                        .frame(width: 8, height: 8)
                    Text("Next difficulty: \(difficultyLevel.rawValue)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(difficultyLevel.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(difficultyLevel.color.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(difficultyLevel.color.opacity(0.4), lineWidth: 1))

                // Recent scores
                if !roundScores.isEmpty {
                    VStack(spacing: 4) {
                        Text("Recent Scores")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                        HStack(spacing: 8) {
                            ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                                Text("\(s)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                Button(action: restartGame) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.95, blue: 0.5), Color(red: 0.1, green: 0.75, blue: 0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .green.opacity(0.5), radius: 10)
                }
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        isStarted = true
        gameState.startGame()
    }

    private func restartGame() {
        gameState.startGame()
    }

    private func startTimer() {
        // SnakeGameState manages its own internal timer
    }

    private func stopTimer() {
        // SnakeGameState manages its own internal timer
    }

    private func handleGameOver() {
        let score = gameState.score
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        adjustDifficulty()
    }

    private func movingAverage(_ scores: [Int]) -> Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func adjustDifficulty() {
        guard roundScores.count >= 2 else {
            difficultyLevel = .easy
            currentInterval = SnakeGameState.moveInterval
            return
        }

        let avg = movingAverage(roundScores)

        // Thresholds for difficulty scaling
        if avg >= 20 {
            difficultyLevel = .hard
            currentInterval = 0.07
        } else if avg >= 10 {
            difficultyLevel = .medium
            currentInterval = 0.10
        } else {
            difficultyLevel = .easy
            currentInterval = SnakeGameState.moveInterval
        }
    }

    private func handleSwipe(translation: CGSize) {
        let dx = translation.width
        let dy = translation.height

        let newDirection: SnakeDirection
        if abs(dx) > abs(dy) {
            newDirection = dx > 0 ? .right : .left
        } else {
            newDirection = dy > 0 ? .down : .up
        }

        // Prevent reversing
        gameState.changeDirection(newDirection)
    }
}

// MARK: - Preview

#Preview {
    SnakeViewV2()
}
