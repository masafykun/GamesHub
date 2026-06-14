import SwiftUI

// MARK: - Neumorphism Extension

// MARK: - LCG Seeded RNG

struct DefenseV3LCG {
    var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &+ 1))
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + Int(next() % UInt64(span))
    }
}

// MARK: - Models

struct DefenseV3Tower: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var range: CGFloat = 2.0
    var damage: Int = 10
}

struct DefenseV3Enemy: Identifiable {
    let id = UUID()
    var position: CGFloat
    var health: Int
    var maxHealth: Int
    var speed: CGFloat
    var spawnDelay: CGFloat   // seconds before this enemy starts moving
    var spawned: Bool = false
}

enum DefenseV3GamePhase {
    case playing, gameOver
}

// MARK: - Main View

struct DefenseViewV3: View {
    let columns = 8
    let rows = 12
    let pathRow = 5

    @State private var towers: [DefenseV3Tower] = []
    @State private var enemies: [DefenseV3Enemy] = []
    @State private var pendingEnemies: [DefenseV3Enemy] = []
    @State private var gold: Int = 100
    @State private var lives: Int = 10
    @State private var wave: Int = 1
    @State private var score: Int = 0
    @State private var phase: DefenseV3GamePhase = .playing

    @State private var waveCleared: Bool = false
    @State private var nextWaveTimer: CGFloat = 0
    @State private var waveElapsed: CGFloat = 0

    @State private var seedInt: Int = 1
    @State private var gameTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width / CGFloat(columns), (geo.size.height - 90) / CGFloat(rows))
            let gridWidth = cellSize * CGFloat(columns)
            let gridHeight = cellSize * CGFloat(rows)

            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    defenseV3HUD(gridWidth: gridWidth)

                    ZStack(alignment: .topLeading) {
                        // Grid cells
                        ForEach(0..<rows, id: \.self) { row in
                            ForEach(0..<columns, id: \.self) { col in
                                defenseV3CellView(col: col, row: row, cellSize: cellSize)
                                    .position(
                                        x: CGFloat(col) * cellSize + cellSize / 2,
                                        y: CGFloat(row) * cellSize + cellSize / 2
                                    )
                                    .onTapGesture { placeTower(col: col, row: row) }
                            }
                        }

                        // Towers
                        ForEach(towers) { tower in
                            defenseV3TowerView(cellSize: cellSize)
                                .position(
                                    x: CGFloat(tower.col) * cellSize + cellSize / 2,
                                    y: CGFloat(tower.row) * cellSize + cellSize / 2
                                )
                        }

                        // Enemies
                        ForEach(enemies) { enemy in
                            defenseV3EnemyView(enemy: enemy, cellSize: cellSize)
                                .position(
                                    x: enemy.position * cellSize,
                                    y: CGFloat(pathRow) * cellSize + cellSize / 2
                                )
                        }
                    }
                    .frame(width: gridWidth, height: gridHeight)
                    .neumorphicCard(radius: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, max(0, (geo.size.width - gridWidth) / 2))
                .padding(.top, 10)

                if phase == .gameOver {
                    defenseV3GameOverOverlay()
                }
            }
        }
        .onAppear { startGame() }
        .onDisappear { stopGame() }
    }

    // MARK: - Sub Views

    func defenseV3HUD(gridWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            defenseV3StatItem(symbol: "circle.fill", color: .yellow, value: "\(gold)g")
            Spacer()
            defenseV3StatItem(symbol: "heart.fill", color: Color(red: 0.75, green: 0.3, blue: 0.3), value: "\(lives)")
            Spacer()
            defenseV3StatItem(symbol: "water.waves", color: Color(red: 0.35, green: 0.55, blue: 0.75), value: "W\(wave)")
            Spacer()
            defenseV3StatItem(symbol: "star.fill", color: Color(red: 0.7, green: 0.6, blue: 0.3), value: "\(score)")
            Spacer()
            // Seed badge
            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .neumorphicCard(radius: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: gridWidth)
        .neumorphicCard(radius: 16)
    }

    func defenseV3StatItem(symbol: String, color: Color, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
        }
    }

    func defenseV3CellView(col: Int, row: Int, cellSize: CGFloat) -> some View {
        let isPath = (row == pathRow)
        return RoundedRectangle(cornerRadius: 3)
            .fill(isPath
                ? Color(red: 0.82, green: 0.78, blue: 0.7)
                : Color(.systemGray6))
            .frame(width: cellSize - 2, height: cellSize - 2)
            .shadow(
                color: isPath ? Color.clear : Color.white.opacity(0.9),
                radius: 2, x: -1.5, y: -1.5
            )
            .shadow(
                color: isPath ? Color.clear : Color(red: 0.7, green: 0.7, blue: 0.74).opacity(0.45),
                radius: 2, x: 1.5, y: 1.5
            )
    }

    func defenseV3TowerView(cellSize: CGFloat) -> some View {
        ZStack {
            // Outer neumorphic ring
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                .shadow(color: Color.white.opacity(0.9), radius: 4, x: -3, y: -3)
                .shadow(color: Color(red: 0.65, green: 0.65, blue: 0.7).opacity(0.55), radius: 4, x: 3, y: 3)

            // Inner circle — muted steel blue
            Circle()
                .fill(Color(red: 0.42, green: 0.55, blue: 0.68))
                .frame(width: cellSize * 0.52, height: cellSize * 0.52)

            Image(systemName: "plus")
                .resizable()
                .scaledToFit()
                .frame(width: cellSize * 0.24, height: cellSize * 0.24)
                .foregroundColor(Color(.systemGray6).opacity(0.9))
        }
    }

    func defenseV3EnemyView(enemy: DefenseV3Enemy, cellSize: CGFloat) -> some View {
        let healthFraction = CGFloat(enemy.health) / CGFloat(enemy.maxHealth)
        let barWidth = cellSize * 0.8
        let bodySize = cellSize * 0.52

        return VStack(spacing: 3) {
            // Muted health bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.75, green: 0.75, blue: 0.78))
                    .frame(width: barWidth, height: 4)

                RoundedRectangle(cornerRadius: 3)
                    .fill(healthFraction > 0.5
                        ? Color(red: 0.42, green: 0.68, blue: 0.48)
                        : healthFraction > 0.25
                            ? Color(red: 0.75, green: 0.65, blue: 0.35)
                            : Color(red: 0.72, green: 0.38, blue: 0.38))
                    .frame(width: barWidth * healthFraction, height: 4)
            }

            // Neumorphic enemy body
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: bodySize, height: bodySize)
                    .shadow(color: Color.white.opacity(0.85), radius: 3, x: -2, y: -2)
                    .shadow(color: Color(red: 0.65, green: 0.65, blue: 0.7).opacity(0.5), radius: 3, x: 2, y: 2)

                Circle()
                    .fill(Color(red: 0.68, green: 0.38, blue: 0.38).opacity(0.75))
                    .frame(width: bodySize * 0.7, height: bodySize * 0.7)

                Image(systemName: "ant.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bodySize * 0.4, height: bodySize * 0.4)
                    .foregroundColor(Color(.systemGray6).opacity(0.85))
            }
        }
    }

    func defenseV3GameOverOverlay() -> some View {
        ZStack {
            Color(.systemGray6).opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(Color(red: 0.55, green: 0.3, blue: 0.3))

                Text("Score: \(score)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))

                Text("SEED: #\(seedInt)  |  Wave \(wave)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))

                Button(action: restartGame) {
                    Text("NEW SEED")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.65))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                }
            }
            .padding(40)
            .neumorphicCard(radius: 24)
        }
    }

    // MARK: - Game Logic

    func buildWaveEnemies(rng: inout DefenseV3LCG) -> [DefenseV3Enemy] {
        let count = wave * 3
        let baseHealth = 50 + wave * 10
        let baseSpeed: CGFloat = 0.5
        var result: [DefenseV3Enemy] = []
        var delay: CGFloat = 0

        for _ in 0..<count {
            // Health variation ±20% seeded
            let healthVariation = 0.8 + rng.nextDouble() * 0.4
            let h = max(10, Int(Double(baseHealth) * healthVariation))

            // Speed variation ±10% seeded
            let speedVariation = CGFloat(0.9 + rng.nextDouble() * 0.2)
            let spd = baseSpeed * speedVariation

            // Spawn delay variation
            let delayVariation = CGFloat(0.6 + rng.nextDouble() * 0.8)
            delay += delayVariation

            result.append(DefenseV3Enemy(
                position: 0,
                health: h,
                maxHealth: h,
                speed: spd,
                spawnDelay: delay,
                spawned: false
            ))
        }
        return result
    }

    func startGame() {
        stopGame()
        loadWave()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { _ in
            gameTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        gameTimer = timer
    }

    func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func loadWave() {
        var rng = DefenseV3LCG(seed: seedInt &* wave &+ wave)
        pendingEnemies = buildWaveEnemies(rng: &rng)
        waveElapsed = 0
        waveCleared = false
    }

    func restartGame() {
        towers = []
        enemies = []
        pendingEnemies = []
        gold = 100
        lives = 10
        wave = 1
        score = 0
        phase = .playing
        waveCleared = false
        nextWaveTimer = 0
        waveElapsed = 0
        seedInt += 1
        loadWave()
        startGame()
    }

    func placeTower(col: Int, row: Int) {
        guard phase == .playing else { return }
        guard row != pathRow else { return }
        guard !towers.contains(where: { $0.col == col && $0.row == row }) else { return }
        guard gold >= 10 else { return }
        towers.append(DefenseV3Tower(col: col, row: row))
        gold -= 10
    }

    func gameTick() {
        guard phase == .playing else { return }
        let dt: CGFloat = 1.0 / 30.0
        waveElapsed += dt

        // Spawn enemies based on seeded delay schedule
        var indicesToSpawn: [Int] = []
        for i in pendingEnemies.indices {
            if !pendingEnemies[i].spawned && waveElapsed >= pendingEnemies[i].spawnDelay {
                indicesToSpawn.append(i)
            }
        }
        for i in indicesToSpawn {
            pendingEnemies[i].spawned = true
            enemies.append(pendingEnemies[i])
        }

        // Move enemies
        var reachedEnd: [UUID] = []
        for i in enemies.indices {
            enemies[i].position += enemies[i].speed * dt
            if enemies[i].position >= CGFloat(columns) + 1 {
                reachedEnd.append(enemies[i].id)
            }
        }
        for eid in reachedEnd {
            enemies.removeAll(where: { $0.id == eid })
            lives -= 1
            if lives <= 0 {
                lives = 0
                phase = .gameOver
                stopGame()
                return
            }
        }

        // Towers attack
        for tower in towers {
            let tCX = CGFloat(tower.col) + 0.5
            let tCY = CGFloat(tower.row) + 0.5
            let pCY = CGFloat(pathRow) + 0.5
            var nearestIdx: Int? = nil
            var nearestDist: CGFloat = .infinity
            for i in enemies.indices {
                let dx = enemies[i].position - tCX
                let dy = pCY - tCY
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= tower.range && dist < nearestDist {
                    nearestDist = dist
                    nearestIdx = i
                }
            }
            if let idx = nearestIdx {
                enemies[idx].health -= tower.damage
            }
        }

        // Remove dead
        let dead = enemies.filter { $0.health <= 0 }.count
        if dead > 0 {
            enemies.removeAll(where: { $0.health <= 0 })
            gold += dead * 5
            score += dead * 10
        }

        // Wave cleared
        let allSpawned = pendingEnemies.allSatisfy { $0.spawned }
        if allSpawned && enemies.isEmpty && !waveCleared {
            waveCleared = true
            nextWaveTimer = 0
        }

        if waveCleared {
            nextWaveTimer += dt
            if nextWaveTimer >= 3.0 {
                wave += 1
                loadWave()
            }
        }
    }
}

#Preview {
    DefenseViewV3()
}
