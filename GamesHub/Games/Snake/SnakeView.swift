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
}

struct SnakeCell: Equatable, Hashable {
    var col: Int
    var row: Int
}

// MARK: - Game State

class SnakeGameState: ObservableObject {
    static let gridSize = 20
    static let moveInterval: TimeInterval = 0.15

    @Published var snake: [SnakeCell] = []
    @Published var food: SnakeCell = SnakeCell(col: 0, row: 0)
    @Published var direction: SnakeDirection = .right
    @Published var isGameOver: Bool = false
    @Published var score: Int = 0

    private var pendingDirection: SnakeDirection = .right
    private var moveTimer: Timer?
    private var moveAccumulator: TimeInterval = 0
    private var lastMoveTime: Date = Date()

    init() {
        startGame()
    }

    func startGame() {
        let mid = SnakeGameState.gridSize / 2
        snake = [
            SnakeCell(col: mid, row: mid),
            SnakeCell(col: mid - 1, row: mid),
            SnakeCell(col: mid - 2, row: mid)
        ]
        direction = .right
        pendingDirection = .right
        isGameOver = false
        score = snake.count - 2
        spawnFood()
        startTimer()
    }

    private func startTimer() {
        moveTimer?.invalidate()
        moveAccumulator = 0
        lastMoveTime = Date()
        moveTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        if let timer = moveTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func timerTick() {
        guard !isGameOver else { return }
        let now = Date()
        let delta = now.timeIntervalSince(lastMoveTime)
        lastMoveTime = now
        moveAccumulator += delta
        if moveAccumulator >= SnakeGameState.moveInterval {
            moveAccumulator -= SnakeGameState.moveInterval
            moveSnake()
        }
    }

    func changeDirection(_ newDirection: SnakeDirection) {
        guard newDirection != direction.opposite else { return }
        pendingDirection = newDirection
    }

    private func moveSnake() {
        direction = pendingDirection

        guard let head = snake.first else { return }

        let newHead: SnakeCell
        switch direction {
        case .up:    newHead = SnakeCell(col: head.col, row: head.row - 1)
        case .down:  newHead = SnakeCell(col: head.col, row: head.row + 1)
        case .left:  newHead = SnakeCell(col: head.col - 1, row: head.row)
        case .right: newHead = SnakeCell(col: head.col + 1, row: head.row)
        }

        // Wall collision
        let g = SnakeGameState.gridSize
        if newHead.col < 0 || newHead.col >= g || newHead.row < 0 || newHead.row >= g {
            triggerGameOver()
            return
        }

        // Self collision
        if snake.contains(newHead) {
            triggerGameOver()
            return
        }

        var newSnake = snake
        newSnake.insert(newHead, at: 0)

        if newHead == food {
            // Grow: don't remove tail
            score = newSnake.count - 2
            snake = newSnake
            spawnFood()
        } else {
            newSnake.removeLast()
            snake = newSnake
        }
    }

    private func triggerGameOver() {
        isGameOver = true
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func spawnFood() {
        let g = SnakeGameState.gridSize
        var empty: [SnakeCell] = []
        for col in 0..<g {
            for row in 0..<g {
                let cell = SnakeCell(col: col, row: row)
                if !snake.contains(cell) {
                    empty.append(cell)
                }
            }
        }
        if let chosen = empty.randomElement() {
            food = chosen
        }
    }
}

// MARK: - Main View

struct SnakeView: View {
    @StateObject private var gameState = SnakeGameState()

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height - 60)
            let cellSize = size / CGFloat(SnakeGameState.gridSize)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Score header
                    HStack {
                        Text("Score: \(gameState.score)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        Spacer()
                    }

                    // Game grid
                    ZStack(alignment: .topLeading) {
                        // Background grid
                        SnakeGridBackground(gridSize: SnakeGameState.gridSize, cellSize: cellSize)
                            .frame(width: size, height: size)

                        // Food
                        SnakeFoodView(cell: gameState.food, cellSize: cellSize)

                        // Snake
                        ForEach(Array(gameState.snake.enumerated()), id: \.offset) { index, cell in
                            SnakeCellView(cell: cell, cellSize: cellSize, isHead: index == 0)
                        }
                    }
                    .frame(width: size, height: size)
                    .clipped()
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                if abs(dx) > abs(dy) {
                                    gameState.changeDirection(dx > 0 ? .right : .left)
                                } else {
                                    gameState.changeDirection(dy > 0 ? .down : .up)
                                }
                            }
                    )

                    Spacer()
                }

                // Game Over overlay
                if gameState.isGameOver {
                    SnakeGameOverView(score: gameState.score) {
                        gameState.startGame()
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct SnakeGridBackground: View {
    let gridSize: Int
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let darkColor = Color(red: 0.08, green: 0.12, blue: 0.08)
            let lightColor = Color(red: 0.10, green: 0.15, blue: 0.10)

            for col in 0..<gridSize {
                for row in 0..<gridSize {
                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    let color = (col + row) % 2 == 0 ? darkColor : lightColor
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}

struct SnakeCellView: View {
    let cell: SnakeCell
    let cellSize: CGFloat
    let isHead: Bool

    var body: some View {
        let padding: CGFloat = 1
        RoundedRectangle(cornerRadius: isHead ? 4 : 2)
            .fill(isHead ? Color.green : Color(red: 0.2, green: 0.8, blue: 0.2))
            .frame(width: cellSize - padding * 2, height: cellSize - padding * 2)
            .offset(
                x: CGFloat(cell.col) * cellSize + padding,
                y: CGFloat(cell.row) * cellSize + padding
            )
    }
}

struct SnakeFoodView: View {
    let cell: SnakeCell
    let cellSize: CGFloat

    var body: some View {
        let padding: CGFloat = 2
        Circle()
            .fill(Color.red)
            .frame(width: cellSize - padding * 2, height: cellSize - padding * 2)
            .offset(
                x: CGFloat(cell.col) * cellSize + padding,
                y: CGFloat(cell.row) * cellSize + padding
            )
    }
}

struct SnakeGameOverView: View {
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.red)

                Text("Score: \(score)")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Button(action: onRestart) {
                    Text("Restart")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
            )
        }
    }
}
