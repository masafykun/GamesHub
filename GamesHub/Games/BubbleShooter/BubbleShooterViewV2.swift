import SwiftUI

// MARK: - Models

enum BubbleShooterColor: Int, CaseIterable {
    case red, blue, green, yellow, purple

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.95, green: 0.3, blue: 0.3)
        case .blue:   return Color(red: 0.3, green: 0.55, blue: 0.95)
        case .green:  return Color(red: 0.3, green: 0.85, blue: 0.45)
        case .yellow: return Color(red: 0.98, green: 0.85, blue: 0.2)
        case .purple: return Color(red: 0.75, green: 0.35, blue: 0.95)
        }
    }
}

enum BubbleShooterDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

// MARK: - V2-Private Models

struct BSV2Bubble: Identifiable {
    let id: Int
    var row: Int
    var col: Int
    var color: BubbleShooterColor
}

struct BSV2Projectile {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: BubbleShooterColor
    var active: Bool
}

// MARK: - Game Engine

class BubbleShooterEngine: ObservableObject {

    // Layout
    var canvasSize: CGSize = .zero
    var bubbleRadius: CGFloat = 22
    var hexRowHeight: CGFloat { bubbleRadius * 1.73 }
    var topOffset: CGFloat = 100

    // Grid
    @Published var bubbles: [BSV2Bubble] = []
    @Published var nextColor: BubbleShooterColor = .red
    @Published var currentColor: BubbleShooterColor = .red
    @Published var projectile: BSV2Projectile = BSV2Projectile(x: 0, y: 0, vx: 0, vy: 0, color: .red, active: false)
    @Published var aimAngle: CGFloat = -.pi / 2  // radians, straight up
    @Published var score: Int = 0
    @Published var shots: Int = 0
    @Published var gameState: BubbleShooterGameState = .aiming
    @Published var difficulty: BubbleShooterDifficulty = .medium
    @Published var roundScores: [Int] = []
    @Published var popEffects: [BubbleShooterPopEffect] = []

    // Difficulty params
    var gridRows: Int = 6
    var projectileSpeed: CGFloat = 12.0

    private var timer: Timer?
    private var nextBubbleID: Int = 0
    private var shotsSinceNewRow: Int = 0

    // MARK: - Setup

    func setup(size: CGSize) {
        canvasSize = size
        projectile.x = size.width / 2
        projectile.y = size.height - 80
    }

    func startGame() {
        guard canvasSize != .zero else { return }
        score = 0
        shots = 0
        shotsSinceNewRow = 0
        popEffects = []
        buildGrid()
        pickNextColor()
        pickCurrentColor()
        projectile = BSV2Projectile(x: canvasSize.width / 2, y: canvasSize.height - 80,
                                     vx: 0, vy: 0, color: currentColor, active: false)
        aimAngle = -.pi / 2
        gameState = .aiming
        startTimer()
    }

    func buildGrid() {
        bubbles = []
        nextBubbleID = 0
        let cols = columnsForRow(0)
        for row in 0..<gridRows {
            let count = columnsForRow(row)
            for col in 0..<count {
                let color = BubbleShooterColor.allCases.randomElement()!
                bubbles.append(BSV2Bubble(id: nextBubbleID, row: row, col: col, color: color))
                nextBubbleID += 1
            }
        }
        _ = cols
    }

    func columnsForRow(_ row: Int) -> Int {
        // Hex grid: even rows have one more column
        let base = Int(canvasSize.width / (bubbleRadius * 2.0)) + 1
        return row % 2 == 0 ? base : base - 1
    }

    func bubblePosition(row: Int, col: Int) -> CGPoint {
        let cols = columnsForRow(row)
        let totalWidth = CGFloat(cols) * bubbleRadius * 2 - bubbleRadius
        let startX = (canvasSize.width - totalWidth) / 2 + bubbleRadius
        let xOff = row % 2 == 1 ? bubbleRadius : 0
        let x = startX + CGFloat(col) * bubbleRadius * 2 + xOff
        let y = topOffset + CGFloat(row) * hexRowHeight
        return CGPoint(x: x, y: y)
    }

    // MARK: - Aim & Fire

    func updateAim(location: CGPoint) {
        guard gameState != .gameOver && !projectile.active else { return }
        let shooterX = canvasSize.width / 2
        let shooterY = canvasSize.height - 80
        let dx = location.x - shooterX
        let dy = location.y - shooterY
        var angle = atan2(dy, dx)
        // Clamp to upper hemisphere
        let minAngle = -.pi + 0.15
        let maxAngle = -0.15
        angle = max(minAngle, min(maxAngle, angle))
        aimAngle = angle
    }

    func fire() {
        guard gameState != .gameOver && !projectile.active else { return }
        projectile.x = canvasSize.width / 2
        projectile.y = canvasSize.height - 80
        projectile.vx = cos(aimAngle) * projectileSpeed
        projectile.vy = sin(aimAngle) * projectileSpeed
        projectile.color = currentColor
        projectile.active = true
        shots += 1
        shotsSinceNewRow += 1
        currentColor = nextColor
        pickNextColor()
    }

    func pickNextColor() {
        nextColor = BubbleShooterColor.allCases.randomElement()!
    }

    func pickCurrentColor() {
        currentColor = BubbleShooterColor.allCases.randomElement()!
    }

    // MARK: - Timer & Loop

    func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard gameState != .gameOver else { return }
        moveProjectile()
        updatePopEffects()
    }

    func moveProjectile() {
        guard projectile.active else { return }

        projectile.x += projectile.vx
        projectile.y += projectile.vy

        // Wall bounces
        if projectile.x - bubbleRadius < 0 {
            projectile.x = bubbleRadius
            projectile.vx = abs(projectile.vx)
        } else if projectile.x + bubbleRadius > canvasSize.width {
            projectile.x = canvasSize.width - bubbleRadius
            projectile.vx = -abs(projectile.vx)
        }

        // Hit top wall
        if projectile.y - bubbleRadius < topOffset / 2 {
            snapProjectile()
            return
        }

        // Check collision with existing bubbles
        for bubble in bubbles {
            let pos = bubblePosition(row: bubble.row, col: bubble.col)
            let dx = projectile.x - pos.x
            let dy = projectile.y - pos.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bubbleRadius * 1.85 {
                snapProjectile()
                return
            }
        }

        // Passed below visible area without hitting: just deactivate
        if projectile.y > canvasSize.height + bubbleRadius {
            projectile.active = false
        }
    }

    func snapProjectile() {
        projectile.active = false
        let (row, col) = findSnapPosition(x: projectile.x, y: projectile.y)
        let newBubble = BSV2Bubble(id: nextBubbleID, row: row, col: col, color: projectile.color)
        nextBubbleID += 1
        bubbles.append(newBubble)

        // Check matches
        let matched = findMatches(id: newBubble.id, color: newBubble.color)
        if matched.count >= 3 {
            let pts = matched.count * 30
            score += pts
            let matchedIDs = Set(matched.map { $0.id })
            // Spawn pop effects
            for b in matched {
                let pos = bubblePosition(row: b.row, col: b.col)
                popEffects.append(BubbleShooterPopEffect(id: nextBubbleID + popEffects.count,
                                                          position: pos, color: b.color.color))
            }
            bubbles.removeAll { matchedIDs.contains($0.id) }
            // Drop disconnected
            let dropped = findDisconnected()
            if !dropped.isEmpty {
                score += dropped.count * 10
                for b in dropped {
                    let pos = bubblePosition(row: b.row, col: b.col)
                    popEffects.append(BubbleShooterPopEffect(id: nextBubbleID + popEffects.count,
                                                              position: pos, color: b.color.color))
                }
                let droppedIDs = Set(dropped.map { $0.id })
                bubbles.removeAll { droppedIDs.contains($0.id) }
            }
        }

        // Add new row every 10 shots
        if shotsSinceNewRow >= 10 {
            shotsSinceNewRow = 0
            addNewRow()
        }

        // Check game over: any bubble in last rows
        checkGameOver()
    }

    func findSnapPosition(x: CGFloat, y: CGFloat) -> (Int, Int) {
        var bestRow = 0
        var bestCol = 0
        var bestDist = CGFloat.infinity

        let maxRow = (gridRows > 0 ? gridRows : 8) + 4
        for row in 0..<maxRow {
            let cols = columnsForRow(row)
            for col in 0..<cols {
                let pos = bubblePosition(row: row, col: col)
                let dx = x - pos.x
                let dy = y - pos.y
                let dist = sqrt(dx * dx + dy * dy)
                // Must be empty
                let occupied = bubbles.contains { $0.row == row && $0.col == col }
                if !occupied && dist < bestDist {
                    bestDist = dist
                    bestRow = row
                    bestCol = col
                }
            }
        }
        return (bestRow, bestCol)
    }

    // MARK: - Match Detection (flood fill)

    func findMatches(id: Int, color: BubbleShooterColor) -> [BSV2Bubble] {
        var visited = Set<Int>()
        var queue: [BSV2Bubble] = []
        var result: [BSV2Bubble] = []

        guard let start = bubbles.first(where: { $0.id == id }) else { return [] }
        queue.append(start)
        visited.insert(start.id)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            let neighbors = getNeighbors(row: current.row, col: current.col)
            for n in neighbors {
                if !visited.contains(n.id) && n.color == color {
                    visited.insert(n.id)
                    queue.append(n)
                }
            }
        }
        return result
    }

    func getNeighbors(row: Int, col: Int) -> [BSV2Bubble] {
        let offsets: [(Int, Int)]
        if row % 2 == 0 {
            offsets = [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)]
        } else {
            offsets = [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)]
        }
        return offsets.compactMap { (dr, dc) in
            bubbles.first { $0.row == row + dr && $0.col == col + dc }
        }
    }

    // MARK: - Disconnected Detection

    func findDisconnected() -> [BSV2Bubble] {
        // Bubbles connected to row 0 are safe
        var connectedIDs = Set<Int>()
        var queue = bubbles.filter { $0.row == 0 }
        for b in queue { connectedIDs.insert(b.id) }

        var i = 0
        while i < queue.count {
            let current = queue[i]
            i += 1
            let neighbors = getNeighbors(row: current.row, col: current.col)
            for n in neighbors {
                if !connectedIDs.contains(n.id) {
                    connectedIDs.insert(n.id)
                    queue.append(n)
                }
            }
        }
        return bubbles.filter { !connectedIDs.contains($0.id) }
    }

    // MARK: - Add New Row

    func addNewRow() {
        // Shift all existing bubbles down by one row
        for i in bubbles.indices {
            bubbles[i].row += 1
        }
        // Add new row at top (row 0)
        let cols = columnsForRow(0)
        for col in 0..<cols {
            let color = BubbleShooterColor.allCases.randomElement()!
            bubbles.append(BSV2Bubble(id: nextBubbleID, row: 0, col: col, color: color))
            nextBubbleID += 1
        }
    }

    // MARK: - Game Over Check

    func checkGameOver() {
        let limit = canvasSize.height - 120
        for bubble in bubbles {
            let pos = bubblePosition(row: bubble.row, col: bubble.col)
            if pos.y >= limit {
                endGame()
                return
            }
        }
    }

    func endGame() {
        stopTimer()
        gameState = .gameOver
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        computeDifficulty()
    }

    // MARK: - Adaptive Difficulty

    func computeDifficulty() {
        guard !roundScores.isEmpty else {
            difficulty = .medium
            gridRows = 6
            projectileSpeed = 12.0
            return
        }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg < 150 {
            difficulty = .easy
            gridRows = 4
            projectileSpeed = 10.0
        } else if avg < 400 {
            difficulty = .medium
            gridRows = 6
            projectileSpeed = 12.0
        } else {
            difficulty = .hard
            gridRows = 8
            projectileSpeed = 15.0
        }
    }

    // MARK: - Pop Effects

    func updatePopEffects() {
        popEffects = popEffects.compactMap { effect in
            var e = effect
            e.lifetime -= 1.0 / 60.0
            e.scale += 0.05
            e.opacity = max(0, e.lifetime / e.maxLifetime)
            return e.lifetime > 0 ? e : nil
        }
    }
}

// MARK: - Pop Effect Model

struct BubbleShooterPopEffect: Identifiable {
    let id: Int
    var position: CGPoint
    var color: Color
    var lifetime: Double = 0.4
    var maxLifetime: Double = 0.4
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// MARK: - Main View

struct BubbleShooterViewV2: View {
    @StateObject private var engine = BubbleShooterEngine()
    @State var roundScores: [Int] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient

                if engine.canvasSize != .zero {
                    BubbleShooterGameCanvas(engine: engine)
                }

                VStack {
                    topBar
                    Spacer()
                    if engine.gameState != .gameOver {
                        bottomShooterUI
                    }
                }

                // Pop effects layer
                ForEach(engine.popEffects) { effect in
                    Circle()
                        .fill(effect.color.opacity(effect.opacity))
                        .frame(width: engine.bubbleRadius * 2 * effect.scale,
                               height: engine.bubbleRadius * 2 * effect.scale)
                        .position(effect.position)
                        .allowsHitTesting(false)
                }

                if engine.canvasSize == .zero {
                    idleOverlay
                } else if engine.gameState == .gameOver {
                    gameOverOverlay
                }
            }
            .onAppear {
                engine.roundScores = roundScores
                engine.computeDifficulty()
                engine.setup(size: geo.size)
            }
            .onChange(of: engine.roundScores) { _, newVal in
                roundScores = newVal
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background

    var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.04, green: 0.04, blue: 0.18), Color(red: 0.08, green: 0.04, blue: 0.22)]
                : [Color(red: 0.82, green: 0.88, blue: 1.0), Color(red: 0.72, green: 0.78, blue: 0.97)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack(spacing: 10) {
            glassLabel {
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(engine.score)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            glassLabel {
                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.difficulty.badgeColor)
                        .frame(width: 8, height: 8)
                    Text(engine.difficulty.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(engine.difficulty.badgeColor)
                }
            }

            Spacer()

            glassLabel {
                VStack(spacing: 2) {
                    Text("SHOTS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(engine.shots)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
    }

    // MARK: - Bottom Shooter UI

    var bottomShooterUI: some View {
        HStack {
            Spacer()

            // Next bubble preview
            VStack(spacing: 4) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [engine.nextColor.color.opacity(0.95), engine.nextColor.color.opacity(0.6)],
                            center: .topLeading, startRadius: 0, endRadius: 20
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .frame(width: 32, height: 32)
                    .shadow(color: engine.nextColor.color.opacity(0.5), radius: 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1))
            .padding(.trailing, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Glass Helper

    func glassLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Idle Overlay

    var idleOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("BUBBLE SHOOTER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple, .pink],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .multilineTextAlignment(.center)

                Text("V2 — Adaptive Difficulty")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Drag to aim  •  Release to fire")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Match 3+ bubbles to pop (+30 pts each)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if !roundScores.isEmpty {
                    glassLabel {
                        VStack(spacing: 4) {
                            Text("Recent Scores")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(roundScores.map { "\($0)" }.joined(separator: "  "))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                            let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
                            Text("Avg: \(Int(avg))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                difficultyBadgeView

                Button(action: {
                    engine.setup(size: .zero)
                    engine.startGame()
                }) {
                    Text("TAP TO PLAY")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.cyan, .purple],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.45), radius: 14, x: 0, y: 6)
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(engine.score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if !roundScores.isEmpty {
                    glassLabel {
                        VStack(spacing: 5) {
                            Text("Last \(roundScores.count) Rounds")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(roundScores.map { "\($0)" }.joined(separator: "  "))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                            let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
                            Text("Moving Avg: \(Int(avg))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                difficultyBadgeView

                Button(action: { engine.startGame() }) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [.orange, .red],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Difficulty Badge

    var difficultyBadgeView: some View {
        HStack(spacing: 8) {
            Text("Next difficulty:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 5) {
                Circle()
                    .fill(engine.difficulty.badgeColor)
                    .frame(width: 9, height: 9)
                Text(engine.difficulty.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(engine.difficulty.badgeColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Game Canvas

struct BubbleShooterGameCanvas: View {
    @ObservedObject var engine: BubbleShooterEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Grid bubbles
                ForEach(engine.bubbles) { bubble in
                    let pos = engine.bubblePosition(row: bubble.row, col: bubble.col)
                    Circle()
                        .fill(bubble.color.color)
                        .frame(width: engine.bubbleRadius * 2, height: engine.bubbleRadius * 2)
                        .position(pos)
                }

                // Aim guide line
                if !engine.projectile.active {
                    BubbleShooterAimLine(
                        from: CGPoint(x: engine.canvasSize.width / 2,
                                      y: engine.canvasSize.height - 80),
                        angle: engine.aimAngle,
                        canvasWidth: engine.canvasSize.width
                    )
                }

                // Shooter base
                BubbleShooterShooterBase(
                    currentColor: engine.currentColor.color,
                    radius: engine.bubbleRadius,
                    x: engine.canvasSize.width / 2,
                    y: engine.canvasSize.height - 80
                )

                // Projectile in flight
                if engine.projectile.active {
                    Circle()
                        .fill(engine.projectile.color.color)
                        .frame(width: engine.bubbleRadius * 2, height: engine.bubbleRadius * 2)
                        .position(CGPoint(x: engine.projectile.x, y: engine.projectile.y))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if engine.canvasSize == .zero {
                            engine.setup(size: geo.size)
                            engine.startGame()
                            return
                        }
                        if engine.gameState != .gameOver {
                            engine.updateAim(location: value.location)
                        }
                    }
                    .onEnded { value in
                        if engine.gameState != .gameOver {
                            engine.updateAim(location: value.location)
                            engine.fire()
                        }
                    }
            )
            .onAppear {
                if engine.canvasSize == .zero {
                    engine.setup(size: geo.size)
                }
            }
        }
    }
}

// MARK: - Bubble View

// MARK: - Aim Line

// MARK: - Shooter Base

struct BubbleShooterShooterBase: View {
    let currentColor: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
                .frame(width: radius * 2.8, height: radius * 2.8)
                .shadow(color: currentColor.opacity(0.4), radius: 10, x: 0, y: 0)

            // Current bubble inside
            Circle()
                .fill(currentColor)
                .frame(width: radius * 2, height: radius * 2)
        }
        .position(CGPoint(x: x, y: y))
    }
}
