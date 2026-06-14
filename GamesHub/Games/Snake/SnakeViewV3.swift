import SwiftUI

// MARK: - Models

struct SnakePoint: Equatable {
    var col: Int
    var row: Int
}

// MARK: - SnakeDirection extensions for V3

extension SnakeDirection: CaseIterable {
    static var allCases: [SnakeDirection] { [.up, .down, .left, .right] }

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

// MARK: - LCG Procedural Generator

struct SnakeLCG {
    private var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = next()
        return Int(n % UInt64(range.count)) + range.lowerBound
    }

    mutating func nextDirection() -> SnakeDirection {
        let idx = Int(next() % 4)
        return SnakeDirection.allCases[idx]
    }
}

// MARK: - Game Phase

enum SnakeGamePhase {
    case playing
    case gameOver
}

// MARK: - Game Logic

class SnakeGameV3: ObservableObject {
    static let gridSize = 20
    static let moveInterval: TimeInterval = 0.15

    @Published var snake: [SnakePoint] = []
    @Published var food: SnakePoint = SnakePoint(col: 0, row: 0)
    @Published var direction: SnakeDirection = .right
    @Published var state: SnakeGamePhase = .playing
    @Published var score: Int = 0

    private var pendingDirection: SnakeDirection = .right
    private var lcg: SnakeLCG
    private var timer: Timer?
    private var moveTimer: Timer?
    private var tickCount: Int = 0
    private let moveTicks: Int  // how many 1/60s ticks per snake move
    private var seedInt: Int

    init(seedInt: Int) {
        self.seedInt = seedInt
        self.lcg = SnakeLCG(seed: seedInt)
        self.moveTicks = Int(SnakeGameV3.moveInterval * 60)
        startGame()
    }

    func startGame() {
        timer?.invalidate()
        timer = nil
        tickCount = 0

        lcg = SnakeLCG(seed: seedInt)

        let initialDirection = lcg.nextDirection()
        direction = initialDirection
        pendingDirection = initialDirection

        let midCol = SnakeGameV3.gridSize / 2
        let midRow = SnakeGameV3.gridSize / 2

        // Build initial snake of length 3 facing the initial direction
        let head = SnakePoint(col: midCol, row: midRow)
        let body = SnakePoint(col: midCol - initialDirection.dx, row: midRow - initialDirection.dy)
        let tail = SnakePoint(col: midCol - initialDirection.dx * 2, row: midRow - initialDirection.dy * 2)
        snake = [head, body, tail]

        state = .playing
        score = snake.count - 2

        spawnFood()
        startTimer()
    }

    private func spawnFood() {
        let occupied = Set(snake.map { "\($0.col),\($0.row)" })
        var attempts = 0
        repeat {
            let col = lcg.nextInt(in: 0..<SnakeGameV3.gridSize)
            let row = lcg.nextInt(in: 0..<SnakeGameV3.gridSize)
            let candidate = SnakePoint(col: col, row: row)
            if !occupied.contains("\(col),\(row)") {
                food = candidate
                return
            }
            attempts += 1
        } while attempts < 400

        // Fallback: linear scan
        for r in 0..<SnakeGameV3.gridSize {
            for c in 0..<SnakeGameV3.gridSize {
                if !occupied.contains("\(c),\(r)") {
                    food = SnakePoint(col: c, row: r)
                    return
                }
            }
        }
    }

    private func startTimer() {
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func tick() {
        guard state == .playing else { return }
        tickCount += 1
        if tickCount >= moveTicks {
            tickCount = 0
            moveSnake()
        }
    }

    private func moveSnake() {
        direction = pendingDirection

        guard let head = snake.first else { return }
        let newHead = SnakePoint(
            col: head.col + direction.dx,
            row: head.row + direction.dy
        )

        // Wall collision
        if newHead.col < 0 || newHead.col >= SnakeGameV3.gridSize ||
           newHead.row < 0 || newHead.row >= SnakeGameV3.gridSize {
            endGame()
            return
        }

        // Self collision (exclude tail tip since it will move away)
        let body = snake.dropLast()
        if body.contains(newHead) {
            endGame()
            return
        }

        let ateFood = newHead == food

        if ateFood {
            snake.insert(newHead, at: 0)
            score = snake.count - 2
            spawnFood()
        } else {
            snake.insert(newHead, at: 0)
            snake.removeLast()
        }
    }

    private func endGame() {
        state = .gameOver
        timer?.invalidate()
        timer = nil
    }

    func changeDirection(_ newDir: SnakeDirection) {
        guard newDir != direction.opposite else { return }
        pendingDirection = newDir
    }

    func restart(newSeed: Int) {
        seedInt = newSeed
        startGame()
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Main View

struct SnakeViewV3: View {
    @StateObject private var game = SnakeGameV3(seedInt: 1)
    @State var seedInt: Int = 1

    private let gridSize = SnakeGameV3.gridSize

    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 16
            let boardSize = min(geo.size.width, geo.size.height) - padding * 2
            let cellSize = boardSize / CGFloat(gridSize)

            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SNAKE")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("SEED: #\(seedInt)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("SCORE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("\(game.score)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .neumorphicCard()
                    .padding(.horizontal, padding)

                    // Game Board
                    ZStack {
                        // Background grid
                        Canvas { ctx, size in
                            let cs = size.width / CGFloat(gridSize)
                            for row in 0..<gridSize {
                                for col in 0..<gridSize {
                                    let rect = CGRect(
                                        x: CGFloat(col) * cs + 1,
                                        y: CGFloat(row) * cs + 1,
                                        width: cs - 2,
                                        height: cs - 2
                                    )
                                    let path = Path(roundedRect: rect, cornerRadius: 2)
                                    let isDark = (row + col) % 2 == 0
                                    ctx.fill(path, with: .color(
                                        isDark
                                            ? Color(.systemGray5)
                                            : Color(.systemGray6)
                                    ))
                                }
                            }
                        }

                        // Food
                        Canvas { ctx, size in
                            let cs = size.width / CGFloat(gridSize)
                            let f = game.food
                            let rect = CGRect(
                                x: CGFloat(f.col) * cs + 2,
                                y: CGFloat(f.row) * cs + 2,
                                width: cs - 4,
                                height: cs - 4
                            )
                            let path = Path(ellipseIn: rect)
                            ctx.fill(path, with: .color(.red))
                            // Highlight
                            let hlRect = CGRect(
                                x: CGFloat(f.col) * cs + cs * 0.3,
                                y: CGFloat(f.row) * cs + cs * 0.2,
                                width: cs * 0.2,
                                height: cs * 0.2
                            )
                            let hlPath = Path(ellipseIn: hlRect)
                            ctx.fill(hlPath, with: .color(.white.opacity(0.5)))
                        }

                        // Snake
                        Canvas { ctx, size in
                            let cs = size.width / CGFloat(gridSize)
                            let snakeBody = game.snake
                            for (i, segment) in snakeBody.enumerated() {
                                let isHead = i == 0
                                let inset: CGFloat = isHead ? 1 : 2
                                let rect = CGRect(
                                    x: CGFloat(segment.col) * cs + inset,
                                    y: CGFloat(segment.row) * cs + inset,
                                    width: cs - inset * 2,
                                    height: cs - inset * 2
                                )
                                let corner: CGFloat = isHead ? 5 : 3
                                let path = Path(roundedRect: rect, cornerRadius: corner)
                                let t = Double(i) / Double(max(snakeBody.count - 1, 1))
                                let green = Color(
                                    hue: 0.33 + t * 0.05,
                                    saturation: 0.8 - t * 0.2,
                                    brightness: isHead ? 0.75 : (0.6 - t * 0.15)
                                )
                                ctx.fill(path, with: .color(green))

                                if isHead {
                                    // Eyes
                                    let eyeSize = cs * 0.18
                                    let eyeOffsets: [(CGFloat, CGFloat)] = [(0.28, 0.28), (0.72, 0.28)]
                                    for (ex, ey) in eyeOffsets {
                                        let eyeRect = CGRect(
                                            x: CGFloat(segment.col) * cs + cs * ex - eyeSize / 2,
                                            y: CGFloat(segment.row) * cs + cs * ey - eyeSize / 2,
                                            width: eyeSize,
                                            height: eyeSize
                                        )
                                        ctx.fill(Path(ellipseIn: eyeRect), with: .color(.white))
                                        let pupilRect = eyeRect.insetBy(dx: eyeSize * 0.2, dy: eyeSize * 0.2)
                                        ctx.fill(Path(ellipseIn: pupilRect), with: .color(.black))
                                    }
                                }
                            }
                        }

                        // Game Over Overlay
                        if game.state == .gameOver {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6).opacity(0.92))
                                .overlay(
                                    VStack(spacing: 16) {
                                        Text("GAME OVER")
                                            .font(.system(size: 26, weight: .black, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text("Score: \(game.score)")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                        Text("SEED: #\(seedInt)")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Button(action: restartGame) {
                                            Text("RESTART")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 32)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [.green, Color(hue: 0.38, saturation: 0.8, brightness: 0.5)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(color: .green.opacity(0.4), radius: 6, x: 0, y: 4)
                                        }
                                    }
                                )
                                .padding(30)
                        }
                    }
                    .frame(width: boardSize, height: boardSize)
                    .neumorphicCard(radius: 20)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                if abs(dx) > abs(dy) {
                                    game.changeDirection(dx > 0 ? .right : .left)
                                } else {
                                    game.changeDirection(dy > 0 ? .down : .up)
                                }
                            }
                    )

                    // Seed display footer
                    HStack {
                        Image(systemName: "dice.fill")
                            .foregroundColor(.secondary)
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Swipe to steer")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .neumorphicCard()
                    .padding(.horizontal, padding)
                }
                .padding(.top, 8)
            }
        }
    }

    private func restartGame() {
        seedInt += 1
        game.restart(newSeed: seedInt)
    }
}

// MARK: - Preview

#Preview {
    SnakeViewV3()
}
