import SwiftUI

// MARK: - LCG Seeded RNG

struct ColorMatchLCG {
    var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 1 }
        // Warm up
        _ = next()
        _ = next()
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Int) -> Int {
        guard range > 0 else { return 0 }
        return Int(next() % UInt64(range))
    }
}

// MARK: - Models

// MARK: - Main View

struct ColorMatchViewV3: View {

    // MARK: State

    @State var seedInt: Int = 1
    @State private var gameState: ColorMatchGameState = .idle
    @State private var questions: [ColorMatchQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var streak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var timeLeft: Double = 2.0
    @State private var timer: Timer? = nil
    @State private var lastAnswerCorrect: Bool? = nil
    @State private var feedbackOpacity: Double = 0
    @State private var answerFlash: Color = .clear
    @State private var questionScale: CGFloat = 1.0

    // MARK: Constants

    private let totalQuestions = 30
    private let questionTime: Double = 2.0

    private let colorPairs: [(name: String, color: Color)] = [
        ("RED",    .red),
        ("BLUE",   .blue),
        ("GREEN",  .green),
        ("YELLOW", .yellow),
        ("ORANGE", .orange),
        ("PURPLE", Color(red: 0.6, green: 0.1, blue: 0.8)),
        ("PINK",   .pink),
        ("TEAL",   .teal),
        ("BROWN",  Color(red: 0.6, green: 0.4, blue: 0.2)),
        ("CYAN",   .cyan)
    ]

    // MARK: Body

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            switch gameState {
            case .idle:
                idleView
            case .playing:
                playingView
            case .finished:
                finishedView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: gameState)
    }

    // MARK: Idle View

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("COLOR MATCH")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("V3  •  PROCEDURAL")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Seed display
            seedBadge

            // Instructions card
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(icon: "eye.fill", text: "Read the COLOR NAME shown")
                instructionRow(icon: "paintpalette.fill", text: "Check if word color matches the name")
                instructionRow(icon: "hand.tap.fill", text: "Tap YES or NO — 2 seconds per question")
                instructionRow(icon: "30.circle.fill", text: "30 questions, same seed = same game")
            }
            .padding(20)
            .neumorphicCard()
            .padding(.horizontal, 32)

            Spacer()

            // Seed stepper
            HStack(spacing: 20) {
                Button {
                    if seedInt > 1 { seedInt -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                Text("SEED #\(seedInt)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 120)

                Button {
                    seedInt += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .neumorphicCard()

            Button(action: startGame) {
                Text("START GAME")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 32)
        }
    }

    // MARK: Playing View

    private var playingView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                // Seed badge
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)

                Spacer()

                // Score
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Streak
                VStack(alignment: .trailing, spacing: 2) {
                    Text("STREAK")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(streak > 0 ? .orange : .secondary)
                            .font(.system(size: 16))
                        Text("\(streak)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(streak > 0 ? .orange : .primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(currentIndex) / CGFloat(totalQuestions),
                            height: 6
                        )
                        .animation(.linear(duration: 0.2), value: currentIndex)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)

            Spacer()

            // Question card
            if currentIndex < questions.count {
                let q = questions[currentIndex]

                VStack(spacing: 24) {
                    // Question counter
                    Text("\(currentIndex + 1) / \(totalQuestions)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)

                    // Timer arc
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 6)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: CGFloat(timeLeft / questionTime))
                            .stroke(
                                timerColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.016), value: timeLeft)
                        Text(String(format: "%.1f", timeLeft))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(timerColor)
                    }

                    // The word in its color
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                        RoundedRectangle(cornerRadius: 20)
                            .fill(answerFlash.opacity(feedbackOpacity * 0.15))

                        Text(q.word)
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundColor(q.wordColor)
                            .padding(.vertical, 36)
                            .padding(.horizontal, 28)
                    }
                    .neumorphicCard(radius: 20)
                    .scaleEffect(questionScale)
                    .padding(.horizontal, 28)
                }
            }

            Spacer()

            // YES / NO buttons
            HStack(spacing: 24) {
                // NO button
                Button {
                    answer(false)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .black))
                        Text("NO")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .neumorphicCard(radius: 18)
                }

                // YES button
                Button {
                    answer(true)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .black))
                        Text("YES")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .neumorphicCard(radius: 18)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }

    // MARK: Finished View

    private var finishedView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Seed badge (always visible)
            seedBadge

            // Result card
            VStack(spacing: 20) {
                Text(scoreEmoji)
                    .font(.system(size: 56))

                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 32) {
                    statBlock(value: "\(score)/\(totalQuestions)", label: "SCORE")
                    statBlock(value: "\(Int(Double(score) / Double(totalQuestions) * 100))%", label: "ACCURACY")
                    statBlock(value: "\(bestStreak)", label: "BEST STREAK")
                }

                Text(scoreMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(28)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 24)

            Spacer()

            // Replay same seed
            Button(action: replaySeed) {
                Label("REPLAY SEED #\(seedInt)", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .neumorphicCard(radius: 16)
            }
            .padding(.horizontal, 28)

            // New seed
            Button(action: nextSeed) {
                Text("NEXT SEED")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 32)
        }
    }

    // MARK: Sub-components

    private var seedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "number.circle.fill")
                .foregroundColor(.purple)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .neumorphicCard(radius: 12)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: Computed

    private var timerColor: Color {
        if timeLeft > 1.0 { return .green }
        if timeLeft > 0.5 { return .orange }
        return .red
    }

    private var scoreEmoji: String {
        let pct = Double(score) / Double(totalQuestions)
        if pct >= 0.9 { return "🏆" }
        if pct >= 0.7 { return "⭐" }
        if pct >= 0.5 { return "👍" }
        return "💪"
    }

    private var scoreMessage: String {
        let pct = Double(score) / Double(totalQuestions)
        if pct >= 0.9 { return "Incredible! You're a color master." }
        if pct >= 0.7 { return "Great job! Fast and accurate." }
        if pct >= 0.5 { return "Not bad — keep practicing!" }
        return "The Stroop effect is real. Try again!"
    }

    // MARK: Game Logic

    private func generateQuestions(seed: Int) -> [ColorMatchQuestion] {
        var lcg = ColorMatchLCG(seed: seed)
        var result: [ColorMatchQuestion] = []

        for _ in 0..<totalQuestions {
            let wordIdx = lcg.nextInt(in: colorPairs.count)
            var colorIdx = lcg.nextInt(in: colorPairs.count)
            // Deterministically decide match or mismatch (~50% chance)
            let forceMatch = lcg.nextInt(in: 2) == 0
            if forceMatch {
                colorIdx = wordIdx
            } else if colorIdx == wordIdx {
                // Shift to avoid accidental match when we want mismatch
                colorIdx = (colorIdx + 1) % colorPairs.count
            }

            let word = colorPairs[wordIdx]
            let col  = colorPairs[colorIdx]
            let isMatch = (wordIdx == colorIdx)

            result.append(ColorMatchQuestion(
                word: word.name,
                wordColor: col.color,
                isMatch: isMatch
            ))
        }
        return result
    }

    private func startGame() {
        questions = generateQuestions(seed: seedInt)
        currentIndex = 0
        score = 0
        streak = 0
        bestStreak = 0
        timeLeft = questionTime
        lastAnswerCorrect = nil
        feedbackOpacity = 0
        answerFlash = .clear
        questionScale = 1.0
        gameState = .playing
        startTimer()
    }

    private func replaySeed() {
        startGame()
    }

    private func nextSeed() {
        seedInt += 1
        startGame()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            tickTimer()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tickTimer() {
        guard gameState == .playing else { return }

        timeLeft -= 1.0 / 60.0

        // Fade out feedback flash
        if feedbackOpacity > 0 {
            feedbackOpacity = max(0, feedbackOpacity - 0.04)
        }

        if timeLeft <= 0 {
            // Time's up — count as wrong
            recordAnswer(correct: false)
            advanceQuestion()
        }
    }

    private func answer(_ tappedYes: Bool) {
        guard gameState == .playing, currentIndex < questions.count else { return }
        let q = questions[currentIndex]
        let correct = (tappedYes == q.isMatch)
        recordAnswer(correct: correct)
        showFeedback(correct: correct)
        advanceQuestion()
    }

    private func recordAnswer(correct: Bool) {
        if correct {
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
        lastAnswerCorrect = correct
    }

    private func showFeedback(correct: Bool) {
        answerFlash = correct ? .green : .red
        feedbackOpacity = 1.0
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            questionScale = correct ? 1.08 : 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                questionScale = 1.0
            }
        }
    }

    private func advanceQuestion() {
        let next = currentIndex + 1
        if next >= totalQuestions {
            endGame()
        } else {
            currentIndex = next
            timeLeft = questionTime
        }
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            gameState = .finished
        }
    }
}

// MARK: - Preview

#Preview {
    ColorMatchViewV3()
}
