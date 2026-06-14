import SwiftUI

// MARK: - Models

enum NFV2GamePhase {
    case start, playing, gameOver
}

struct NFV2FallingNumber: Identifiable {
    let id = UUID()
    var value: Int
    var column: Int
    var row: Double
}

struct NFV2StackEntry {
    var value: Int
    var correct: Bool
}

// MARK: - V2 View (Glassmorphism + Adaptive Difficulty)

struct NumberFlowViewV2: View {
    private let columns = 9
    private let tickInterval = 0.05

    @State private var phase: NFV2GamePhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var baseSpeed: Double = 0.008
    @State private var speed: Double = 0.008
    @State private var falling: NFV2FallingNumber? = nil
    @State private var stacks: [[NFV2StackEntry]] = Array(repeating: [], count: 9)
    @State private var timer: Timer? = nil
    @State private var expectedValue: Int = 1
    @State private var recentResults: [Bool] = []
    @State private var combo: Int = 0
    @State private var flashGreen: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
            VStack(spacing: 8) {
                Text("NUMBER FLOW")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Adaptive Edition")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Text("Guide falling numbers to their\ncorrect columns in order 1-9!")
                .font(.system(size: 14, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            Button(action: startGame) {
                Text("START GAME")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
            VStack(spacing: 8) {
                Text("Score")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(score)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(36)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            // HUD
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                if combo > 1 {
                    Text("x\(combo)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .transition(.scale)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.0f", timeLeft))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.15)), alignment: .bottom)

            // Field
            GeometryReader { geo in
                let colW = geo.size.width / CGFloat(columns)
                ZStack {
                    ForEach(0..<columns, id: \.self) { col in
                        Rectangle()
                            .fill(Color.white.opacity(col % 2 == 0 ? 0.03 : 0.06))
                            .frame(width: colW)
                            .frame(maxHeight: .infinity)
                            .offset(x: colW * CGFloat(col) - geo.size.width / 2 + colW / 2)
                        VStack {
                            Text("\(col + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.25))
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
                            let y = geo.size.height - CGFloat(idx) * 26 - 14
                            Text("\(entry.value)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(entry.correct ? .green : .red.opacity(0.7))
                                .frame(width: colW - 4, height: 22)
                                .position(x: x, y: y)
                        }
                    }

                    // Falling
                    if let f = falling {
                        let fx = colW * CGFloat(f.column) + colW / 2
                        let fy = geo.size.height * CGFloat(f.row)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.5), lineWidth: 1.5))
                                .frame(width: colW - 4, height: 28)
                            Text("\(f.value)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .position(x: fx, y: fy)
                    }
                }
                .animation(.linear(duration: tickInterval), value: falling?.row)
            }
            .overlay(
                flashGreen ? Color.green.opacity(0.15).ignoresSafeArea() : Color.clear.ignoresSafeArea()
            )

            // Controls
            HStack(spacing: 20) {
                Button(action: moveLeft) {
                    Text("◀")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 90, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                }
                Button(action: moveRight) {
                    Text("▶")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 90, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0
        timeLeft = 30
        baseSpeed = 0.008
        speed = 0.008
        stacks = Array(repeating: [], count: columns)
        falling = nil
        expectedValue = 1
        recentResults = []
        combo = 0
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
        let val = Int.random(in: 1...9)
        let col = Int.random(in: 0..<columns)
        falling = NFV2FallingNumber(value: val, column: col, row: 0.02)
    }

    func tick() {
        guard phase == .playing else { return }
        timeLeft -= tickInterval
        if timeLeft <= 0 {
            endGame(); return
        }
        speed = baseSpeed + (30 - timeLeft) * 0.0003

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

    func land(number: NFV2FallingNumber) {
        let isCorrect = number.value == expectedValue && number.column == (number.value - 1)
        stacks[number.column].append(NFV2StackEntry(value: number.value, correct: isCorrect))

        // Record result
        recentResults.append(isCorrect)
        if recentResults.count > 5 { recentResults.removeFirst() }

        // Adaptive difficulty: if last 5 are >4 correct, increase speed ~20%
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            baseSpeed = min(baseSpeed * 1.20, 0.04)
            recentResults = []
        }

        if isCorrect {
            combo += 1
            score += 10 * combo
            expectedValue = expectedValue % 9 + 1
            withAnimation(.easeOut(duration: 0.2)) { flashGreen = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { flashGreen = false }
        } else {
            combo = 0
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

#Preview { NumberFlowViewV2() }
