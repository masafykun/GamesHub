import SwiftUI

enum ReactionGamePhase {
    case idle
    case waiting
    case ready
    case tapped
    case results
}

struct ReactionRoundResult: Identifiable {
    let id = UUID()
    let round: Int
    let milliseconds: Int
    let isPenalty: Bool
}

struct ReactionView: View {
    @State private var phase: ReactionGamePhase = .idle
    @State private var currentRound: Int = 0
    @State private var results: [ReactionRoundResult] = []
    @State private var waitTimer: Timer? = nil
    @State private var reactionStartTime: Date? = nil
    @State private var waitDelay: Double = 0
    @State private var earlyTap: Bool = false

    let totalRounds = 5
    let penaltyMs = 500

    var averageMs: Int {
        guard !results.isEmpty else { return 0 }
        let total = results.reduce(0) { $0 + $1.milliseconds }
        return total / results.count
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in handleTap() }
                )

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
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    var backgroundColor: Color {
        switch phase {
        case .ready:
            return Color.green
        case .waiting:
            return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .tapped:
            return earlyTap ? Color.red.opacity(0.8) : Color.blue.opacity(0.7)
        default:
            return Color(red: 0.12, green: 0.12, blue: 0.18)
        }
    }

    var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Reaction Timer")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Tap as fast as possible\nwhen the screen turns green!")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                ReactionInfoRow(icon: "circle.fill", color: .green, text: "Green = tap now!")
                ReactionInfoRow(icon: "exclamationmark.triangle.fill", color: .yellow, text: "Early tap = +500ms penalty")
                ReactionInfoRow(icon: "chart.bar.fill", color: .cyan, text: "5 rounds, lower average wins")
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 32)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer()

            Button(action: startGame) {
                Text("Start Game")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    var gameView: some View {
        VStack(spacing: 24) {
            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<totalRounds, id: \.self) { i in
                    Circle()
                        .fill(i < results.count ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.bottom, 8)

            Text("Round \(currentRound) of \(totalRounds)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            VStack(spacing: 16) {
                if phase == .waiting {
                    Text("Wait...")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Don't tap yet!")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                } else if phase == .ready {
                    Text("TAP!")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                } else if phase == .tapped {
                    if earlyTap {
                        Text("Too early!")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("+\(penaltyMs)ms penalty")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    } else if let last = results.last {
                        Text("\(last.milliseconds)ms")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(reactionLabel(ms: last.milliseconds))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }

            Spacer()

            if phase == .tapped {
                Text(currentRound < totalRounds ? "Tap anywhere to continue" : "Tap to see results")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 48)
            } else {
                Color.clear.frame(height: 64)
            }
        }
    }

    var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Results")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 48)

                ReactionScoreBadge(averageMs: averageMs)

                VStack(spacing: 10) {
                    ForEach(results) { result in
                        ReactionRoundRow(result: result)
                    }
                }
                .padding(.horizontal, 24)

                Text(performanceLabel(ms: averageMs))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)

                Button(action: resetGame) {
                    Text("Play Again")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
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
        waitDelay = Double.random(in: 1.5...4.5)

        waitTimer?.invalidate()
        waitTimer = Timer.scheduledTimer(withTimeInterval: waitDelay, repeats: false) { _ in
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
            // Early tap
            waitTimer?.invalidate()
            waitTimer = nil
            earlyTap = true
            let result = ReactionRoundResult(round: currentRound, milliseconds: penaltyMs, isPenalty: true)
            results.append(result)
            phase = .tapped

        case .ready:
            // Valid tap
            let elapsed = Date().timeIntervalSince(reactionStartTime ?? Date())
            let ms = Int(elapsed * 1000)
            let result = ReactionRoundResult(round: currentRound, milliseconds: ms, isPenalty: false)
            results.append(result)
            phase = .tapped

        case .tapped:
            // Advance to next round or results
            if currentRound < totalRounds {
                startRound()
            } else {
                phase = .results
            }

        case .results:
            resetGame()
        }
    }

    func resetGame() {
        waitTimer?.invalidate()
        waitTimer = nil
        results = []
        currentRound = 0
        phase = .idle
    }

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
}

// MARK: - Subviews

struct ReactionInfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }
}

struct ReactionScoreBadge: View {
    let averageMs: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Average")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
            Text("\(averageMs)ms")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundColor(.green)
            Text("reaction time")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }
}

struct ReactionRoundRow: View {
    let result: ReactionRoundResult

    var body: some View {
        HStack {
            Text("Round \(result.round)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))

            Spacer()

            if result.isPenalty {
                Label("Penalty", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.yellow)
            }

            Text("\(result.milliseconds)ms")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(result.isPenalty ? .yellow : reactionColor(ms: result.milliseconds))
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func reactionColor(ms: Int) -> Color {
        switch ms {
        case ..<200: return .green
        case 200..<300: return .cyan
        case 300..<400: return .orange
        default: return .red
        }
    }
}
