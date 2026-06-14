import SwiftUI

// MARK: - LCG Random

struct NFLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

enum NFV3GamePhase {
    case start, playing, gameOver
}

struct NFV3FallingNumber: Identifiable {
    let id = UUID()
    var value: Int
    var column: Int
    var row: Double
}

struct NFV3StackEntry {
    var value: Int
    var correct: Bool
}

// MARK: - V3 View (Neumorphism + Seeded Procedural)

struct NumberFlowViewV3: View {
    private let columns = 9
    private let tickInterval = 0.05

    @State private var phase: NFV3GamePhase = .start
    @State private var score: Int = 0
    @State private var highScore: Int = 0
    @State private var timeLeft: Double = 30
    @State private var speed: Double = 0.008
    @State private var falling: NFV3FallingNumber? = nil
    @State private var stacks: [[NFV3StackEntry]] = Array(repeating: [], count: 9)
    @State private var timer: Timer? = nil
    @State private var expectedValue: Int = 1
    @State private var seedInt: Int = 1
    @State private var rng: NFLCG = NFLCG(seed: 1)
    @State private var missCount: Int = 0
    @State private var streak: Int = 0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("NUMBER FLOW")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
                Text("Procedural Edition")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(.secondaryLabel))
            }
            VStack(spacing: 6) {
                Text("Guide each falling number\nto its correct column (1–9)!")
                    .font(.system(size: 13, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.secondaryLabel))
                if highScore > 0 {
                    Text("Best: \(highScore)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))
                    .frame(width: 140, height: 50)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 22)
        .padding(28)
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(Color(.label))
            VStack(spacing: 4) {
                Text("Score")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(.secondaryLabel))
                Text("\(score)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
                if score >= highScore && score > 0 {
                    Text("NEW BEST!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            VStack(spacing: 4) {
                Text("Hits: \(score / 10)   Misses: \(missCount)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(.secondaryLabel))
            }
            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))
                    .frame(width: 160, height: 48)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 22)
        .padding(28)
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            // HUD
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.secondaryLabel))
                    Text("\(score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                    if streak > 1 {
                        Text("🔥 \(streak) streak")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(.secondaryLabel))
                    Text(String(format: "%.0f", timeLeft))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(timeLeft < 10 ? .red : Color(.label))
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .neumorphicCard(radius: 0)

            // Play field
            GeometryReader { geo in
                let colW = geo.size.width / CGFloat(columns)
                ZStack {
                    // Column backgrounds
                    ForEach(0..<columns, id: \.self) { col in
                        Rectangle()
                            .fill(col % 2 == 0 ? Color(.systemGray5) : Color(.systemGray6))
                            .frame(width: colW)
                            .frame(maxHeight: .infinity)
                            .offset(x: colW * CGFloat(col) - geo.size.width / 2 + colW / 2)
                        // Column label
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: colW - 6, height: colW - 6)
                                Text("\(col + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            .padding(.top, 6)
                            Spacer()
                        }
                        .offset(x: colW * CGFloat(col) - geo.size.width / 2 + colW / 2)
                    }

                    // Stacks
                    ForEach(0..<columns, id: \.self) { col in
                        ForEach(0..<stacks[col].count, id: \.self) { idx in
                            let entry = stacks[col][idx]
                            let x = colW * CGFloat(col) + colW / 2
                            let y = geo.size.height - CGFloat(idx) * 24 - 14
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(entry.correct ? Color.green.opacity(0.18) : Color.red.opacity(0.15))
                                    .frame(width: colW - 5, height: 20)
                                Text("\(entry.value)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(entry.correct ? .green : .red)
                            }
                            .position(x: x, y: y)
                        }
                    }

                    // Falling
                    if let f = falling {
                        let fx = colW * CGFloat(f.column) + colW / 2
                        let fy = geo.size.height * CGFloat(f.row)
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                                .frame(width: colW - 4, height: 30)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 3, y: 3)
                                .shadow(color: .white.opacity(0.8), radius: 4, x: -3, y: -3)
                            Text("\(f.value)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .position(x: fx, y: fy)
                    }
                }
            }

            // Controls
            HStack(spacing: 16) {
                Button(action: moveLeft) {
                    Text("◀")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(.label))
                        .frame(width: 100, height: 54)
                        .neumorphicCard(radius: 16)
                }
                Button(action: moveRight) {
                    Text("▶")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(.label))
                        .frame(width: 100, height: 54)
                        .neumorphicCard(radius: 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0
        timeLeft = 30
        speed = 0.008
        stacks = Array(repeating: [], count: columns)
        falling = nil
        expectedValue = 1
        missCount = 0
        streak = 0
        seedInt += 1
        rng = NFLCG(seed: seedInt)
        phase = .playing
        startTimer()
        spawnFallingNumber()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            tick()
        }
    }

    func spawnFallingNumber() {
        guard phase == .playing else { return }
        // Use LCG for seeded randomness
        let val = rng.nextInt(9) + 1
        let col = rng.nextInt(columns)
        falling = NFV3FallingNumber(value: val, column: col, row: 0.02)
    }

    func tick() {
        guard phase == .playing else { return }
        timeLeft -= tickInterval
        if timeLeft <= 0 {
            endGame(); return
        }
        speed = 0.008 + (30 - timeLeft) * 0.0005

        if var f = falling {
            f.row += speed
            if f.row >= 1.0 {
                land(number: f)
                falling = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    spawnFallingNumber()
                }
            } else {
                falling = f
            }
        }
    }

    func land(number: NFV3FallingNumber) {
        let isCorrect = number.value == expectedValue && number.column == (number.value - 1)
        stacks[number.column].append(NFV3StackEntry(value: number.value, correct: isCorrect))
        if isCorrect {
            streak += 1
            score += 10 + (streak > 2 ? streak * 2 : 0)
            expectedValue = expectedValue % 9 + 1
        } else {
            missCount += 1
            streak = 0
        }
    }

    func moveLeft() {
        guard var f = falling else { return }
        f.column = max(0, f.column - 1)
        falling = f
    }

    func moveRight() {
        guard var f = falling else { return }
        f.column = min(columns - 1, f.column + 1)
        falling = f
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        falling = nil
        if score > highScore { highScore = score }
        phase = .gameOver
    }
}

#Preview { NumberFlowViewV3() }
