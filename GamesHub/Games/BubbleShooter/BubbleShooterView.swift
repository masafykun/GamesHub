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

    /// Fewer colours on easy makes matches far more likely.
    var colorCount: Int {
        switch self {
        case .easy: return 4
        case .medium: return 5
        case .hard: return 5
        }
    }
}

enum BubbleShooterGameState {
    case idle, aiming, gameOver
}

struct BubbleShooterBubble: Identifiable {
    let id: Int
    var row: Int
    var col: Int
    var color: BubbleShooterColor
}

struct BubbleShooterProjectile {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: BubbleShooterColor
    var active: Bool
}

struct BubbleShooterPopEffect: Identifiable {
    let id: Int
    var position: CGPoint
    var color: Color
    var lifetime: Double = 0.4
    var maxLifetime: Double = 0.4
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// MARK: - Engine

final class BubbleShooterEngine: ObservableObject {
    var canvasSize: CGSize = .zero
    var bubbleRadius: CGFloat = 22
    var hexRowHeight: CGFloat { bubbleRadius * 1.73 }
    let topOffset: CGFloat = 80

    @Published var bubbles: [BubbleShooterBubble] = []
    @Published var nextColor: BubbleShooterColor = .red
    @Published var currentColor: BubbleShooterColor = .red
    @Published var projectile = BubbleShooterProjectile(x: 0, y: 0, vx: 0, vy: 0, color: .red, active: false)
    @Published var aimAngle: CGFloat = -.pi / 2
    @Published var score: Int = 0
    @Published var shots: Int = 0
    @Published var shotsUntilNewRow: Int = 8
    @Published var gameState: BubbleShooterGameState = .idle
    @Published var difficulty: BubbleShooterDifficulty = .medium
    @Published var roundScores: [Int] = []
    @Published var popEffects: [BubbleShooterPopEffect] = []

    var gridRows: Int = 5
    var projectileSpeed: CGFloat = 12.0
    var shotsPerRow: Int = 8

    private var timer: Timer?
    private var nextBubbleID: Int = 0
    private var shotsSinceNewRow: Int = 0

    var shooterY: CGFloat { canvasSize.height - 110 }

    // MARK: Setup

    func setup(size: CGSize) {
        canvasSize = size
        projectile.x = size.width / 2
        projectile.y = shooterY
    }

    func startGame() {
        guard canvasSize != .zero else { return }
        computeDifficulty()
        score = 0
        shots = 0
        shotsSinceNewRow = 0
        shotsUntilNewRow = shotsPerRow
        popEffects = []
        buildGrid()
        pickNextColor()
        currentColor = randomColor()
        projectile = BubbleShooterProjectile(x: canvasSize.width / 2, y: shooterY,
                                             vx: 0, vy: 0, color: currentColor, active: false)
        aimAngle = -.pi / 2
        gameState = .aiming
        startTimer()
    }

    private func randomColor() -> BubbleShooterColor {
        BubbleShooterColor.allCases[Int.random(in: 0..<difficulty.colorCount)]
    }

    func buildGrid() {
        bubbles = []
        nextBubbleID = 0
        for row in 0..<gridRows {
            for col in 0..<columnsForRow(row) {
                bubbles.append(BubbleShooterBubble(id: nextBubbleID, row: row, col: col, color: randomColor()))
                nextBubbleID += 1
            }
        }
    }

    func columnsForRow(_ row: Int) -> Int {
        let base = Int(canvasSize.width / (bubbleRadius * 2.0))
        return row % 2 == 0 ? base : base - 1
    }

    func bubblePosition(row: Int, col: Int) -> CGPoint {
        // Every row is laid out from the same origin so the hex offset
        // stays centred instead of pushing odd rows off the right edge.
        let baseCols = columnsForRow(0)
        let totalWidth = CGFloat(baseCols) * bubbleRadius * 2
        let startX = (canvasSize.width - totalWidth) / 2 + bubbleRadius
        let xOff = row % 2 == 1 ? bubbleRadius : 0
        return CGPoint(
            x: startX + CGFloat(col) * bubbleRadius * 2 + xOff,
            y: topOffset + CGFloat(row) * hexRowHeight
        )
    }

    // MARK: Aim & fire

    func updateAim(location: CGPoint) {
        guard gameState == .aiming, !projectile.active else { return }
        let dx = location.x - canvasSize.width / 2
        let dy = location.y - shooterY
        var angle = atan2(dy, dx)
        angle = max(-.pi + 0.18, min(-0.18, angle))
        aimAngle = angle
    }

    func fire() {
        guard gameState == .aiming, !projectile.active else { return }
        projectile.x = canvasSize.width / 2
        projectile.y = shooterY
        projectile.vx = cos(aimAngle) * projectileSpeed
        projectile.vy = sin(aimAngle) * projectileSpeed
        projectile.color = currentColor
        projectile.active = true
        shots += 1
        shotsSinceNewRow += 1
        shotsUntilNewRow = max(0, shotsPerRow - shotsSinceNewRow)
        currentColor = nextColor
        pickNextColor()
    }

    func pickNextColor() {
        nextColor = randomColor()
    }

    // MARK: Loop

    func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard gameState == .aiming else { return }
        moveProjectile()
        updatePopEffects()
    }

    private func moveProjectile() {
        guard projectile.active else { return }

        projectile.x += projectile.vx
        projectile.y += projectile.vy

        if projectile.x - bubbleRadius < 0 {
            projectile.x = bubbleRadius
            projectile.vx = abs(projectile.vx)
        } else if projectile.x + bubbleRadius > canvasSize.width {
            projectile.x = canvasSize.width - bubbleRadius
            projectile.vx = -abs(projectile.vx)
        }

        if projectile.y - bubbleRadius < topOffset - hexRowHeight {
            snapProjectile()
            return
        }

        for bubble in bubbles {
            let pos = bubblePosition(row: bubble.row, col: bubble.col)
            let dx = projectile.x - pos.x
            let dy = projectile.y - pos.y
            if sqrt(dx * dx + dy * dy) < bubbleRadius * 1.85 {
                snapProjectile()
                return
            }
        }

        if projectile.y > canvasSize.height + bubbleRadius {
            projectile.active = false
        }
    }

    private func snapProjectile() {
        projectile.active = false
        let (row, col) = findSnapPosition(x: projectile.x, y: projectile.y)
        let newBubble = BubbleShooterBubble(id: nextBubbleID, row: row, col: col, color: projectile.color)
        nextBubbleID += 1
        bubbles.append(newBubble)

        let matched = findMatches(id: newBubble.id, color: newBubble.color)
        if matched.count >= 3 {
            score += matched.count * 30
            spawnPops(for: matched)
            let matchedIDs = Set(matched.map { $0.id })
            bubbles.removeAll { matchedIDs.contains($0.id) }

            // Anything no longer hanging from the ceiling falls too.
            let dropped = findDisconnected()
            if !dropped.isEmpty {
                score += dropped.count * 20
                spawnPops(for: dropped)
                let droppedIDs = Set(dropped.map { $0.id })
                bubbles.removeAll { droppedIDs.contains($0.id) }
            }

            if bubbles.isEmpty {
                score += 500
                clearBoardBonus()
                return
            }
        }

        if shotsSinceNewRow >= shotsPerRow {
            shotsSinceNewRow = 0
            addNewRow()
        }
        shotsUntilNewRow = max(0, shotsPerRow - shotsSinceNewRow)

        checkGameOver()
    }

    private func spawnPops(for list: [BubbleShooterBubble]) {
        for b in list {
            popEffects.append(
                BubbleShooterPopEffect(
                    id: nextBubbleID + popEffects.count,
                    position: bubblePosition(row: b.row, col: b.col),
                    color: b.color.color
                )
            )
        }
    }

    /// Clearing the board refills it — the run keeps going and gets a bonus.
    private func clearBoardBonus() {
        gridRows = min(gridRows + 1, 9)
        buildGrid()
        shotsSinceNewRow = 0
        shotsUntilNewRow = shotsPerRow
    }

    private func findSnapPosition(x: CGFloat, y: CGFloat) -> (Int, Int) {
        var bestRow = 0
        var bestCol = 0
        var bestDist = CGFloat.infinity

        let maxRow = Int((canvasSize.height - topOffset) / hexRowHeight) + 1
        for row in 0..<max(maxRow, 6) {
            for col in 0..<columnsForRow(row) {
                let occupied = bubbles.contains { $0.row == row && $0.col == col }
                guard !occupied else { continue }
                let pos = bubblePosition(row: row, col: col)
                let dx = x - pos.x
                let dy = y - pos.y
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

    private func findMatches(id: Int, color: BubbleShooterColor) -> [BubbleShooterBubble] {
        var visited = Set<Int>()
        var queue: [BubbleShooterBubble] = []
        var result: [BubbleShooterBubble] = []

        guard let start = bubbles.first(where: { $0.id == id }) else { return [] }
        queue.append(start)
        visited.insert(start.id)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            for n in getNeighbors(row: current.row, col: current.col) where !visited.contains(n.id) && n.color == color {
                visited.insert(n.id)
                queue.append(n)
            }
        }
        return result
    }

    private func getNeighbors(row: Int, col: Int) -> [BubbleShooterBubble] {
        let offsets: [(Int, Int)] = row % 2 == 0
            ? [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)]
            : [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)]
        return offsets.compactMap { (dr, dc) in
            bubbles.first { $0.row == row + dr && $0.col == col + dc }
        }
    }

    private func findDisconnected() -> [BubbleShooterBubble] {
        var connectedIDs = Set<Int>()
        var queue = bubbles.filter { $0.row == 0 }
        for b in queue { connectedIDs.insert(b.id) }

        var i = 0
        while i < queue.count {
            let current = queue[i]
            i += 1
            for n in getNeighbors(row: current.row, col: current.col) where !connectedIDs.contains(n.id) {
                connectedIDs.insert(n.id)
                queue.append(n)
            }
        }
        return bubbles.filter { !connectedIDs.contains($0.id) }
    }

    private func addNewRow() {
        for i in bubbles.indices { bubbles[i].row += 1 }
        for col in 0..<columnsForRow(0) {
            bubbles.append(BubbleShooterBubble(id: nextBubbleID, row: 0, col: col, color: randomColor()))
            nextBubbleID += 1
        }
    }

    private func checkGameOver() {
        let limit = shooterY - bubbleRadius * 2
        for bubble in bubbles {
            if bubblePosition(row: bubble.row, col: bubble.col).y >= limit {
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
    }

    func computeDifficulty() {
        guard !roundScores.isEmpty else {
            difficulty = .medium
            gridRows = 5
            projectileSpeed = 12.0
            shotsPerRow = 8
            return
        }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg < 400 {
            difficulty = .easy
            gridRows = 4
            projectileSpeed = 11.0
            shotsPerRow = 10
        } else if avg < 1200 {
            difficulty = .medium
            gridRows = 5
            projectileSpeed = 12.5
            shotsPerRow = 8
        } else {
            difficulty = .hard
            gridRows = 7
            projectileSpeed = 14.5
            shotsPerRow = 6
        }
    }

    private func updatePopEffects() {
        popEffects = popEffects.compactMap { effect in
            var e = effect
            e.lifetime -= 1.0 / 60.0
            e.scale += 0.05
            e.opacity = max(0, e.lifetime / e.maxLifetime)
            return e.lifetime > 0 ? e : nil
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Main View

struct BubbleShooterView: View {
    @StateObject private var engine = BubbleShooterEngine()
    @AppStorage("bubbleShooterBestScore") private var bestScore: Int = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient

                BubbleShooterGameCanvas(engine: engine)

                VStack {
                    topBar
                    Spacer()
                    if engine.gameState == .aiming {
                        bottomShooterUI
                    }
                }

                ForEach(engine.popEffects) { effect in
                    Circle()
                        .fill(effect.color.opacity(effect.opacity))
                        .frame(width: engine.bubbleRadius * 2 * effect.scale,
                               height: engine.bubbleRadius * 2 * effect.scale)
                        .position(effect.position)
                        .allowsHitTesting(false)
                }

                if engine.gameState == .idle {
                    idleOverlay
                } else if engine.gameState == .gameOver {
                    gameOverOverlay
                }
            }
            .onAppear { engine.setup(size: geo.size) }
            .onChange(of: engine.gameState) { _, state in
                if state == .gameOver { bestScore = max(bestScore, engine.score) }
            }
            .onDisappear { engine.stopTimer() }
        }
        .preferredColorScheme(.dark)
    }

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
                VStack(spacing: 2) {
                    Text("NEW ROW IN")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(engine.shotsUntilNewRow)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(engine.shotsUntilNewRow <= 2 ? .red : .primary)
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    var bottomShooterUI: some View {
        HStack {
            Spacer()
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
                    .frame(width: 30, height: 30)
                    .shadow(color: engine.nextColor.color.opacity(0.5), radius: 6)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.trailing, 18)
            .padding(.bottom, 34)
        }
    }

    func glassLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    var idleOverlay: some View {
        overlayCard {
            VStack(spacing: 20) {
                Text("BUBBLE SHOOTER")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("Drag to aim · release to fire")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Match 3+ to pop · cut them loose to drop clusters")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if bestScore > 0 {
                        Text("Best: \(bestScore)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }

                capsuleButton(title: "TAP TO PLAY", colors: [.cyan, .purple]) { engine.startGame() }
            }
        }
    }

    var gameOverOverlay: some View {
        overlayCard {
            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))

                Text("Score: \(engine.score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Best: \(bestScore) · \(engine.shots) shots")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("Next difficulty:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 5) {
                        Circle().fill(engine.difficulty.badgeColor).frame(width: 9, height: 9)
                        Text(engine.difficulty.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(engine.difficulty.badgeColor)
                    }
                }

                capsuleButton(title: "PLAY AGAIN", colors: [.orange, .red]) { engine.startGame() }
            }
        }
    }

    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            content()
                .padding(26)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 28)
        }
    }

    private func capsuleButton(title: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 13)
                .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: colors[0].opacity(0.45), radius: 12, x: 0, y: 5)
        }
    }
}

// MARK: - Canvas

struct BubbleShooterGameCanvas: View {
    @ObservedObject var engine: BubbleShooterEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(engine.bubbles) { bubble in
                    BubbleShooterBubbleView(color: bubble.color.color, radius: engine.bubbleRadius)
                        .position(engine.bubblePosition(row: bubble.row, col: bubble.col))
                }

                if engine.gameState == .aiming && !engine.projectile.active {
                    BubbleShooterAimLine(
                        from: CGPoint(x: engine.canvasSize.width / 2, y: engine.shooterY),
                        angle: engine.aimAngle,
                        color: engine.currentColor.color
                    )
                }

                if engine.gameState != .idle {
                    BubbleShooterShooterBase(
                        currentColor: engine.currentColor.color,
                        radius: engine.bubbleRadius,
                        x: engine.canvasSize.width / 2,
                        y: engine.shooterY
                    )
                }

                if engine.projectile.active {
                    BubbleShooterBubbleView(color: engine.projectile.color.color, radius: engine.bubbleRadius)
                        .position(CGPoint(x: engine.projectile.x, y: engine.projectile.y))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        engine.updateAim(location: value.location)
                    }
                    .onEnded { value in
                        engine.updateAim(location: value.location)
                        engine.fire()
                    }
            )
            .onAppear {
                if engine.canvasSize == .zero { engine.setup(size: geo.size) }
            }
        }
    }
}

struct BubbleShooterBubbleView: View {
    let color: Color
    let radius: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(1.0), color.opacity(0.65)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 1,
                    endRadius: radius * 1.3
                )
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: radius * 0.5, height: radius * 0.4)
                    .offset(x: -radius * 0.28, y: -radius * 0.32)
            )
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .frame(width: radius * 2, height: radius * 2)
    }
}

struct BubbleShooterAimLine: View {
    let from: CGPoint
    let angle: CGFloat
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: CGPoint(
                x: from.x + cos(angle) * 220,
                y: from.y + sin(angle) * 220
            ))
        }
        .stroke(
            color.opacity(0.55),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 10])
        )
        .allowsHitTesting(false)
    }
}

struct BubbleShooterShooterBase: View {
    let currentColor: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
                .frame(width: radius * 2.8, height: radius * 2.8)
                .shadow(color: currentColor.opacity(0.4), radius: 10)

            BubbleShooterBubbleView(color: currentColor, radius: radius)
        }
        .position(CGPoint(x: x, y: y))
    }
}

#Preview {
    BubbleShooterView()
}
