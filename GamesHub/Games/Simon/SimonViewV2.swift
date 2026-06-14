import SwiftUI

// MARK: - Enums & Models

enum SimonPhase {
    case idle, showing, playerTurn, gameOver
}

enum SimonDifficulty: String {
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

    /// Duration (seconds) each button is lit during the sequence playback.
    var flashDuration: Double {
        switch self {
        case .easy:   return 0.7
        case .medium: return 0.5
        case .hard:   return 0.35
        }
    }

    /// Pause between flashes.
    var pauseDuration: Double {
        switch self {
        case .easy:   return 0.25
        case .medium: return 0.18
        case .hard:   return 0.12
        }
    }
}

// MARK: - Main View

struct SimonViewV2: View {

    // MARK: Game state
    @State private var sequence: [SimonColor] = []
    @State private var playerIndex: Int = 0
    @State private var phase: SimonPhase = .idle
    @State private var litButton: SimonColor? = nil
    @State private var score: Int = 0
    @State private var highScore: Int = 0

    // MARK: Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var difficulty: SimonDifficulty = .easy

    // MARK: Animation helpers
    @State private var showingIndex: Int = 0
    @State private var wrongFlash: Bool = false
    @State private var correctPulse: Bool = false
    @State private var gameOverScale: CGFloat = 0.6
    @State private var gameOverOpacity: Double = 0

    // MARK: Timer
    @State private var sequenceTimer: Timer? = nil

    // MARK: Layout
    private let buttonSize: CGFloat = 130

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 24) {
                headerSection
                scoreSection
                Spacer(minLength: 8)
                gridSection
                Spacer(minLength: 8)
                statusSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 36)

            if phase == .gameOver {
                gameOverOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.14),
                Color(red: 0.09, green: 0.10, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Simon Says")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("V2 · Adaptive")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            difficultyBadge
        }
    }

    private var difficultyBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 80, height: 34)
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(difficulty.color)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(difficulty.color.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        HStack(spacing: 16) {
            scoreCard(title: "Round", value: max(score, 0))
            scoreCard(title: "Best",  value: highScore)
            lengthCard
        }
    }

    private func scoreCard(title: String, value: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }

    private var lengthCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
            VStack(spacing: 4) {
                Text("\(sequence.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Length")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }

    // MARK: - Button Grid

    private var gridSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                simonButton(.red)
                simonButton(.blue)
            }
            HStack(spacing: 14) {
                simonButton(.green)
                simonButton(.yellow)
            }
        }
        .scaleEffect(wrongFlash ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.08), value: wrongFlash)
    }

    private func simonButton(_ simonColor: SimonColor) -> some View {
        let isLit = litButton == simonColor
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(isLit ? simonColor.brightColor : simonColor.color.opacity(0.55))
                .shadow(
                    color: isLit ? simonColor.brightColor.opacity(0.75) : .clear,
                    radius: isLit ? 22 : 0
                )

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isLit ? 0.35 : 0.12),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(simonColor.label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(isLit ? 1.0 : 0.6))
        }
        .frame(width: buttonSize, height: buttonSize)
        .scaleEffect(isLit ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isLit)
        .onTapGesture {
            handlePlayerTap(simonColor)
        }
        .disabled(phase != .playerTurn)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .frame(height: 56)

            if phase == .idle {
                Button(action: startGame) {
                    Text("Start Game")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            } else if phase == .showing {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                    Text("Watch the sequence…")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
            } else if phase == .playerTurn {
                HStack(spacing: 8) {
                    ForEach(0..<sequence.count, id: \.self) { idx in
                        Circle()
                            .fill(idx < playerIndex ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { /* consume */ }

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.5), radius: 30)

                VStack(spacing: 20) {
                    Text("Game Over")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    VStack(spacing: 6) {
                        Text("Score: \(score)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Best: \(highScore)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    movingAverageView

                    Button(action: resetGame) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.35, green: 0.55, blue: 1.0),
                                                 Color(red: 0.20, green: 0.38, blue: 0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 50)
                            Text("Play Again")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(32)
            }
            .frame(width: 300)
            .scaleEffect(gameOverScale)
            .opacity(gameOverOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    gameOverScale = 1.0
                    gameOverOpacity = 1.0
                }
            }
        }
    }

    private var movingAverageView: some View {
        let avg = movingAverage()
        return VStack(spacing: 6) {
            Text("Recent Avg: \(avg > 0 ? String(format: "%.1f", avg) : "—")")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 6) {
                Text("Difficulty:")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Text(difficulty.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(difficulty.color)
            }
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        sequence = []
        playerIndex = 0
        score = 0
        phase = .showing
        addStep()
    }

    private func resetGame() {
        gameOverScale = 0.6
        gameOverOpacity = 0
        phase = .idle
    }

    private func addStep() {
        let next = SimonColor.allCases.randomElement()!
        sequence.append(next)
        playerIndex = 0
        playSequence()
    }

    private func playSequence() {
        phase = .showing
        showingIndex = 0
        litButton = nil
        scheduleNextFlash()
    }

    private func scheduleNextFlash() {
        guard showingIndex < sequence.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                litButton = nil
                phase = .playerTurn
            }
            return
        }

        let color = sequence[showingIndex]
        let flash = difficulty.flashDuration
        let pause = difficulty.pauseDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
            litButton = color
            DispatchQueue.main.asyncAfter(deadline: .now() + flash) {
                litButton = nil
                showingIndex += 1
                scheduleNextFlash()
            }
        }
    }

    private func handlePlayerTap(_ tapped: SimonColor) {
        guard phase == .playerTurn else { return }

        let expected = sequence[playerIndex]

        if tapped == expected {
            // Briefly light the tapped button
            litButton = tapped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                litButton = nil
            }

            playerIndex += 1

            if playerIndex == sequence.count {
                // Completed the round
                score = sequence.count
                if score > highScore { highScore = score }
                phase = .showing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    addStep()
                }
            }
        } else {
            // Wrong tap
            handleGameOver()
        }
    }

    private func handleGameOver() {
        wrongFlash = true
        litButton = nil
        phase = .gameOver

        // Adaptive difficulty: record score, keep last 5, adjust
        roundScores.append(score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adjustDifficulty()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            wrongFlash = false
        }
    }

    // MARK: - Adaptive Difficulty

    private func movingAverage() -> Double {
        guard !roundScores.isEmpty else { return 0 }
        let sum = roundScores.reduce(0, +)
        return Double(sum) / Double(roundScores.count)
    }

    private func adjustDifficulty() {
        guard roundScores.count >= 2 else { return }
        let avg = movingAverage()
        // Trend: compare latest two halves of the window
        let half = roundScores.count / 2
        let recent = roundScores.suffix(max(half, 1))
        let older  = roundScores.prefix(max(half, 1))
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let olderAvg  = Double(older.reduce(0, +))  / Double(older.count)
        let improving = recentAvg > olderAvg

        if avg >= 10 && improving {
            difficulty = .hard
        } else if avg >= 5 && improving {
            difficulty = .medium
        } else if avg < 4 {
            difficulty = .easy
        }
        // else keep current difficulty
    }
}

// MARK: - Preview

#Preview {
    SimonViewV2()
}
