import SwiftUI

// MARK: - LCG Seed Generator

struct WhackLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let count = UInt64(range.count)
        return range.lowerBound + Int(next() % count)
    }
}

// MARK: - Mole State

enum WhackMoleState {
    case hidden
    case visible
    case whacked
}

// MARK: - Main View

struct WhackViewV3: View {

    // Seed
    @State var seedInt: Int = 1

    // Grid
    @State private var moleStates: [WhackMoleState] = Array(repeating: .hidden, count: 9)
    @State private var moleTimers: [Double] = Array(repeating: 0, count: 9)

    // Scoring
    @State private var score: Int = 0
    @State private var timeRemaining: Double = 30

    // Game state
    @State private var isGameOver: Bool = false
    @State private var isPlaying: Bool = false

    // Timers
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil

    // LCG generator
    @State private var lcg: WhackLCG = WhackLCG(seed: 1)

    // Spawn schedule: pre-generated list of (delay, holes) from LCG
    @State private var spawnSchedule: [(delay: Double, holes: [Int])] = []
    @State private var scheduleIndex: Int = 0
    @State private var nextSpawnTime: Double = 0

    // Elapsed time (for spawn scheduling)
    @State private var elapsed: Double = 0

    // Animation feedback
    @State private var whackedScale: [CGFloat] = Array(repeating: 1.0, count: 9)

    private let gameDuration: Double = 30.0
    private let moleVisibleDuration: Double = 1.2
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                // Seed display
                seedView

                // Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<9, id: \.self) { index in
                        ZStack {
                            Ellipse()
                                .fill(Color(.systemGray4))
                                .frame(height: 50).padding(.top, 24)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.6), radius: 4, x: -2, y: -2)
                            if moleStates[index] == .visible || moleStates[index] == .whacked {
                                Circle()
                                    .fill(Color(red: 0.65, green: 0.45, blue: 0.28))
                                    .frame(width: 40, height: 40)
                                    .offset(y: moleStates[index] == .whacked ? -25 : -18)
                                    .scaleEffect(whackedScale[index])
                                    .transition(.move(edge: .bottom))
                            }
                        }
                        .frame(width: 85, height: 85).clipped()
                        .neumorphicCard(radius: 12)
                        .onTapGesture { handleTap(index: index) }
                    }
                }
                .padding(.horizontal, 24)
                .neumorphicCard(radius: 24)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 20)

            // Game Over Overlay
            if isGameOver {
                gameOverOverlay
            }

            // Start Overlay
            if !isPlaying && !isGameOver {
                startOverlay
            }
        }
        .preferredColorScheme(nil)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .neumorphicCard()

            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f", max(0, timeRemaining)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(timeRemaining <= 5 ? .red : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .neumorphicCard()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Seed View

    private var seedView: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 12)
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("WHACK-A-MOLE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("V3 · Procedural")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Tap moles as they appear!\n+10 per whack · -5 per miss")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.subheadline)

                Button(action: startGame) {
                    Text("START")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("FINAL SCORE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(score >= 0 ? .green : .red)
                }
                .padding()
                .neumorphicCard()

                Button(action: restartGame) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.orange.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Game Logic

    private func buildSpawnSchedule(seed: Int) -> [(delay: Double, holes: [Int])] {
        var gen = WhackLCG(seed: seed)
        var schedule: [(delay: Double, holes: [Int])] = []
        var t: Double = 0.5

        while t < gameDuration {
            // Pick 1 or 2 random holes
            let count = gen.nextInt(in: 1..<3)
            var holes: [Int] = []
            var available = Array(0..<9)

            for _ in 0..<count {
                if available.isEmpty { break }
                let pick = gen.nextInt(in: 0..<available.count)
                holes.append(available[pick])
                available.remove(at: pick)
            }

            schedule.append((delay: t, holes: holes))

            // Interval between spawns: 0.8 to 1.6s (derived from LCG)
            let interval = 0.8 + Double(gen.next() % 1000) / 1000.0 * 0.8
            t += interval
        }

        return schedule
    }

    private func startGame() {
        moleStates = Array(repeating: .hidden, count: 9)
        moleTimers = Array(repeating: 0, count: 9)
        whackedScale = Array(repeating: 1.0, count: 9)
        score = 0
        timeRemaining = gameDuration
        elapsed = 0
        isGameOver = false
        isPlaying = true

        lcg = WhackLCG(seed: seedInt)
        spawnSchedule = buildSpawnSchedule(seed: seedInt)
        scheduleIndex = 0
        nextSpawnTime = spawnSchedule.first?.delay ?? Double.infinity

        stopTimers()

        // Main game tick at ~60fps
        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(gameTimer!, forMode: .common)
    }

    private func restartGame() {
        seedInt += 1
        startGame()
    }

    private func stopTimers() {
        gameTimer?.invalidate()
        gameTimer = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    private func tick() {
        let dt = 1.0 / 60.0

        // Decrement game time
        timeRemaining -= dt
        elapsed += dt

        if timeRemaining <= 0 {
            endGame()
            return
        }

        // Spawn moles per schedule
        while scheduleIndex < spawnSchedule.count && elapsed >= spawnSchedule[scheduleIndex].delay {
            let entry = spawnSchedule[scheduleIndex]
            for hole in entry.holes {
                if moleStates[hole] == .hidden {
                    moleStates[hole] = .visible
                    moleTimers[hole] = moleVisibleDuration
                }
            }
            scheduleIndex += 1
        }

        // Tick individual mole timers
        for i in 0..<9 {
            if moleStates[i] == .visible {
                moleTimers[i] -= dt
                if moleTimers[i] <= 0 {
                    // Mole escaped — penalty
                    score -= 5
                    moleStates[i] = .hidden
                    moleTimers[i] = 0
                }
            } else if moleStates[i] == .whacked {
                moleTimers[i] -= dt
                if moleTimers[i] <= 0 {
                    moleStates[i] = .hidden
                    moleTimers[i] = 0
                }
            }
        }
    }

    private func handleTap(index: Int) {
        guard isPlaying else { return }

        if moleStates[index] == .visible {
            score += 10
            moleStates[index] = .whacked
            moleTimers[index] = 0.3
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                whackedScale[index] = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    whackedScale[index] = 1.0
                }
            }
        }
    }

    private func endGame() {
        stopTimers()
        // Hide all moles
        for i in 0..<9 {
            moleStates[i] = .hidden
        }
        isPlaying = false
        isGameOver = true
    }
}

// MARK: - Hole View

// MARK: - Mole Character

