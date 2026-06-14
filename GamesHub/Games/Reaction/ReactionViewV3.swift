import SwiftUI

// MARK: - Phase

enum ReactionV3Phase {
    case idle
    case waiting
    case ready
    case tapped
    case results
}

// MARK: - Round Result

struct ReactionV3RoundResult: Identifiable {
    let id = UUID()
    let round: Int
    let milliseconds: Int
    let isPenalty: Bool
}

// MARK: - LCG Helper

struct ReactionV3LCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let normalized = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Main View

struct ReactionViewV3: View {
    @State private var phase: ReactionV3Phase = .idle
    @State private var currentRound: Int = 0
    @State private var results: [ReactionV3RoundResult] = []
    @State private var waitTimer: Timer? = nil
    @State private var reactionStartTime: Date? = nil
    @State private var earlyTap: Bool = false
    @State private var seedInt: Int = 1
    @State private var waitDelays: [Double] = []

    let totalRounds = 5
    let penaltyMs = 500

    var averageMs: Int {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.milliseconds } / results.count
    }

    var backgroundColor: Color {
        switch phase {
        case .ready:
            return Color.green
        case .waiting:
            return Color(.systemGray6)
        case .tapped:
            return earlyTap ? Color.red.opacity(0.15) : Color.blue.opacity(0.08)
        default:
            return Color(.systemGray6)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: phase)

            if phase != .idle && phase != .results {
                VStack {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.5))
                        .padding(.top, 8)
                    Spacer()
                }
            }

            VStack(spacing: 0) {
                if phase == .idle {
                    idleView
                } else if phase == .results {
                    resultsView
                } else {
                    gameView
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in handleTap() }
        )
    }

    // MARK: - Idle View

    var idleView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 48)

                VStack(spacing: 6) {
                    Text("Reaction Timer")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("V3 — Seeded Timing")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("Each seed produces the same wait sequence")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .neumorphicCard(radius: 20)
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ReactionV3InfoRow(icon: "circle.fill", color: .green, text: "Green screen = tap now!")
                    ReactionV3InfoRow(icon: "exclamationmark.triangle.fill", color: .orange, text: "Early tap = +500ms penalty")
                    ReactionV3InfoRow(icon: "chart.bar.fill", color: .blue, text: "5 rounds, lower average wins")
                    ReactionV3InfoRow(icon: "number", color: .purple, text: "Same seed = same wait times")
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .neumorphicCard(radius: 20)
                .padding(.horizontal, 24)

                HStack(spacing: 14) {
                    Button(action: {
                        if seedInt > 1 { seedInt -= 1 }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .neumorphicCard(radius: 14)
                    }

                    VStack(spacing: 4) {
                        Text("Seed")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("#\(seedInt)")
                            .font(.system(size: 28, weight: .heavy, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .neumorphicCard(radius: 14)

                    Button(action: { seedInt += 1 }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .neumorphicCard(radius: 14)
                    }
                }
                .padding(.horizontal, 24)

                Button(action: startGame) {
                    Text("Start Game")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Game View

    var gameView: some View {
        VStack(spacing: 0) {
            // Seed badge always visible
            HStack {
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)
                    .padding(.trailing, 20)
                    .padding(.top, 16)
            }

            Spacer()

            // Round dots
            HStack(spacing: 10) {
                ForEach(0..<totalRounds, id: \.self) { i in
                    Circle()
                        .fill(i < results.count ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }

            Text("Round \(currentRound) of \(totalRounds)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 12)

            Spacer()

            // Main game content
            VStack(spacing: 16) {
                if phase == .waiting {
                    Text("Wait...")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Don't tap yet!")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else if phase == .ready {
                    Text("TAP!")
                        .font(.system(size: 80, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                } else if phase == .tapped {
                    if earlyTap {
                        Text("Too Early!")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                        Text("+\(penaltyMs)ms penalty")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    } else if let last = results.last {
                        Text("\(last.milliseconds)ms")
                            .font(.system(size: 68, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text(reactionLabel(ms: last.milliseconds))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 24)

            Spacer()

            if phase == .tapped {
                Text(currentRound < totalRounds ? "Tap anywhere to continue" : "Tap to see results")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            } else {
                Color.clear.frame(height: 56)
            }
        }
    }

    // MARK: - Results View

    var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 40)

                Text("Results")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Seed badge on results screen
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .neumorphicCard(radius: 12)

                // Average score card
                VStack(spacing: 8) {
                    Text("Average")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(averageMs)ms")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text(reactionLabel(ms: averageMs))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .neumorphicCard(radius: 22)
                .padding(.horizontal, 24)

                // Round rows
                VStack(spacing: 10) {
                    ForEach(results) { result in
                        ReactionV3RoundRow(result: result)
                    }
                }
                .padding(.horizontal, 24)

                Text(performanceLabel(ms: averageMs))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Play again — increments seed
                Button(action: playAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold))
                        Text("Play Again (Seed #\(seedInt + 1))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.green.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)

                Button(action: resetToIdle) {
                    Text("Change Seed")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Game Logic

    func generateWaitDelays() {
        var lcg = ReactionV3LCG(seed: seedInt)
        waitDelays = (0..<totalRounds).map { _ in lcg.nextDouble(in: 1.5...4.5) }
    }

    func startGame() {
        generateWaitDelays()
        results = []
        currentRound = 0
        startRound()
    }

    func playAgain() {
        seedInt += 1
        startGame()
    }

    func resetToIdle() {
        waitTimer?.invalidate()
        waitTimer = nil
        results = []
        currentRound = 0
        phase = .idle
    }

    func startRound() {
        earlyTap = false
        reactionStartTime = nil
        currentRound += 1
        phase = .waiting

        let delay = waitDelays[currentRound - 1]

        waitTimer?.invalidate()
        waitTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.phase == .waiting {
                    self.phase = .ready
                    self.reactionStartTime = Date()
                }
            }
        }
    }

    func handleTap() {
        switch phase {
        case .idle:
            break

        case .waiting:
            waitTimer?.invalidate()
            waitTimer = nil
            earlyTap = true
            results.append(ReactionV3RoundResult(round: currentRound, milliseconds: penaltyMs, isPenalty: true))
            phase = .tapped

        case .ready:
            let elapsed = Date().timeIntervalSince(reactionStartTime ?? Date())
            let ms = max(1, Int(elapsed * 1000))
            results.append(ReactionV3RoundResult(round: currentRound, milliseconds: ms, isPenalty: false))
            phase = .tapped

        case .tapped:
            if currentRound < totalRounds {
                startRound()
            } else {
                phase = .results
            }

        case .results:
            playAgain()
        }
    }

    // MARK: - Labels

    func reactionLabel(ms: Int) -> String {
        switch ms {
        case ..<150: return "Superhuman!"
        case 150..<200: return "Excellent!"
        case 200..<250: return "Great!"
        case 250..<300: return "Good"
        case 300..<400: return "Average"
        default: return "Keep practicing"
        }
    }

    func performanceLabel(ms: Int) -> String {
        switch ms {
        case ..<150: return "Incredible reflexes — are you even human?"
        case 150..<200: return "Elite reaction time — top tier!"
        case 200..<250: return "Above average — well done!"
        case 250..<300: return "Average human reaction time."
        case 300..<400: return "A bit slow — keep practicing!"
        default: return "There is room to improve — try again!"
        }
    }
}

// MARK: - Subviews

struct ReactionV3InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
            Spacer()
        }
    }
}

struct ReactionV3RoundRow: View {
    let result: ReactionV3RoundResult

    var body: some View {
        HStack {
            Text("Round \(result.round)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            if result.isPenalty {
                Label("Penalty", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.orange)
            }

            Text("\(result.milliseconds)ms")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(result.isPenalty ? .orange : reactionColor(ms: result.milliseconds))
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .neumorphicCard(radius: 12)
    }

    func reactionColor(ms: Int) -> Color {
        switch ms {
        case ..<200: return .green
        case 200..<300: return .blue
        case 300..<400: return .orange
        default: return .red
        }
    }
}
