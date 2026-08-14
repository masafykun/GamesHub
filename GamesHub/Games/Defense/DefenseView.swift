import SwiftUI

// MARK: - Models

struct DefenseTower: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var range: CGFloat = 2.0
    var damage: Int = 10
    var fireInterval: CGFloat = 0.4
    var cooldown: CGFloat = 0
}

struct DefenseEnemy: Identifiable {
    let id = UUID()
    var position: CGFloat
    var health: Int
    var maxHealth: Int
    var speed: CGFloat
}

enum DefenseGamePhase {
    case playing, gameOver
}

enum DefenseDifficultyLevel: String {
    case easy = "EASY"
    case normal = "NORMAL"
    case hard = "HARD"
}

// MARK: - Main View

struct DefenseView: View {
    let columns = 8
    let rows = 12
    let pathRow = 5

    @State private var towers: [DefenseTower] = []
    @State private var enemies: [DefenseEnemy] = []
    @State private var gold: Int = 100
    @State private var lives: Int = 10
    @State private var wave: Int = 1
    @State private var score: Int = 0
    @State private var phase: DefenseGamePhase = .playing

    @State private var enemiesSpawnedThisWave: Int = 0
    @State private var waveCleared: Bool = false
    @State private var nextWaveTimer: CGFloat = 0
    @State private var spawnTimer: CGFloat = 0

    // Adaptive difficulty
    @State private var roundScores: [Int] = []
    @State private var currentRoundKills: Int = 0
    @State private var adaptiveSpeedBonus: CGFloat = 0.0
    @State private var adaptiveHealthMultiplier: CGFloat = 1.0

    @State private var gameTimer: Timer? = nil

    var difficultyLevel: DefenseDifficultyLevel {
        let avg = roundScores.isEmpty ? 0 : roundScores.reduce(0, +) / roundScores.count
        if avg > 10 { return .hard }
        if avg > 5  { return .normal }
        return .easy
    }

    var difficultyColor: Color {
        switch difficultyLevel {
        case .easy:   return .green
        case .normal: return .yellow
        case .hard:   return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width / CGFloat(columns), (geo.size.height - 80) / CGFloat(rows))
            let gridWidth = cellSize * CGFloat(columns)
            let gridHeight = cellSize * CGFloat(rows)

            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.15), Color(red: 0.08, green: 0.14, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 8) {
                    // Glassmorphism HUD
                    defenseHUD(gridWidth: gridWidth)

                    // Grid
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<rows, id: \.self) { row in
                            ForEach(0..<columns, id: \.self) { col in
                                defenseCellView(col: col, row: row, cellSize: cellSize)
                                    .position(
                                        x: CGFloat(col) * cellSize + cellSize / 2,
                                        y: CGFloat(row) * cellSize + cellSize / 2
                                    )
                                    .onTapGesture { placeTower(col: col, row: row) }
                            }
                        }

                        ForEach(towers) { tower in
                            defenseTowerView(cellSize: cellSize)
                                .position(
                                    x: CGFloat(tower.col) * cellSize + cellSize / 2,
                                    y: CGFloat(tower.row) * cellSize + cellSize / 2
                                )
                        }

                        ForEach(enemies) { enemy in
                            defenseEnemyView(enemy: enemy, cellSize: cellSize)
                                .position(
                                    x: enemy.position * cellSize,
                                    y: CGFloat(pathRow) * cellSize + cellSize / 2
                                )
                                .animation(.linear(duration: 1.0 / 30.0), value: enemy.position)
                        }
                    }
                    .frame(width: gridWidth, height: gridHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, max(0, (geo.size.width - gridWidth) / 2))
                .padding(.top, 12)

                // Game Over overlay
                if phase == .gameOver {
                    defenseGameOverOverlay()
                }
            }
        }
        .onAppear { startGame() }
        .onDisappear { stopGame() }
    }

    // MARK: - Sub Views

    func defenseHUD(gridWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            defenseStatPill(label: "💰", value: "\(gold)")
            Spacer()
            defenseStatPill(label: "❤️", value: "\(lives)")
            Spacer()
            defenseStatPill(label: "🌊", value: "W\(wave)")
            Spacer()
            defenseStatPill(label: "⭐", value: "\(score)")
            Spacer()
            // Difficulty badge
            Text(difficultyLevel.rawValue)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(difficultyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(difficultyColor.opacity(0.18))
                        .overlay(
                            Capsule().stroke(difficultyColor.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: gridWidth)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    func defenseStatPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 13))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    func defenseCellView(col: Int, row: Int, cellSize: CGFloat) -> some View {
        let isPath = (row == pathRow)
        return RoundedRectangle(cornerRadius: 2)
            .fill(isPath
                ? Color(red: 0.5, green: 0.4, blue: 0.2).opacity(0.7)
                : Color(red: 0.15, green: 0.25, blue: 0.18).opacity(0.8))
            .frame(width: cellSize - 1.5, height: cellSize - 1.5)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(isPath ? 0.08 : 0.04), lineWidth: 0.5)
            )
    }

    func defenseTowerView(cellSize: CGFloat) -> some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(Color(red: 0.1, green: 0.5, blue: 1.0).opacity(0.25))
                .frame(width: cellSize * 0.92, height: cellSize * 0.92)
                .blur(radius: 4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.4, green: 0.75, blue: 1.0), Color(red: 0.1, green: 0.45, blue: 0.85)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: cellSize * 0.5
                    )
                )
                .frame(width: cellSize * 0.76, height: cellSize * 0.76)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: cellSize * 0.76, height: cellSize * 0.76)

            Image(systemName: "plus")
                .resizable()
                .scaledToFit()
                .frame(width: cellSize * 0.32, height: cellSize * 0.32)
                .foregroundColor(.white.opacity(0.9))
        }
    }

    func defenseEnemyView(enemy: DefenseEnemy, cellSize: CGFloat) -> some View {
        let healthFraction = CGFloat(enemy.health) / CGFloat(enemy.maxHealth)
        let barWidth = cellSize * 0.82
        let bodySize = cellSize * 0.54

        return VStack(spacing: 2) {
            // Gradient health bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.55))
                    .frame(width: barWidth, height: 5)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: healthFraction > 0.5
                                ? [Color(red: 0.2, green: 0.9, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.3)]
                                : healthFraction > 0.25
                                    ? [Color.yellow, Color.orange]
                                    : [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 0.8, green: 0.1, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth * healthFraction, height: 5)
            }

            ZStack {
                // Soft shadow / glow
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.3))
                    .frame(width: bodySize + 4, height: bodySize + 4)
                    .blur(radius: 3)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.3, blue: 0.3), Color(red: 0.7, green: 0.1, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: bodySize, height: bodySize)

                Image(systemName: "ant.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bodySize * 0.55, height: bodySize * 0.55)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    func defenseGameOverOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 22) {
                Text("GAME OVER")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Score: \(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Wave \(wave) | \(difficultyLevel.rawValue) difficulty")
                    .font(.system(size: 15))
                    .foregroundColor(difficultyColor)

                Button(action: restartGame) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.5), radius: 10)
                }
            }
            .padding(40)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Game Logic

    func startGame() {
        stopGame()
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

    func restartGame() {
        towers = []
        enemies = []
        gold = 100
        lives = 10
        wave = 1
        score = 0
        phase = .playing
        enemiesSpawnedThisWave = 0
        waveCleared = false
        nextWaveTimer = 0
        spawnTimer = 0
        currentRoundKills = 0
        adaptiveSpeedBonus = 0.0
        adaptiveHealthMultiplier = 1.0
        roundScores = []
        startGame()
    }

    func placeTower(col: Int, row: Int) {
        guard phase == .playing else { return }
        guard row != pathRow else { return }
        guard !towers.contains(where: { $0.col == col && $0.row == row }) else { return }
        guard gold >= 10 else { return }
        towers.append(DefenseTower(col: col, row: row))
        gold -= 10
    }

    func waveEnemyCount() -> Int { wave * 3 }

    func waveEnemyHealth() -> Int {
        Int(CGFloat(50 + wave * 10) * adaptiveHealthMultiplier)
    }

    func waveEnemySpeed() -> CGFloat {
        max(0.3, 0.5 + adaptiveSpeedBonus)
    }

    func updateAdaptiveDifficulty() {
        // Keep last 5 round scores
        roundScores.append(currentRoundKills)
        if roundScores.count > 5 { roundScores.removeFirst() }
        currentRoundKills = 0

        guard roundScores.count >= 2 else { return }
        let avg = CGFloat(roundScores.reduce(0, +)) / CGFloat(roundScores.count)
        let expected = CGFloat(wave * 3)
        let ratio = avg / max(1, expected)

        if ratio > 0.75 {
            // Player doing well: increase difficulty
            adaptiveSpeedBonus = min(adaptiveSpeedBonus + 0.1, 0.8)
            adaptiveHealthMultiplier = min(adaptiveHealthMultiplier * 1.2, 3.0)
        } else if ratio < 0.4 {
            // Player struggling: decrease difficulty
            adaptiveSpeedBonus = max(adaptiveSpeedBonus - 0.1, -0.2)
        }
    }

    func gameTick() {
        guard phase == .playing else { return }
        let dt: CGFloat = 1.0 / 30.0

        let totalEnemies = waveEnemyCount()
        if enemiesSpawnedThisWave < totalEnemies && !waveCleared {
            spawnTimer += dt
            if spawnTimer >= 1.0 {
                spawnTimer = 0
                let h = waveEnemyHealth()
                enemies.append(DefenseEnemy(
                    position: 0,
                    health: h,
                    maxHealth: h,
                    speed: waveEnemySpeed()
                ))
                enemiesSpawnedThisWave += 1
            }
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

        // Towers attack (rate-limited by fire cooldown)
        for t in towers.indices {
            towers[t].cooldown = max(0, towers[t].cooldown - dt)
            guard towers[t].cooldown <= 0 else { continue }

            let tCX = CGFloat(towers[t].col) + 0.5
            let tCY = CGFloat(towers[t].row) + 0.5
            let pCY = CGFloat(pathRow) + 0.5
            var nearestIndex: Int? = nil
            var nearestDist: CGFloat = .infinity
            for i in enemies.indices {
                let dx = enemies[i].position - tCX
                let dy = pCY - tCY
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= towers[t].range && dist < nearestDist {
                    nearestDist = dist
                    nearestIndex = i
                }
            }
            if let idx = nearestIndex {
                enemies[idx].health -= towers[t].damage
                towers[t].cooldown = towers[t].fireInterval
            }
        }

        // Remove dead
        let dead = enemies.filter { $0.health <= 0 }.count
        if dead > 0 {
            enemies.removeAll(where: { $0.health <= 0 })
            gold += dead * 5
            score += dead * 10
            currentRoundKills += dead
        }

        // Wave cleared
        if enemiesSpawnedThisWave >= totalEnemies && enemies.isEmpty && !waveCleared {
            waveCleared = true
            nextWaveTimer = 0
            updateAdaptiveDifficulty()
        }

        if waveCleared {
            nextWaveTimer += dt
            if nextWaveTimer >= 3.0 {
                wave += 1
                enemiesSpawnedThisWave = 0
                waveCleared = false
                spawnTimer = 0
                nextWaveTimer = 0
            }
        }
    }
}

#Preview {
    DefenseView()
}
