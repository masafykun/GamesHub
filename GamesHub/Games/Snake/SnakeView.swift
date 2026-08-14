import SwiftUI

// MARK: - Models

enum SnakeDirection {
    case up, down, left, right

    var opposite: SnakeDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }
}

struct SnakeCell: Equatable, Hashable {
    var col: Int
    var row: Int
}

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

    /// Seconds between moves at the start of a round.
    var baseInterval: TimeInterval {
        switch self {
        case .easy: return 0.16
        case .medium: return 0.12
        case .hard: return 0.09
        }
    }
}

// MARK: - Game State

final class SnakeGameState: ObservableObject {
    static let gridSize = 20

    @Published var snake: [SnakeCell] = []
    @Published var food: SnakeCell = SnakeCell(col: 0, row: 0)
    @Published var direction: SnakeDirection = .right
    @Published var isGameOver: Bool = false
    @Published var score: Int = 0

    /// Starting pace for the round; the snake keeps speeding up as it eats.
    private var baseInterval: TimeInterval = SnakeDifficultyLevel.easy.baseInterval
    private var pendingDirection: SnakeDirection = .right
    private var moveTimer: Timer?
    private var moveAccumulator: TimeInterval = 0
    private var lastMoveTime: Date = Date()

    /// Every food eaten shaves a little off the interval, down to a floor.
    private var currentInterval: TimeInterval {
        max(0.055, baseInterval - Double(score) * 0.0035)
    }

    init() {
        layoutBoard()
    }

    /// Places the snake and food without running the clock, so the
    /// start screen shows a still board instead of a game already in progress.
    private func layoutBoard() {
        let mid = SnakeGameState.gridSize / 2
        snake = [
            SnakeCell(col: mid, row: mid),
            SnakeCell(col: mid - 1, row: mid),
            SnakeCell(col: mid - 2, row: mid)
        ]
        direction = .right
        pendingDirection = .right
        isGameOver = false
        score = 0
        spawnFood()
    }

    func startGame(baseInterval: TimeInterval) {
        self.baseInterval = baseInterval
        layoutBoard()
        startTimer()
    }

    func stop() {
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func startTimer() {
        moveTimer?.invalidate()
        moveAccumulator = 0
        lastMoveTime = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        moveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func timerTick() {
        guard !isGameOver else { return }
        let now = Date()
        let delta = min(now.timeIntervalSince(lastMoveTime), 0.25)
        lastMoveTime = now
        moveAccumulator += delta
        while moveAccumulator >= currentInterval && !isGameOver {
            moveAccumulator -= currentInterval
            moveSnake()
        }
    }

    func changeDirection(_ newDirection: SnakeDirection) {
        guard !isGameOver else { return }
        guard newDirection != direction.opposite else { return }
        pendingDirection = newDirection
    }

    private func moveSnake() {
        direction = pendingDirection

        guard let head = snake.first else { return }
        let newHead = SnakeCell(col: head.col + direction.dx, row: head.row + direction.dy)

        let g = SnakeGameState.gridSize
        if newHead.col < 0 || newHead.col >= g || newHead.row < 0 || newHead.row >= g {
            triggerGameOver()
            return
        }

        // The tail tip moves away on this same step, so it is not a collision.
        if snake.dropLast().contains(newHead) {
            triggerGameOver()
            return
        }

        var newSnake = snake
        newSnake.insert(newHead, at: 0)

        if newHead == food {
            score += 1
            snake = newSnake
            spawnFood()
        } else {
            newSnake.removeLast()
            snake = newSnake
        }
    }

    private func triggerGameOver() {
        isGameOver = true
        stop()
    }

    private func spawnFood() {
        let g = SnakeGameState.gridSize
        let occupied = Set(snake)
        var empty: [SnakeCell] = []
        for col in 0..<g {
            for row in 0..<g {
                let cell = SnakeCell(col: col, row: row)
                if !occupied.contains(cell) { empty.append(cell) }
            }
        }
        if let chosen = empty.randomElement() {
            food = chosen
        }
    }

    deinit {
        moveTimer?.invalidate()
    }
}

// MARK: - Main View

struct SnakeView: View {
    @StateObject private var gameState = SnakeGameState()
    @AppStorage("snakeBestScore") private var bestScore: Int = 0
    @State private var roundScores: [Int] = []
    @State private var difficultyLevel: SnakeDifficultyLevel = .easy
    @State private var isStarted: Bool = false

    private let gridSize = SnakeGameState.gridSize

    var body: some View {
        GeometryReader { geo in
            let boardSize = min(geo.size.width - 24, geo.size.height - 140)
            let cellSize = boardSize / CGFloat(gridSize)

            ZStack {
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
                    headerView
                    boardView(cellSize: cellSize)
                        .frame(width: boardSize, height: boardSize)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

                if !isStarted {
                    startOverlay
                } else if gameState.isGameOver {
                    gameOverOverlay
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in handleSwipe(translation: value.translation) }
        )
        .onChange(of: gameState.isGameOver) { _, over in
            if over && isStarted { handleGameOver() }
        }
        .onDisappear { gameState.stop() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            statBadge(title: "SCORE", value: "\(gameState.score)", color: .white)
            Spacer()
            statBadge(title: "BEST", value: "\(bestScore)", color: Color(red: 0.4, green: 0.9, blue: 1))
            Spacer()
            VStack(spacing: 2) {
                Text("LEVEL")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text(difficultyLevel.rawValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(difficultyLevel.color)
            }
            .frame(minWidth: 68)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(minWidth: 68)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Board

    private func boardView(cellSize: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

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

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.45, blue: 0.35), Color(red: 0.9, green: 0.15, blue: 0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: cellSize * 0.5
                    )
                )
                .shadow(color: Color.red.opacity(0.7), radius: 6)
                .frame(width: cellSize - 2, height: cellSize - 2)
                .offset(
                    x: CGFloat(gameState.food.col) * cellSize + 1,
                    y: CGFloat(gameState.food.row) * cellSize + 1
                )

            ForEach(Array(gameState.snake.enumerated()), id: \.offset) { index, cell in
                let isHead = index == 0
                let fraction = gameState.snake.count > 1
                    ? Double(index) / Double(gameState.snake.count - 1)
                    : 0
                let color = segmentColor(fraction: fraction, isHead: isHead)

                RoundedRectangle(cornerRadius: isHead ? 5 : 3)
                    .fill(color)
                    .overlay(
                        isHead
                            ? RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                            : nil
                    )
                    .shadow(color: color.opacity(0.5), radius: isHead ? 4 : 1)
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .offset(
                        x: CGFloat(cell.col) * cellSize + 1,
                        y: CGFloat(cell.row) * cellSize + 1
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func segmentColor(fraction: Double, isHead: Bool) -> Color {
        if isHead { return Color(red: 0.2, green: 0.95, blue: 0.5) }
        let r = 0.1 + fraction * 0.05
        let g = 0.85 - fraction * 0.35
        let b = 0.3 + fraction * 0.35
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Overlays

    private var startOverlay: some View {
        overlayCard {
            VStack(spacing: 20) {
                Text("SNAKE")
                    .font(.system(size: 42, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .green.opacity(0.8), radius: 12)

                Text("Swipe to steer · the snake speeds up as it eats")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                primaryButton(title: "Start Game", action: startGame)
            }
        }
    }

    private var gameOverOverlay: some View {
        overlayCard {
            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .red.opacity(0.8), radius: 10)

                VStack(spacing: 6) {
                    Text("Score: \(gameState.score)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Best: \(bestScore)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

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

                primaryButton(title: "Play Again", action: restartGame)
            }
        }
    }

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            content()
                .padding(30)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 32)
                .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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

    // MARK: - Flow

    private func startGame() {
        isStarted = true
        gameState.startGame(baseInterval: difficultyLevel.baseInterval)
    }

    private func restartGame() {
        gameState.startGame(baseInterval: difficultyLevel.baseInterval)
    }

    private func handleGameOver() {
        let score = gameState.score
        bestScore = max(bestScore, score)
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        adjustDifficulty()
    }

    /// Keep the pace honest: strong recent rounds start the next one faster.
    private func adjustDifficulty() {
        guard roundScores.count >= 2 else {
            difficultyLevel = .easy
            return
        }
        let recent = roundScores.suffix(3)
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)
        if avg >= 20 {
            difficultyLevel = .hard
        } else if avg >= 10 {
            difficultyLevel = .medium
        } else {
            difficultyLevel = .easy
        }
    }

    private func handleSwipe(translation: CGSize) {
        let dx = translation.width
        let dy = translation.height
        if abs(dx) > abs(dy) {
            gameState.changeDirection(dx > 0 ? .right : .left)
        } else {
            gameState.changeDirection(dy > 0 ? .down : .up)
        }
    }
}

#Preview {
    SnakeView()
}
