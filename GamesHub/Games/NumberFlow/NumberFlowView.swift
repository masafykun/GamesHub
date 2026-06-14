import SwiftUI

// MARK: - Models

enum NFGamePhase {
    case start, playing, gameOver
}

struct NFFallingNumber: Identifiable {
    let id = UUID()
    var value: Int
    var column: Int
    var row: Double // 0.0 (top) to 1.0 (bottom)
}

struct NFStackEntry {
    var value: Int
    var correct: Bool
}

// MARK: - Main View

struct NumberFlowView: View {
    private let columns = 9
    private let tickInterval = 0.05

    @State private var phase: NFGamePhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var speed: Double = 0.008
    @State private var falling: NFFallingNumber? = nil
    @State private var stacks: [[NFStackEntry]] = Array(repeating: [], count: 9)
    @State private var timer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var expectedValue: Int = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("NUMBER FLOW")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
            Text("Tap arrows to guide falling numbers\ninto columns 1-9 in order!")
                .font(.system(size: 14, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundColor(.red)
            Text("Score: \(score)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 36).padding(.vertical, 12)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            // HUD
            HStack {
                Text("Score: \(score)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
                Text(String(format: "Time: %.0f", timeLeft))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(timeLeft < 10 ? .red : .white)
            }
            .padding(.horizontal, 16).padding(.top, 8)

            // Play field
            GeometryReader { geo in
                let colW = geo.size.width / CGFloat(columns)
                ZStack {
                    // Column dividers + labels
                    ForEach(0..<columns, id: \.self) { col in
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: colW - 2)
                            .frame(maxHeight: .infinity)
                            .offset(x: colW * CGFloat(col) - geo.size.width / 2 + colW / 2)
                        VStack {
                            Text("\(col + 1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                            Spacer()
                        }
                        .offset(x: colW * CGFloat(col) - geo.size.width / 2 + colW / 2)
                    }

                    // Stacked numbers
                    ForEach(0..<columns, id: \.self) { col in
                        ForEach(0..<stacks[col].count, id: \.self) { idx in
                            let entry = stacks[col][idx]
                            let x = colW * CGFloat(col) + colW / 2
                            let y = geo.size.height - CGFloat(idx) * 26 - 16
                            Text("\(entry.value)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(entry.correct ? .green : .red)
                                .frame(width: colW - 4, height: 22)
                                .position(x: x, y: y)
                        }
                    }

                    // Falling number
                    if let f = falling {
                        let fx = colW * CGFloat(f.column) + colW / 2
                        let fy = geo.size.height * CGFloat(f.row)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.yellow)
                                .frame(width: colW - 4, height: 26)
                            Text("\(f.value)")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        .position(x: fx, y: fy)
                    }
                }
                .contentShape(Rectangle())
            }

            // Controls
            HStack(spacing: 32) {
                Button(action: moveLeft) {
                    Text("◀")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 60)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: moveRight) {
                    Text("▶")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 60)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        phase = .playing
        startTimers()
    }

    func startTimers() {
        timer?.invalidate()
        spawnTimer?.invalidate()

        spawnFallingNumber()

        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            tick()
        }
    }

    func spawnFallingNumber() {
        guard phase == .playing else { return }
        let val = Int.random(in: 1...9)
        let col = Int.random(in: 0..<columns)
        falling = NFFallingNumber(value: val, column: col, row: 0.02)
    }

    func tick() {
        guard phase == .playing else { return }

        timeLeft -= tickInterval
        if timeLeft <= 0 {
            endGame()
            return
        }

        // Increase speed over time
        speed = 0.008 + (30 - timeLeft) * 0.0004

        if var f = falling {
            f.row += speed
            if f.row >= 1.0 {
                land(number: f)
                falling = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    spawnFallingNumber()
                }
            } else {
                falling = f
            }
        }
    }

    func land(number: NFFallingNumber) {
        let isCorrect = number.value == expectedValue && number.column == (number.value - 1)
        let entry = NFStackEntry(value: number.value, correct: isCorrect)
        stacks[number.column].append(entry)
        if isCorrect {
            score += 10
            expectedValue = expectedValue % 9 + 1
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
        phase = .gameOver
    }
}

#Preview { NumberFlowView() }
