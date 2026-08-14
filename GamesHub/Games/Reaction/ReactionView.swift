import SwiftUI

// MARK: - Enums & Models

enum ReactionPhase {
    case idle
    case waiting
    case ready
    case tapped
    case results
}

enum ReactionDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard:   return "bolt.fill"
        }
    }

    /// Wait-time range in seconds. Harder = tighter, shorter window = harder to predict.
    var waitRange: ClosedRange<Double> {
        switch self {
        case .easy:   return 2.0...5.0
        case .medium: return 1.2...4.0
        case .hard:   return 0.6...2.8
        }
    }
}

struct ReactionRoundResult: Identifiable {
    let id = UUID()
    let round: Int
    let milliseconds: Int
    let isPenalty: Bool
}

// MARK: - Main View

struct ReactionView: View {
    // Persistent cross-game tracking (adaptive difficulty)
    @State var roundScores: [Int] = []
    @AppStorage("reactionBestMs") private var bestMs: Int = 0

    // Current game state
    @State private var phase: ReactionPhase = .idle
    @State private var currentRound: Int = 0
    @State private var results: [ReactionRoundResult] = []
    @State private var waitTimer: Timer? = nil
    @State private var reactionStartTime: Date? = nil
    @State private var earlyTap: Bool = false
    @State private var difficulty: ReactionDifficulty = .medium
    @State private var showDifficultyBadge: Bool = false

    let totalRounds = 5
    let penaltyMs = 500

    var averageMs: Int {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.milliseconds } / results.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Animated background gradient
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: phase)

            // Tap target layer
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in handleTap() }
                )

            // Content
            VStack(spacing: 0) {
                switch phase {
                case .idle:
                    idleView
                case .results:
                    resultsView
                default:
                    gameView
                }
            }

            // Floating difficulty badge (top-right)
            if phase != .idle {
                VStack {
                    HStack {
                        Spacer()
                        difficultyBadge
                            .padding(.top, 56)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var backgroundColors: [Color] {
        switch phase {
        case .ready:
            return [Color(red: 0.1, green: 0.55, blue: 0.2), Color(red: 0.05, green: 0.35, blue: 0.1)]
        case .waiting:
            return [Color(red: 0.08, green: 0.08, blue: 0.18), Color(red: 0.12, green: 0.10, blue: 0.22)]
        case .tapped:
            return earlyTap
                ? [Color(red: 0.45, green: 0.05, blue: 0.05), Color(red: 0.25, green: 0.05, blue: 0.05)]
                : [Color(red: 0.05, green: 0.18, blue: 0.42), Color(red: 0.08, green: 0.10, blue: 0.28)]
        case .results:
            return [Color(red: 0.06, green: 0.06, blue: 0.16), Color(red: 0.10, green: 0.08, blue: 0.22)]
        default:
            return [Color(red: 0.07, green: 0.07, blue: 0.17), Color(red: 0.11, green: 0.09, blue: 0.21)]
        }
    }

    // MARK: - Difficulty Badge

    var difficultyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 11, weight: .bold))
            Text(difficulty.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(difficulty.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(difficulty.color.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Idle View

    var idleView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Title glass card
            VStack(spacing: 12) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)

                Text("Reaction Timer")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(bestMs > 0 ? "Best: \(bestMs) ms" : "Tap the moment the screen turns green")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Info card
            VStack(spacing: 14) {
                ReactionInfoRow(icon: "circle.fill", color: .green,  text: "Green screen = tap now!")
                ReactionInfoRow(icon: "exclamationmark.triangle.fill", color: .yellow, text: "Early tap = +500ms penalty")
                ReactionInfoRow(icon: "chart.line.uptrend.xyaxis", color: .cyan,   text: "5 rounds — lower average wins")
                ReactionInfoRow(icon: difficulty.icon, color: difficulty.color, text: "Difficulty adapts to your skill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Current difficulty display
            if !roundScores.isEmpty {
                VStack(spacing: 4) {
                    Text("Current difficulty")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    HStack(spacing: 6) {
                        Image(systemName: difficulty.icon)
                            .font(.system(size: 13))
                        Text(difficulty.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(difficulty.color)

                    if roundScores.count >= 1 {
                        Text("Moving avg: \(movingAverage)ms")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.40))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(difficulty.color.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
            }

            Spacer()

            Button(action: startGame) {
                Text("Start Game")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.green.opacity(0.45), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Game View

    var gameView: some View {
        VStack(spacing: 0) {
            // Round progress bar
            roundProgressBar
                .padding(.top, 60)
                .padding(.horizontal, 24)

            Spacer()

            // Central feedback
            centralFeedback

            Spacer()

            // Bottom hint
            bottomHint
                .padding(.bottom, 52)
        }
    }

    var roundProgressBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Round \(currentRound) of \(totalRounds)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if results.count > 0 {
                    Text("Avg \(runningAverage)ms")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Pip progress
            HStack(spacing: 8) {
                ForEach(0..<totalRounds, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i < results.count ? Color.white : Color.white.opacity(0.2))
                        .frame(height: 4)
                        .animation(.easeInOut, value: results.count)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var centralFeedback: some View {
        VStack(spacing: 20) {
            switch phase {
            case .waiting:
                VStack(spacing: 16) {
                    Text("Wait...")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    Text("Don't tap yet!")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))

                    // Animated pulsing indicator
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                        )
                }

            case .ready:
                VStack(spacing: 12) {
                    Text("TAP!")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                    Text("Now!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }

            case .tapped:
                tappedFeedback

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    var tappedFeedback: some View {
        VStack(spacing: 14) {
            if earlyTap {
                Image(systemName: "hand.raised.slash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red.opacity(0.9))

                Text("Too Early!")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("+\(penaltyMs)ms penalty")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Capsule())
            } else if let last = results.last {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green.opacity(0.9))

                Text("\(last.milliseconds)ms")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(reactionLabel(ms: last.milliseconds))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(reactionColor(ms: last.milliseconds).opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }

    var bottomHint: some View {
        Group {
            if phase == .tapped {
                Text(currentRound < totalRounds ? "Tap anywhere to continue" : "Tap to see results")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(height: 40)
            }
        }
    }

    // MARK: - Results View

    var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Results")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Game Complete")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                }
                .padding(.top, 52)

                // Score glass card
                resultScoreCard

                // Adaptive difficulty banner
                adaptiveDifficultyBanner

                // Round list
                VStack(spacing: 8) {
                    ForEach(results) { result in
                        ReactionRoundRow(result: result)
                    }
                }
                .padding(.horizontal, 20)

                // Performance label
                Text(performanceLabel(ms: averageMs))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                // Play again
                Button(action: resetGame) {
                    Text("Play Again")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.green.opacity(0.45), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    var resultScoreCard: some View {
        VStack(spacing: 10) {
            Text("Average Reaction Time")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.2)

            Text("\(averageMs)ms")
                .font(.system(size: 62, weight: .black, design: .rounded))
                .foregroundColor(.green)
                .shadow(color: Color.green.opacity(0.4), radius: 10, x: 0, y: 4)

            Text(reactionLabel(ms: averageMs))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            // Mini bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(results) { result in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(result.isPenalty ? Color.red.opacity(0.7) : reactionColor(ms: result.milliseconds))
                            .frame(width: 30, height: barHeight(ms: result.milliseconds))
                        Text("R\(result.round)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    var adaptiveDifficultyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 18))
                .foregroundColor(difficulty.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Next difficulty: \(difficulty.rawValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(difficultyExplainer)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            difficultyBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(difficulty.color.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Computed Helpers

    var runningAverage: Int {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.milliseconds } / results.count
    }

    var movingAverage: Int {
        guard !roundScores.isEmpty else { return 0 }
        return roundScores.reduce(0, +) / roundScores.count
    }

    var difficultyExplainer: String {
        switch difficulty {
        case .easy:   return "Wide wait window — easier to predict"
        case .medium: return "Balanced wait window"
        case .hard:   return "Tight, unpredictable wait window"
        }
    }

    // MARK: - Game Logic

    func startGame() {
        results = []
        currentRound = 0
        startRound()
    }

    func startRound() {
        earlyTap = false
        reactionStartTime = nil
        currentRound += 1
        phase = .waiting

        // Adaptive wait delay: use difficulty's range
        let range = difficulty.waitRange
        let delay = Double.random(in: range)

        waitTimer?.invalidate()
        waitTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DispatchQueue.main.async {
                guard self.phase == .waiting else { return }
                self.phase = .ready
                self.reactionStartTime = Date()
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
            let result = ReactionRoundResult(round: currentRound, milliseconds: penaltyMs, isPenalty: true)
            results.append(result)
            phase = .tapped

        case .ready:
            let elapsed = Date().timeIntervalSince(reactionStartTime ?? Date())
            let ms = max(1, Int(elapsed * 1000))
            let result = ReactionRoundResult(round: currentRound, milliseconds: ms, isPenalty: false)
            results.append(result)
            if bestMs == 0 || ms < bestMs { bestMs = ms }
            phase = .tapped

        case .tapped:
            if currentRound < totalRounds {
                startRound()
            } else {
                finalizeGame()
            }

        case .results:
            resetGame()
        }
    }

    func finalizeGame() {
        // Append score, keep last 5, compute moving average, adjust difficulty
        roundScores.append(averageMs)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }

        // Compute moving average over stored game scores
        let avg = movingAverage

        // Adaptive difficulty rules:
        // Improving (avg < 220ms) → Hard
        // Average (220..320ms)   → Medium
        // Struggling (> 320ms)   → Easy
        if roundScores.count >= 2 {
            if avg < 220 {
                difficulty = .hard
            } else if avg < 320 {
                difficulty = .medium
            } else {
                difficulty = .easy
            }
        }

        phase = .results
    }

    func resetGame() {
        waitTimer?.invalidate()
        waitTimer = nil
        results = []
        currentRound = 0
        phase = .idle
    }

    // MARK: - Label Helpers

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
        default: return "There's room to improve — try again!"
        }
    }

    func reactionColor(ms: Int) -> Color {
        switch ms {
        case ..<200: return .green
        case 200..<300: return .cyan
        case 300..<400: return .orange
        default: return .red
        }
    }

    func barHeight(ms: Int) -> CGFloat {
        // Clamp ms to a visible bar range (50–600ms → 8–56pt)
        let clamped = min(max(ms, 50), 600)
        let ratio = Double(clamped - 50) / Double(600 - 50)
        return CGFloat(8 + ratio * 48)
    }
}

// MARK: - Sub-views

struct ReactionInfoRow: View {
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
                .foregroundColor(.white.opacity(0.82))
            Spacer()
        }
    }
}

struct ReactionRoundRow: View {
    let result: ReactionRoundResult

    var body: some View {
        HStack(spacing: 12) {
            // Round number bubble
            Text("\(result.round)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())

            Text("Round \(result.round)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            Spacer()

            if result.isPenalty {
                Label("Penalty", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("\(result.milliseconds)ms")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(result.isPenalty ? .yellow : rowColor(ms: result.milliseconds))
                .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    func rowColor(ms: Int) -> Color {
        switch ms {
        case ..<200: return .green
        case 200..<300: return .cyan
        case 300..<400: return .orange
        default: return .red
        }
    }
}
