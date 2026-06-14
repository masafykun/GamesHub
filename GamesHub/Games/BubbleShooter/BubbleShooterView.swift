import SwiftUI

// MARK: - Constants

private enum BubbleShooterConstants {
    static let cols: Int = 9
    static let initialRows: Int = 6
    static let bubbleRadius: CGFloat = 22
    static let bubbleDiameter: CGFloat = 44
    static let shooterRadius: CGFloat = 26
    static let projectileSpeed: CGFloat = 600 // points per second
    static let tickInterval: TimeInterval = 1.0 / 60.0
    static let popScore: Int = 30
    static let newRowEveryShots: Int = 10
    static let colors: [Color] = [.red, .blue, .green, .yellow, .purple]
    static let colorNames: [String] = ["red", "blue", "green", "yellow", "purple"]
}

// MARK: - Models

struct BubbleShooterBubble: Identifiable, Equatable {
    let id: UUID = UUID()
    var col: Int
    var row: Int
    var colorIndex: Int

    static func == (lhs: BubbleShooterBubble, rhs: BubbleShooterBubble) -> Bool {
        lhs.id == rhs.id
    }
}

struct BubbleShooterProjectile {
    var x: CGFloat
    var y: CGFloat
    var dx: CGFloat
    var dy: CGFloat
    var colorIndex: Int
}

enum BubbleShooterGameState {
    case idle
    case aiming
    case shooting
    case gameOver
}

// MARK: - LCG RNG (no Foundation)

private struct BubbleShooterRNG {
    private var state: UInt64

    init(seed: UInt64 = 12345) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - ViewModel

@MainActor
final class BubbleShooterViewModel: ObservableObject {

    @Published var bubbles: [BubbleShooterBubble] = []
    @Published var projectile: BubbleShooterProjectile? = nil
    @Published var nextColorIndex: Int = 0
    @Published var aimAngle: Double = -.pi / 2   // radians, -pi/2 = straight up
    @Published var isDragging: Bool = false
    @Published var score: Int = 0
    @Published var shots: Int = 0
    @Published var gameState: BubbleShooterGameState = .aiming
    @Published var popFeedback: [BubbleShooterBubble] = []  // bubbles being animated out

    private var rng = BubbleShooterRNG(seed: UInt64(Date.timeIntervalSinceReferenceDate.bitPattern & 0xFFFFFFFF))
    private var gameTimer: Timer?
    var canvasSize: CGSize = .zero

    // Grid cell size (hex offset layout)
    var cellW: CGFloat { BubbleShooterConstants.bubbleDiameter }
    var cellH: CGFloat { BubbleShooterConstants.bubbleDiameter * 0.866 } // sqrt(3)/2

    func setup(size: CGSize) {
        canvasSize = size
        startNewGame()
    }

    func startNewGame() {
        stopTimer()
        bubbles = []
        score = 0
        shots = 0
        gameState = .aiming
        projectile = nil
        popFeedback = []
        generateInitialRows()
        nextColorIndex = rng.nextInt(BubbleShooterConstants.colors.count)
        startTimer()
    }

    // MARK: - Grid helpers

    func bubblePosition(col: Int, row: Int) -> CGPoint {
        let offsetX = (row % 2 == 0) ? 0.0 : cellW / 2.0
        let x = offsetX + cellW / 2.0 + CGFloat(col) * cellW
        let y = cellH / 2.0 + CGFloat(row) * cellH
        return CGPoint(x: x, y: y)
    }

    func gridCols(for row: Int) -> Int {
        row % 2 == 0 ? BubbleShooterConstants.cols : BubbleShooterConstants.cols - 1
    }

    private func generateInitialRows() {
        for row in 0..<BubbleShooterConstants.initialRows {
            addRow(at: row)
        }
    }

    private func addRow(at row: Int) {
        let cols = gridCols(for: row)
        for col in 0..<cols {
            let colorIdx = rng.nextInt(BubbleShooterConstants.colors.count)
            bubbles.append(BubbleShooterBubble(col: col, row: row, colorIndex: colorIdx))
        }
    }

    // Push all rows down by 1 and add new row at top
    private func addNewTopRow() {
        for i in 0..<bubbles.count {
            bubbles[i].row += 1
        }
        addRow(at: 0)
        // Check game over: any bubble row >= bottom threshold
        let maxAllowedRow = maxAllowedBubbleRow()
        if bubbles.contains(where: { $0.row >= maxAllowedRow }) {
            gameState = .gameOver
        }
    }

    private func maxAllowedBubbleRow() -> Int {
        // canvas height - shooter area; approximate row count
        let shooterAreaHeight: CGFloat = 120
        let usableHeight = canvasSize.height - shooterAreaHeight
        return Int(usableHeight / cellH)
    }

    // MARK: - Shooting

    func handleDrag(value: DragGesture.Value) {
        guard gameState == .aiming else { return }
        let shooterY = canvasSize.height - 90
        let dx = value.location.x - canvasSize.width / 2
        let dy = value.location.y - shooterY
        // angle from shooter toward touch, clamped away from horizontal
        var angle = atan2(dy, dx)
        // clamp: must aim upward (dy negative means up)
        // angle should be between -pi and 0 (pointing upward hemisphere)
        // allow some wiggle: clamp between -pi+0.15 and -0.15
        let minAngle = -Double.pi + 0.15
        let maxAngle = -0.15
        angle = max(minAngle, min(maxAngle, angle))
        aimAngle = angle
        isDragging = true
    }

    func handleDragEnd() {
        guard gameState == .aiming else { return }
        isDragging = false
        fireProjectile()
    }

    private func fireProjectile() {
        guard gameState == .aiming else { return }
        let shooterX = canvasSize.width / 2
        let shooterY = canvasSize.height - 90
        let speed = BubbleShooterConstants.projectileSpeed
        let dx = CGFloat(cos(aimAngle)) * speed
        let dy = CGFloat(sin(aimAngle)) * speed
        projectile = BubbleShooterProjectile(
            x: shooterX, y: shooterY,
            dx: dx, dy: dy,
            colorIndex: nextColorIndex
        )
        shots += 1
        nextColorIndex = rng.nextInt(BubbleShooterConstants.colors.count)
        gameState = .shooting
    }

    // MARK: - Game Loop

    private func startTimer() {
        gameTimer = Timer(timeInterval: BubbleShooterConstants.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(gameTimer!, forMode: .common)
    }

    private func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func tick() {
        guard gameState == .shooting, var proj = projectile else { return }

        let dt = CGFloat(BubbleShooterConstants.tickInterval)
        proj.x += proj.dx * dt
        proj.y += proj.dy * dt

        // Wall bouncing (left/right)
        let r = BubbleShooterConstants.bubbleRadius
        if proj.x - r < 0 {
            proj.x = r
            proj.dx = abs(proj.dx)
        } else if proj.x + r > canvasSize.width {
            proj.x = canvasSize.width - r
            proj.dx = -abs(proj.dx)
        }

        // Ceiling
        if proj.y - r < 0 {
            proj.y = r
            // snap to grid
            projectile = proj
            snapProjectile()
            return
        }

        // Check collision with existing bubbles
        for bubble in bubbles {
            let bPos = bubblePosition(col: bubble.col, row: bubble.row)
            let dist = hypot(proj.x - bPos.x, proj.y - bPos.y)
            if dist < BubbleShooterConstants.bubbleDiameter * 0.9 {
                projectile = proj
                snapProjectile()
                return
            }
        }

        projectile = proj
    }

    private func snapProjectile() {
        guard var proj = projectile else { return }

        // Find nearest grid cell that is empty
        let nearestCell = findNearestEmptyCell(x: proj.x, y: proj.y)
        let newBubble = BubbleShooterBubble(col: nearestCell.col, row: nearestCell.row, colorIndex: proj.colorIndex)
        bubbles.append(newBubble)
        projectile = nil

        // Check for matches
        let matched = findMatches(startId: newBubble.id, colorIndex: newBubble.colorIndex)
        if matched.count >= 3 {
            score += matched.count * BubbleShooterConstants.popScore
            let matchedBubbles = bubbles.filter { matched.contains($0.id) }
            popFeedback = matchedBubbles
            bubbles.removeAll { matched.contains($0.id) }
            // Find disconnected bubbles
            let disconnected = findDisconnectedBubbles()
            if !disconnected.isEmpty {
                score += disconnected.count * BubbleShooterConstants.popScore
                bubbles.removeAll { disconnected.contains($0.id) }
            }
            // Clear pop feedback after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.popFeedback = []
            }
        }

        // Every N shots add a new row
        if shots % BubbleShooterConstants.newRowEveryShots == 0 {
            addNewTopRow()
        }

        // Check game over
        let maxRow = maxAllowedBubbleRow()
        if bubbles.contains(where: { $0.row >= maxRow }) {
            gameState = .gameOver
            stopTimer()
            return
        }

        gameState = .aiming
    }

    private func findNearestEmptyCell(x: CGFloat, y: CGFloat) -> (col: Int, row: Int) {
        // Estimate row from y
        var bestRow = max(0, Int(y / cellH))
        var bestCol = 0
        var bestDist = CGFloat.infinity

        // Search nearby rows
        for rowOffset in -1...1 {
            let row = max(0, bestRow + rowOffset)
            let cols = gridCols(for: row)
            for col in 0..<cols {
                // Skip occupied cells
                if bubbles.contains(where: { $0.col == col && $0.row == row }) { continue }
                let pos = bubblePosition(col: col, row: row)
                let dist = hypot(x - pos.x, y - pos.y)
                if dist < bestDist {
                    bestDist = dist
                    bestRow = row
                    bestCol = col
                }
            }
        }

        // If still no empty found, brute search closest empty
        if bestDist == .infinity {
            for b in bubbles {
                let neighbors = getNeighbors(col: b.col, row: b.row)
                for n in neighbors {
                    if !bubbles.contains(where: { $0.col == n.col && $0.row == n.row }) {
                        let pos = bubblePosition(col: n.col, row: n.row)
                        let dist = hypot(x - pos.x, y - pos.y)
                        if dist < bestDist {
                            bestDist = dist
                            bestRow = n.row
                            bestCol = n.col
                        }
                    }
                }
            }
        }

        return (col: bestCol, row: max(0, bestRow))
    }

    // MARK: - Match detection

    private func findMatches(startId: UUID, colorIndex: Int) -> Set<UUID> {
        guard let startBubble = bubbles.first(where: { $0.id == startId }) else { return [] }
        var visited = Set<UUID>()
        var queue = [startBubble]
        visited.insert(startBubble.id)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = getNeighborBubbles(col: current.col, row: current.row)
            for neighbor in neighbors {
                if !visited.contains(neighbor.id) && neighbor.colorIndex == colorIndex {
                    visited.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        return visited
    }

    private func findDisconnectedBubbles() -> Set<UUID> {
        // BFS from all top-row bubbles (row == 0)
        let topBubbles = bubbles.filter { $0.row == 0 }
        var connected = Set<UUID>()
        var queue = topBubbles
        for b in topBubbles { connected.insert(b.id) }

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = getNeighborBubbles(col: current.col, row: current.row)
            for neighbor in neighbors {
                if !connected.contains(neighbor.id) {
                    connected.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }

        let disconnected = bubbles.filter { !connected.contains($0.id) }
        return Set(disconnected.map { $0.id })
    }

    // MARK: - Neighbor helpers

    private func getNeighborBubbles(col: Int, row: Int) -> [BubbleShooterBubble] {
        let neighborCells = getNeighbors(col: col, row: row)
        return bubbles.filter { b in neighborCells.contains(where: { $0.col == b.col && $0.row == b.row }) }
    }

    private func getNeighbors(col: Int, row: Int) -> [(col: Int, row: Int)] {
        let isEvenRow = row % 2 == 0
        // hex grid neighbors
        var neighbors: [(col: Int, row: Int)] = [
            (col - 1, row),
            (col + 1, row),
            (col, row - 1),
            (col, row + 1)
        ]
        if isEvenRow {
            neighbors.append((col - 1, row - 1))
            neighbors.append((col - 1, row + 1))
        } else {
            neighbors.append((col + 1, row - 1))
            neighbors.append((col + 1, row + 1))
        }
        return neighbors.filter { $0.col >= 0 && $0.row >= 0 && $0.col < BubbleShooterConstants.cols }
    }
}

// MARK: - Main View

struct BubbleShooterView: View {
    @StateObject private var vm = BubbleShooterViewModel()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.18), Color(red: 0.1, green: 0.05, blue: 0.25)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    // Grid bubbles
                    ForEach(vm.bubbles) { bubble in
                        BubbleShooterBubbleView(colorIndex: bubble.colorIndex, isPopping: false)
                            .position(vm.bubblePosition(col: bubble.col, row: bubble.row))
                    }

                    // Pop feedback
                    ForEach(vm.popFeedback) { bubble in
                        BubbleShooterBubbleView(colorIndex: bubble.colorIndex, isPopping: true)
                            .position(vm.bubblePosition(col: bubble.col, row: bubble.row))
                    }

                    // Projectile
                    if let proj = vm.projectile {
                        BubbleShooterBubbleView(colorIndex: proj.colorIndex, isPopping: false)
                            .position(x: proj.x, y: proj.y)
                    }

                    // Aim line
                    if vm.gameState == .aiming && vm.isDragging {
                        BubbleShooterAimLine(
                            from: CGPoint(x: geo.size.width / 2, y: geo.size.height - 90),
                            angle: vm.aimAngle,
                            canvasWidth: geo.size.width
                        )
                    }

                    // Shooter
                    BubbleShooterShooterView(
                        nextColorIndex: vm.nextColorIndex,
                        canvasWidth: geo.size.width
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height - 90)

                    // Game over overlay
                    if vm.gameState == .gameOver {
                        BubbleShooterGameOverView(score: vm.score) {
                            vm.setup(size: geo.size)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if vm.canvasSize == .zero {
                                vm.setup(size: geo.size)
                            }
                            vm.handleDrag(value: value)
                        }
                        .onEnded { _ in
                            vm.handleDragEnd()
                        }
                )
                .onAppear {
                    vm.setup(size: geo.size)
                }
            }

            // HUD
            VStack {
                BubbleShooterHUDView(score: vm.score, shots: vm.shots)
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Bubble View

struct BubbleShooterBubbleView: View {
    let colorIndex: Int
    let isPopping: Bool

    private var color: Color {
        BubbleShooterConstants.colors[colorIndex % BubbleShooterConstants.colors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.9), color, color.opacity(0.6)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: BubbleShooterConstants.bubbleRadius
                    )
                )
                .frame(width: BubbleShooterConstants.bubbleDiameter - 4,
                       height: BubbleShooterConstants.bubbleDiameter - 4)
                .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 2)

            // Shine
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 10, height: 10)
                .offset(x: -6, y: -6)
        }
        .scaleEffect(isPopping ? 1.4 : 1.0)
        .opacity(isPopping ? 0.0 : 1.0)
        .animation(isPopping ? .easeOut(duration: 0.3) : .none, value: isPopping)
    }
}

// MARK: - Aim Line View

struct BubbleShooterAimLine: View {
    let from: CGPoint
    let angle: Double
    let canvasWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            let dotCount = 12
            let spacing: CGFloat = 28
            for i in 0..<dotCount {
                let t = CGFloat(i) * spacing
                let x = from.x + CGFloat(cos(angle)) * t
                let y = from.y + CGFloat(sin(angle)) * t
                let rect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                let opacity = 1.0 - Double(i) / Double(dotCount)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(opacity * 0.7))
                )
            }
        }
    }
}

// MARK: - Shooter View

struct BubbleShooterShooterView: View {
    let nextColorIndex: Int
    let canvasWidth: CGFloat

    private var color: Color {
        BubbleShooterConstants.colors[nextColorIndex % BubbleShooterConstants.colors.count]
    }

    var body: some View {
        ZStack {
            // Base
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 2)
                )

            // Next bubble preview
            BubbleShooterBubbleView(colorIndex: nextColorIndex, isPopping: false)
        }
    }
}

// MARK: - HUD View

struct BubbleShooterHUDView: View {
    let score: Int
    let shots: Int

    var body: some View {
        HStack(spacing: 24) {
            BubbleShooterStatBox(label: "SCORE", value: "\(score)")
            Spacer()
            BubbleShooterStatBox(label: "SHOTS", value: "\(shots)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct BubbleShooterStatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Game Over View

struct BubbleShooterGameOverView: View {
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Score: \(score)")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                        .shadow(color: .purple.opacity(0.5), radius: 10)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.2))
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
        }
    }
}
