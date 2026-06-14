import SwiftUI

// MARK: - Constants
private enum BubbleShooterConstants {
    static let cols = 9
    static let maxRows = 14
    static let bubbleRadius: CGFloat = 20
    static let hexOffsetY: CGFloat = 34
    static let hexOffsetX: CGFloat = 40
    static let colorCount = 5
    static let shotsPerNewRow = 10
    static let matchThreshold = 3
    static let scorePerBubble = 30
}

// MARK: - V3-Private Models

struct BSV3Bubble: Identifiable {
    let id: UUID
    var row: Int
    var col: Int
    var color: BubbleShooterColor
    init(row: Int, col: Int, color: BubbleShooterColor) {
        self.id = UUID()
        self.row = row
        self.col = col
        self.color = color
    }
}

struct BSV3Projectile {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: BubbleShooterColor
    var active: Bool
}

// MARK: - LCG Random
struct BubbleShooterLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Int) -> Int {
        guard range > 0 else { return 0 }
        return Int(next() % UInt64(range))
    }
}

// MARK: - Main View
struct BubbleShooterViewV3: View {
    // MARK: Seed
    @State var seedInt: Int = 1

    // MARK: Grid state
    @State private var bubbles: [BSV3Bubble] = []
    @State private var projectile = BSV3Projectile(x: 0, y: 0, vx: 0, vy: 0, color: .red, active: false)
    @State private var nextBubbleColor: BubbleShooterColor = .red
    @State private var gameState: BubbleShooterGameState = .aiming

    // MARK: Score / shots
    @State private var score: Int = 0
    @State private var shots: Int = 0

    // MARK: Aim
    @State private var aimAngle: CGFloat = -.pi / 2  // straight up
    @State private var isDragging: Bool = false
    @State private var aimLineEnd: CGPoint = .zero

    // MARK: Timer
    @State private var gameTimer: Timer? = nil

    // MARK: Geometry cache
    @State private var canvasSize: CGSize = .zero

    // MARK: LCG for new rows
    @State private var rng: BubbleShooterLCG = BubbleShooterLCG(seed: 1)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Game canvas
                    ZStack {
                        Color(.systemGray6)

                        // Bubbles
                        ForEach(bubbles) { bubble in
                            bubbleView(bubble)
                        }

                        // Aim line
                        if gameState == .aiming || gameState == .idle {
                            aimLineView
                        }

                        // Projectile
                        if projectile.active {
                            Circle()
                                .fill(projectile.color.color)
                                .frame(width: BubbleShooterConstants.bubbleRadius * 2,
                                       height: BubbleShooterConstants.bubbleRadius * 2)
                                .overlay(
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                                center: .init(x: 0.35, y: 0.3),
                                                startRadius: 1,
                                                endRadius: BubbleShooterConstants.bubbleRadius
                                            )
                                        )
                                )
                                .shadow(color: projectile.color.color.opacity(0.5), radius: 4, x: 2, y: 2)
                                .position(x: projectile.x, y: projectile.y)
                        }

                        // Shooter
                        shooterView(in: geo.size)

                        // Game Over overlay
                        if gameState == .gameOver {
                            gameOverOverlay
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard gameState != .gameOver else { return }
                                guard !projectile.active else { return }
                                gameState = .aiming
                                isDragging = true
                                let shooterPos = shooterPosition(in: canvasSize)
                                let dx = value.location.x - shooterPos.x
                                let dy = value.location.y - shooterPos.y
                                let len = sqrt(dx * dx + dy * dy)
                                if len > 5 {
                                    var angle = atan2(dy, dx)
                                    // Clamp so bubble goes upward
                                    let minAngle: CGFloat = -.pi + 0.15
                                    let maxAngle: CGFloat = -0.15
                                    angle = max(minAngle, min(maxAngle, angle))
                                    aimAngle = angle
                                    aimLineEnd = value.location
                                }
                            }
                            .onEnded { _ in
                                guard gameState == .aiming else { return }
                                isDragging = false
                                fireProjectile()
                            }
                    )
                    .background(
                        GeometryReader { inner in
                            Color.clear
                                .onAppear {
                                    canvasSize = inner.size
                                }
                                .onChange(of: inner.size) {
                                    canvasSize = inner.size
                                }
                        }
                    )
                }
            }
            .onAppear {
                startGame()
            }
        }
    }

    // MARK: - Header
    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(minWidth: 70)
            .padding(10)
            .neumorphicCard()

            Spacer()

            VStack(spacing: 2) {
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("BUBBLE SHOOTER")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .neumorphicCard()

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SHOTS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(shots)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(minWidth: 70)
            .padding(10)
            .neumorphicCard()
        }
    }

    // MARK: - Bubble View
    func bubbleView(_ bubble: BSV3Bubble) -> some View {
        let pos = bubblePosition(row: bubble.row, col: bubble.col, in: canvasSize)
        let r = BubbleShooterConstants.bubbleRadius
        return Circle()
            .fill(bubble.color.color)
            .frame(width: r * 2, height: r * 2)
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.55), .clear]),
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 1,
                            endRadius: r
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: bubble.color.color.opacity(0.4), radius: 4, x: 2, y: 2)
            .shadow(color: Color.white.opacity(0.6), radius: 3, x: -2, y: -2)
            .position(pos)
    }

    // MARK: - Aim Line
    var aimLineView: some View {
        Canvas { context, size in
            guard canvasSize != .zero else { return }
            let start = shooterPosition(in: canvasSize)
            let length: CGFloat = 140
            let ex = start.x + cos(aimAngle) * length
            let ey = start.y + sin(aimAngle) * length

            var path = Path()
            path.move(to: start)
            path.addLine(to: CGPoint(x: ex, y: ey))

            context.stroke(
                path,
                with: .color(.white.opacity(0.45)),
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )

            // Dot at end
            let dotRect = CGRect(x: ex - 5, y: ey - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.6)))
        }
    }

    // MARK: - Shooter View
    func shooterView(in size: CGSize) -> some View {
        let pos = shooterPosition(in: canvasSize)
        return ZStack {
            // Base
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 54, height: 54)
                .shadow(color: .white.opacity(0.8), radius: 6, x: -3, y: -3)
                .shadow(color: Color(.systemGray4), radius: 6, x: 3, y: 3)

            // Next bubble preview inside shooter
            Circle()
                .fill(nextBubbleColor.color)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 1,
                                endRadius: 17
                            )
                        )
                )
                .shadow(color: nextBubbleColor.color.opacity(0.5), radius: 4, x: 1, y: 1)

            // Aim indicator line from center upward
            if gameState == .aiming || isDragging {
                Rectangle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 3, height: 14)
                    .offset(x: cos(aimAngle) * 20, y: sin(aimAngle) * 20)
                    .rotationEffect(.radians(aimAngle + .pi / 2))
            }
        }
        .position(pos)
    }

    // MARK: - Game Over Overlay
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("Score: \(score)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Shots: \(shots)")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                Button(action: restartGame) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 24)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
        }
    }

    // MARK: - Position Helpers
    func bubblePosition(row: Int, col: Int, in size: CGSize) -> CGPoint {
        let r = BubbleShooterConstants.bubbleRadius
        let ox = BubbleShooterConstants.hexOffsetX
        let oy = BubbleShooterConstants.hexOffsetY
        let isOddRow = row % 2 == 1
        let totalWidth = CGFloat(BubbleShooterConstants.cols) * ox
        let startX = (size.width - totalWidth) / 2 + r + (isOddRow ? ox / 2 : 0)
        let x = startX + CGFloat(col) * ox
        let y = r + CGFloat(row) * oy
        return CGPoint(x: x, y: y)
    }

    func shooterPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height - 50)
    }

    // MARK: - Game Setup
    func startGame() {
        rng = BubbleShooterLCG(seed: seedInt)
        bubbles = generateInitialGrid()
        score = 0
        shots = 0
        gameState = .idle
        nextBubbleColor = randomColor()
        projectile.active = false
        aimAngle = -.pi / 2
    }

    func restartGame() {
        stopTimer()
        seedInt += 1
        startGame()
    }

    func generateInitialGrid() -> [BSV3Bubble] {
        var result: [BSV3Bubble] = []
        let initialRows = 5
        let cols = BubbleShooterConstants.cols
        for row in 0..<initialRows {
            let colCount = row % 2 == 0 ? cols : cols - 1
            for col in 0..<colCount {
                let colorIdx = rng.nextInt(in: BubbleShooterConstants.colorCount)
                let color = BubbleShooterColor(rawValue: colorIdx) ?? .red
                result.append(BSV3Bubble(row: row, col: col, color: color))
            }
        }
        return result
    }

    func randomColor() -> BubbleShooterColor {
        let idx = rng.nextInt(in: BubbleShooterConstants.colorCount)
        return BubbleShooterColor(rawValue: idx) ?? .red
    }

    // MARK: - Firing
    func fireProjectile() {
        guard gameState != .gameOver, !projectile.active else { return }
        let pos = shooterPosition(in: canvasSize)
        let speed: CGFloat = 600
        projectile = BSV3Projectile(
            x: pos.x,
            y: pos.y,
            vx: cos(aimAngle) * speed,
            vy: sin(aimAngle) * speed,
            color: nextBubbleColor,
            active: true
        )
        gameState = .shooting
        shots += 1
        nextBubbleColor = randomColor()
        startTimer()
    }

    // MARK: - Timer
    func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame()
        }
        RunLoop.main.add(t, forMode: .common)
        gameTimer = t
    }

    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    // MARK: - Game Update
    func updateGame() {
        guard projectile.active else { return }
        let dt: CGFloat = 1.0 / 60.0
        projectile.x += projectile.vx * dt
        projectile.y += projectile.vy * dt

        // Wall bounce
        let r = BubbleShooterConstants.bubbleRadius
        if projectile.x - r < 0 {
            projectile.x = r
            projectile.vx = abs(projectile.vx)
        } else if projectile.x + r > canvasSize.width {
            projectile.x = canvasSize.width - r
            projectile.vx = -abs(projectile.vx)
        }

        // Top wall: snap to top row
        if projectile.y - r < r {
            snapProjectile()
            return
        }

        // Check collision with existing bubbles
        for bubble in bubbles {
            let bpos = bubblePosition(row: bubble.row, col: bubble.col, in: canvasSize)
            let dx = projectile.x - bpos.x
            let dy = projectile.y - bpos.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < r * 1.9 {
                snapProjectile()
                return
            }
        }

        // Fell off screen
        if projectile.y > canvasSize.height {
            projectile.active = false
            gameState = .idle
            stopTimer()
        }
    }

    // MARK: - Snap Projectile to Grid
    func snapProjectile() {
        projectile.active = false
        stopTimer()

        // Find best grid cell
        let best = findBestCell(for: CGPoint(x: projectile.x, y: projectile.y))
        let newBubble = BSV3Bubble(row: best.row, col: best.col, color: projectile.color)
        bubbles.append(newBubble)

        // Match & pop
        let matched = findMatches(at: best, color: projectile.color)
        if matched.count >= BubbleShooterConstants.matchThreshold {
            let matchedIDs = Set(matched.map { $0.id })
            bubbles.removeAll { matchedIDs.contains($0.id) }
            score += matched.count * BubbleShooterConstants.scorePerBubble

            // Remove disconnected
            removeDisconnected()
        }

        // Check game over: any bubble below bottom threshold
        let bottomThreshold = canvasSize.height - 90
        let hasReachedBottom = bubbles.contains { b in
            let pos = bubblePosition(row: b.row, col: b.col, in: canvasSize)
            return pos.y > bottomThreshold
        }
        if hasReachedBottom {
            gameState = .gameOver
            return
        }

        // Add new row every N shots
        if shots > 0 && shots % BubbleShooterConstants.shotsPerNewRow == 0 {
            addNewRow()
            // Check again after adding
            let hasReachedBottomAfter = bubbles.contains { b in
                let pos = bubblePosition(row: b.row, col: b.col, in: canvasSize)
                return pos.y > bottomThreshold
            }
            if hasReachedBottomAfter {
                gameState = .gameOver
                return
            }
        }

        gameState = .idle
    }

    func findBestCell(for point: CGPoint) -> (row: Int, col: Int) {
        let r = BubbleShooterConstants.bubbleRadius
        let ox = BubbleShooterConstants.hexOffsetX
        let oy = BubbleShooterConstants.hexOffsetY
        let cols = BubbleShooterConstants.cols

        // Estimate row from y
        var bestRow = max(0, Int((point.y - r) / oy))
        var bestCol = 0
        var bestDist: CGFloat = .greatestFiniteMagnitude

        // Search nearby rows
        for row in max(0, bestRow - 1)...min(BubbleShooterConstants.maxRows - 1, bestRow + 1) {
            let isOddRow = row % 2 == 1
            let totalWidth = CGFloat(cols) * ox
            let startX = (canvasSize.width - totalWidth) / 2 + r + (isOddRow ? ox / 2 : 0)
            let colCount = isOddRow ? cols - 1 : cols
            for col in 0..<colCount {
                // Skip if already occupied
                if bubbles.contains(where: { $0.row == row && $0.col == col }) { continue }
                let x = startX + CGFloat(col) * ox
                let y = r + CGFloat(row) * oy
                let dx = point.x - x
                let dy = point.y - y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < bestDist {
                    bestDist = dist
                    bestRow = row
                    bestCol = col
                }
            }
        }
        return (bestRow, bestCol)
    }

    // MARK: - Match Finding (BFS)
    func findMatches(at cell: (row: Int, col: Int), color: BubbleShooterColor) -> [BSV3Bubble] {
        var visited = Set<UUID>()
        var queue: [BSV3Bubble] = []
        var result: [BSV3Bubble] = []

        if let start = bubbles.first(where: { $0.row == cell.row && $0.col == cell.col && $0.color == color }) {
            queue.append(start)
            visited.insert(start.id)
        }

        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            let neighbors = hexNeighbors(row: current.row, col: current.col)
            for (nr, nc) in neighbors {
                if let neighbor = bubbles.first(where: { $0.row == nr && $0.col == nc && $0.color == color && !visited.contains($0.id) }) {
                    visited.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        return result
    }

    // MARK: - Remove Disconnected Bubbles
    func removeDisconnected() {
        guard !bubbles.isEmpty else { return }

        var connected = Set<UUID>()
        var queue: [BSV3Bubble] = bubbles.filter { $0.row == 0 }
        for b in queue { connected.insert(b.id) }

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = hexNeighbors(row: current.row, col: current.col)
            for (nr, nc) in neighbors {
                if let neighbor = bubbles.first(where: { $0.row == nr && $0.col == nc && !connected.contains($0.id) }) {
                    connected.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }

        let dropped = bubbles.filter { !connected.contains($0.id) }
        bubbles.removeAll { !connected.contains($0.id) }
        score += dropped.count * BubbleShooterConstants.scorePerBubble
    }

    // MARK: - Hex Neighbors
    func hexNeighbors(row: Int, col: Int) -> [(Int, Int)] {
        let isOdd = row % 2 == 1
        var neighbors: [(Int, Int)] = [
            (row, col - 1),
            (row, col + 1),
            (row - 1, col),
            (row + 1, col),
        ]
        if isOdd {
            neighbors.append((row - 1, col + 1))
            neighbors.append((row + 1, col + 1))
        } else {
            neighbors.append((row - 1, col - 1))
            neighbors.append((row + 1, col - 1))
        }
        return neighbors.filter { $0.0 >= 0 && $0.1 >= 0 && $0.1 < BubbleShooterConstants.cols }
    }

    // MARK: - Add New Row
    func addNewRow() {
        // Shift all existing bubbles down by 1 row
        bubbles = bubbles.map { b in
            var nb = b
            nb = BSV3Bubble(row: b.row + 1, col: b.col, color: b.color)
            return nb
        }

        // Add new row at top (row 0)
        let cols = BubbleShooterConstants.cols
        for col in 0..<cols {
            let colorIdx = rng.nextInt(in: BubbleShooterConstants.colorCount)
            let color = BubbleShooterColor(rawValue: colorIdx) ?? .red
            bubbles.append(BSV3Bubble(row: 0, col: col, color: color))
        }
    }
}
