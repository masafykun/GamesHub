import SwiftUI

// MARK: - Models & Enums

enum ColorMatchDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var timePerQuestion: Double {
        switch self {
        case .easy:   return 2.5
        case .medium: return 2.0
        case .hard:   return 1.4
        }
    }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

enum ColorMatchGamePhase {
    case idle
    case playing
    case gameOver
}

struct ColorMatchPair {
    let word: String
    let wordColor: Color
    let isMatch: Bool
}

// MARK: - View Model

@MainActor
final class ColorMatchViewModel: ObservableObject {

    // MARK: - Named colors for the game
    static let namedColors: [(name: String, color: Color)] = [
        ("RED",    .red),
        ("BLUE",   .blue),
        ("GREEN",  .green),
        ("YELLOW", .yellow),
        ("ORANGE", .orange),
        ("PURPLE", .purple),
        ("PINK",   .pink),
        ("WHITE",  .white),
        ("CYAN",   .cyan),
    ]

    // MARK: - Published State
    @Published var phase: ColorMatchGamePhase = .idle
    @Published var currentPair: ColorMatchPair = ColorMatchPair(word: "RED", wordColor: .red, isMatch: true)
    @Published var questionIndex: Int = 0
    @Published var score: Int = 0
    @Published var streak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var timeRemaining: Double = 2.0
    @Published var difficulty: ColorMatchDifficulty = .medium
    @Published var roundScores: [Int] = []
    @Published var lastAnswerCorrect: Bool? = nil
    @Published var showFeedback: Bool = false
    @Published var progress: Double = 1.0

    // MARK: - Internal
    private var questions: [ColorMatchPair] = []
    private var timer: Timer?
    private let totalQuestions = 30

    // MARK: - Derived
    var difficultyBadgeText: String { difficulty.rawValue }
    var difficultyBadgeColor: Color { difficulty.color }
    var isLastQuestion: Bool { questionIndex >= totalQuestions }

    // MARK: - Game Flow

    func startGame() {
        questions = generateQuestions()
        questionIndex = 0
        score = 0
        streak = 0
        bestStreak = 0
        lastAnswerCorrect = nil
        showFeedback = false
        phase = .playing
        loadQuestion()
        startTimer()
    }

    func answer(_ tappedYes: Bool) {
        guard phase == .playing else { return }
        stopTimer()

        let correct = (tappedYes == currentPair.isMatch)
        withAnimation(.easeInOut(duration: 0.15)) {
            lastAnswerCorrect = correct
            showFeedback = true
        }

        if correct {
            score += 1
            streak += 1
            if streak > bestStreak { bestStreak = streak }
        } else {
            streak = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.showFeedback = false
            self.lastAnswerCorrect = nil
            self.advance()
        }
    }

    private func advance() {
        questionIndex += 1
        if questionIndex >= totalQuestions {
            endGame()
        } else {
            loadQuestion()
            startTimer()
        }
    }

    private func loadQuestion() {
        currentPair = questions[questionIndex]
        timeRemaining = difficulty.timePerQuestion
        progress = 1.0
    }

    private func startTimer() {
        stopTimer()
        let interval = 1.0 / 60.0
        var elapsed = 0.0
        let total = difficulty.timePerQuestion
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            elapsed += interval
            let remaining = max(0, total - elapsed)
            Task { @MainActor in
                self.timeRemaining = remaining
                self.progress = remaining / total
                if remaining <= 0 {
                    self.timeUp()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timeUp() {
        stopTimer()
        // Treat timeout as wrong answer
        streak = 0
        lastAnswerCorrect = false
        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.showFeedback = false
            self.lastAnswerCorrect = nil
            self.advance()
        }
    }

    private func endGame() {
        stopTimer()
        phase = .gameOver

        // Adaptive difficulty: track last 5 scores
        roundScores.append(score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adjustDifficulty()
    }

    private func adjustDifficulty() {
        guard roundScores.count >= 2 else { return }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        let highThreshold = Double(totalQuestions) * 0.80  // >= 80% correct -> go harder
        let lowThreshold  = Double(totalQuestions) * 0.50  // <= 50% correct -> go easier

        if avg >= highThreshold {
            switch difficulty {
            case .easy:   difficulty = .medium
            case .medium: difficulty = .hard
            case .hard:   break
            }
        } else if avg <= lowThreshold {
            switch difficulty {
            case .hard:   difficulty = .medium
            case .medium: difficulty = .easy
            case .easy:   break
            }
        }
    }

    private func generateQuestions() -> [ColorMatchPair] {
        var pairs: [ColorMatchPair] = []
        for _ in 0..<totalQuestions {
            let wordEntry = Self.namedColors.randomElement()!
            let wordName  = wordEntry.name
            let wordColor = wordEntry.color
            // ~50% chance the word matches the color
            let forceMatch = Bool.random()
            if forceMatch {
                pairs.append(ColorMatchPair(word: wordName, wordColor: wordColor, isMatch: true))
            } else {
                // Ensure mismatch
                var displayEntry = Self.namedColors.randomElement()!
                while displayEntry.name == wordName {
                    displayEntry = Self.namedColors.randomElement()!
                }
                pairs.append(ColorMatchPair(word: wordName, wordColor: displayEntry.color, isMatch: false))
            }
        }
        return pairs
    }
}

// MARK: - Main View

struct ColorMatchView: View {

    @StateObject private var vm = ColorMatchViewModel()

    // Feedback flash overlay color
    private var feedbackOverlay: Color {
        guard vm.showFeedback, let correct = vm.lastAnswerCorrect else { return .clear }
        return correct ? Color.green.opacity(0.25) : Color.red.opacity(0.25)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.18),
                         Color(red: 0.12, green: 0.05, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Feedback flash
            feedbackOverlay
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: vm.showFeedback)

            switch vm.phase {
            case .idle:
                ColorMatchIdleView(onStart: { vm.startGame() },
                                   difficulty: vm.difficulty,
                                   roundScores: vm.roundScores)
            case .playing:
                ColorMatchPlayingView(vm: vm)
            case .gameOver:
                ColorMatchGameOverView(vm: vm,
                                       onRestart: { vm.startGame() })
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Idle / Start Screen

struct ColorMatchIdleView: View {
    let onStart: () -> Void
    let difficulty: ColorMatchDifficulty
    let roundScores: [Int]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Title glass card
            VStack(spacing: 12) {
                Text("COLOR MATCH")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .purple.opacity(0.8)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("Does the word match its colour?")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.purple.opacity(0.8))
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            // Description
            VStack(spacing: 8) {
                Text("Does the WORD match the COLOR?")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                HStack(spacing: 16) {
                    Label("YES / NO", systemImage: "hand.tap.fill")
                    Text("•")
                    Label("30 questions", systemImage: "list.number")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Difficulty badge
            ColorMatchDifficultyBadge(difficulty: difficulty)

            // Past scores
            if !roundScores.isEmpty {
                ColorMatchRecentScoresView(scores: roundScores)
            }

            Spacer()

            // Start button
            Button(action: onStart) {
                Text("START")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [.purple, .blue],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .purple.opacity(0.5), radius: 12, y: 6)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Playing View

struct ColorMatchPlayingView: View {
    @ObservedObject var vm: ColorMatchViewModel

    var body: some View {
        VStack(spacing: 20) {

            // Top HUD
            ColorMatchHUDView(vm: vm)
                .padding(.top, 16)

            // Timer bar
            ColorMatchTimerBarView(progress: vm.progress, difficulty: vm.difficulty)

            Spacer()

            // Word card
            ColorMatchWordCardView(pair: vm.currentPair)

            Spacer()

            // YES / NO buttons
            ColorMatchAnswerButtonsView(
                onYes: { vm.answer(true) },
                onNo:  { vm.answer(false) }
            )
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - HUD

struct ColorMatchHUDView: View {
    @ObservedObject var vm: ColorMatchViewModel

    var body: some View {
        HStack {
            // Score glass pill
            ColorMatchStatPill(label: "SCORE", value: "\(vm.score)")

            Spacer()

            // Question counter
            Text("\(vm.questionIndex + 1) / 30")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // Streak glass pill
            ColorMatchStatPill(label: "STREAK", value: "\(vm.streak)")
        }
    }
}

struct ColorMatchStatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Timer Bar

struct ColorMatchTimerBarView: View {
    let progress: Double
    let difficulty: ColorMatchDifficulty

    private var barColor: Color {
        if progress > 0.6 { return .green }
        if progress > 0.3 { return .orange }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 8)
                Capsule()
                    .fill(
                        LinearGradient(colors: [barColor, barColor.opacity(0.6)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, progress))), height: 8)
                    .animation(.linear(duration: 1.0 / 60.0), value: progress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Word Card

struct ColorMatchWordCardView: View {
    let pair: ColorMatchPair

    var body: some View {
        ZStack {
            // Glass card background
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            VStack(spacing: 16) {
                Text("Does the word match the color?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text(pair.word)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(pair.wordColor)
                    .shadow(color: pair.wordColor.opacity(0.6), radius: 12)
                    .padding(.vertical, 8)
            }
            .padding(36)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

// MARK: - Answer Buttons

struct ColorMatchAnswerButtonsView: View {
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // NO button
            Button(action: onNo) {
                Text("NO")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.regularMaterial)
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.35))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
            }

            // YES button
            Button(action: onYes) {
                Text("YES")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.regularMaterial)
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.green.opacity(0.35))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: .green.opacity(0.3), radius: 10, y: 4)
            }
        }
    }
}

// MARK: - Game Over Screen

struct ColorMatchGameOverView: View {
    @ObservedObject var vm: ColorMatchViewModel
    let onRestart: () -> Void

    private var movingAverage: Double {
        guard !vm.roundScores.isEmpty else { return 0 }
        return Double(vm.roundScores.reduce(0, +)) / Double(vm.roundScores.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // Title
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .purple.opacity(0.8)],
                                       startPoint: .top, endPoint: .bottom)
                    )

                // Score card
                VStack(spacing: 18) {
                    Text("Your Score")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    Text("\(vm.score)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("/ 30 correct")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))

                    Divider().background(Color.white.opacity(0.15))

                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("BEST STREAK")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(vm.bestStreak)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        Divider()
                            .frame(height: 40)
                            .background(Color.white.opacity(0.15))
                        VStack(spacing: 4) {
                            Text("AVG (5 RND)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            Text(String(format: "%.1f", movingAverage))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Adaptive difficulty info
                VStack(spacing: 10) {
                    Text("NEXT DIFFICULTY")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    ColorMatchDifficultyBadge(difficulty: vm.difficulty)

                    Text(difficultyHint)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Recent scores
                if !vm.roundScores.isEmpty {
                    ColorMatchRecentScoresView(scores: vm.roundScores)
                }

                // Play again button
                Button(action: onRestart) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(colors: [.purple, .blue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .purple.opacity(0.5), radius: 12, y: 6)
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 24)
        }
    }

    private var difficultyHint: String {
        switch vm.difficulty {
        case .easy:   return "Keep practicing — you'll speed up!"
        case .medium: return "Good balance — push yourself!"
        case .hard:   return "Elite mode! You're on a roll."
        }
    }
}

// MARK: - Difficulty Badge

struct ColorMatchDifficultyBadge: View {
    let difficulty: ColorMatchDifficulty

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
                .shadow(color: difficulty.color.opacity(0.8), radius: 4)
            Text(difficulty.rawValue.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(difficulty.color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Recent Scores

struct ColorMatchRecentScoresView: View {
    let scores: [Int]

    var body: some View {
        VStack(spacing: 10) {
            Text("RECENT ROUNDS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))

            HStack(spacing: 8) {
                ForEach(Array(scores.enumerated()), id: \.offset) { idx, s in
                    VStack(spacing: 4) {
                        Text("\(s)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("R\(idx + 1)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
