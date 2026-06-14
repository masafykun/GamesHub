import SwiftUI

// MARK: - Models

struct DefenseTower: Identifiable {
    let id = UUID()
    var col: Int
    var row: Int
    var range: CGFloat = 2.0
    var damage: Int = 10
}

struct DefenseEnemy: Identifiable {
    let id = UUID()
    var position: CGFloat  // 0...columns, along path row
    var health: Int
    var maxHealth: Int
    var speed: CGFloat
}

// MARK: - Game State

enum DefenseGamePhase {
    case playing, gameOver
}

// MARK: - Main View

struct DefenseView: View {
    // Grid dimensions
    let columns = 8
    let rows = 12
    let pathRow = 5

    // Game state
    @State private var towers: [DefenseTower] = []
    @State private var enemies: [DefenseEnemy] = []
    @State private var gold: Int = 100
    @State private var lives: Int = 10
    @State private var wave: Int = 1
    @State private var score: Int = 0
    @State private var phase: DefenseGamePhase = .playing

    // Wave management
    @State private var enemiesSpawnedThisWave: Int = 0
    @State private var waveCleared: Bool = false
    @State private var nextWaveTimer: CGFloat = 0
    @State private var spawnTimer: CGFloat = 0
    @State private var spawnInterval: CGFloat = 1.0

    // Game loop
    @State private var gameTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width / CGFloat(columns), geo.size.height / CGFloat(rows + 2))
            let gridWidth = cellSize * CGFloat(columns)
            let gridHeight = cellSize * CGFloat(rows)
            let gridOffsetX = (geo.size.width - gridWidth) / 2

            ZStack(alignment: .top) {
                Color(red: 0.12, green: 0.16, blue: 0.12)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // HUD
                    defenseHUD(cellSize: cellSize, gridWidth: gridWidth)
                        .frame(width: gridWidth)
                        .padding(.top, 8)

                    // Grid
                    ZStack(alignment: .topLeading) {
                        // Cells
                        ForEach(0..<rows, id: \.self) { row in
                            ForEach(0..<columns, id: \.self) { col in
                                defenseCellView(col: col, row: row, cellSize: cellSize)
                                    .position(
                                        x: CGFloat(col) * cellSize + cellSize / 2,
                                        y: CGFloat(row) * cellSize + cellSize / 2
                                    )
                                    .onTapGesture {
                                        placeTower(col: col, row: row)
                                    }
                            }
                        }

                        // Towers
                        ForEach(towers) { tower in
                            defenseTowerView(cellSize: cellSize)
                                .position(
                                    x: CGFloat(tower.col) * cellSize + cellSize / 2,
                                    y: CGFloat(tower.row) * cellSize + cellSize / 2
                                )
                        }

                        // Enemies
                        ForEach(enemies) { enemy in
                            defenseEnemyView(enemy: enemy, cellSize: cellSize)
                                .position(
                                    x: enemy.position * cellSize,
                                    y: CGFloat(pathRow) * cellSize + cellSize / 2
                                )
                        }
                    }
                    .frame(width: gridWidth, height: gridHeight)
                    .background(Color(red: 0.1, green: 0.14, blue: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, gridOffsetX > 0 ? gridOffsetX : 0)

                // Game Over overlay
                if phase == .gameOver {
                    defenseGameOverOverlay(gridWidth: gridWidth)
                }
            }
        }
        .onAppear { startGame() }
        .onDisappear { stopGame() }
    }

    // MARK: - Sub Views

    func defenseHUD(cellSize: CGFloat, gridWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            defenseHUDItem(icon: "💰", value: "\(gold)")
            Spacer()
            defenseHUDItem(icon: "❤️", value: "\(lives)")
            Spacer()
            defenseHUDItem(icon: "🌊", value: "W\(wave)")
            Spacer()
            defenseHUDItem(icon: "⭐", value: "\(score)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(red: 0.08, green: 0.12, blue: 0.08))
        .cornerRadius(8)
        .padding(.bottom, 6)
    }

    func defenseHUDItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 14))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    func defenseCellView(col: Int, row: Int, cellSize: CGFloat) -> some View {
        let isPath = (row == pathRow)
        let hasTower = towers.contains(where: { $0.col == col && $0.row == row })

        return ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(isPath
                    ? Color(red: 0.55, green: 0.45, blue: 0.25)
                    : Color(red: 0.18, green: 0.28, blue: 0.18))
                .frame(width: cellSize - 1, height: cellSize - 1)

            if isPath {
                // Path markings
                Rectangle()
                    .fill(Color(red: 0.65, green: 0.55, blue: 0.3).opacity(0.4))
                    .frame(width: cellSize - 1, height: 2)
            }
        }
    }

    func defenseTowerView(cellSize: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.2, green: 0.6, blue: 0.9))
                .frame(width: cellSize * 0.78, height: cellSize * 0.78)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: cellSize * 0.78, height: cellSize * 0.78)

            // Crosshair
            Image(systemName: "plus")
                .resizable()
                .scaledToFit()
                .frame(width: cellSize * 0.35, height: cellSize * 0.35)
                .foregroundColor(.white)
        }
    }

    func defenseEnemyView(enemy: DefenseEnemy, cellSize: CGFloat) -> some View {
        let healthFraction = CGFloat(enemy.health) / CGFloat(enemy.maxHealth)
        let barWidth = cellSize * 0.8
        let bodySize = cellSize * 0.55

        return VStack(spacing: 2) {
            // Health bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: barWidth, height: 5)

                RoundedRectangle(cornerRadius: 2)
                    .fill(healthFraction > 0.5 ? Color.green : healthFraction > 0.25 ? Color.yellow : Color.red)
                    .frame(width: barWidth * healthFraction, height: 5)
            }

            // Enemy body
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.85, green: 0.25, blue: 0.25))
                    .frame(width: bodySize, height: bodySize)

                Image(systemName: "ant.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bodySize * 0.6, height: bodySize * 0.6)
                    .foregroundColor(.white)
            }
        }
    }

    func defenseGameOverOverlay(gridWidth: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.red)

                Text("Score: \(score)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("Wave reached: \(wave)")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)

                Button(action: restartGame) {
                    Text("RESTART")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(12)
                }
            }
            .padding(40)
            .background(Color(red: 0.1, green: 0.1, blue: 0.15))
            .cornerRadius(20)
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
        spawnInterval = 1.0
        startGame()
    }

    func placeTower(col: Int, row: Int) {
        guard phase == .playing else { return }
        guard row != pathRow else { return }
        guard !towers.contains(where: { $0.col == col && $0.row == row }) else { return }
        guard gold >= 10 else { return }

        let tower = DefenseTower(col: col, row: row)
        towers.append(tower)
        gold -= 10
    }

    func waveEnemyCount() -> Int {
        return wave * 3
    }

    func waveEnemyHealth() -> Int {
        return 50 + wave * 10
    }

    func waveEnemySpeed() -> CGFloat {
        return 0.5
    }

    func gameTick() {
        guard phase == .playing else { return }

        let dt: CGFloat = 1.0 / 30.0

        // Spawning
        let totalEnemies = waveEnemyCount()
        if enemiesSpawnedThisWave < totalEnemies && !waveCleared {
            spawnTimer += dt
            if spawnTimer >= spawnInterval {
                spawnTimer = 0
                let h = waveEnemyHealth()
                let enemy = DefenseEnemy(
                    position: 0,
                    health: h,
                    maxHealth: h,
                    speed: waveEnemySpeed()
                )
                enemies.append(enemy)
                enemiesSpawnedThisWave += 1
            }
        }

        // Move enemies
        var enemiesReachedEnd: [UUID] = []
        for i in enemies.indices {
            enemies[i].position += enemies[i].speed * dt
            if enemies[i].position >= CGFloat(columns) + 1 {
                enemiesReachedEnd.append(enemies[i].id)
            }
        }

        // Remove enemies that reached end, lose life
        for eid in enemiesReachedEnd {
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
            let towerCX = CGFloat(tower.col) + 0.5
            let towerCY = CGFloat(tower.row) + 0.5
            let pathCY = CGFloat(pathRow) + 0.5

            // Find nearest enemy in range
            var nearestIndex: Int? = nil
            var nearestDist: CGFloat = .infinity

            for i in enemies.indices {
                let ex = enemies[i].position
                let ey = pathCY
                let dx = ex - towerCX
                let dy = ey - towerCY
                let dist = sqrt(dx * dx + dy * dy)
                if dist <= tower.range && dist < nearestDist {
                    nearestDist = dist
                    nearestIndex = i
                }
            }

            if let idx = nearestIndex {
                enemies[idx].health -= tower.damage
            }
        }

        // Remove dead enemies
        let deadCount = enemies.filter { $0.health <= 0 }.count
        if deadCount > 0 {
            enemies.removeAll(where: { $0.health <= 0 })
            gold += deadCount * 5
            score += deadCount * 10
        }

        // Wave cleared check
        let allSpawned = enemiesSpawnedThisWave >= totalEnemies
        if allSpawned && enemies.isEmpty && !waveCleared {
            waveCleared = true
            nextWaveTimer = 0
        }

        // Next wave countdown
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
