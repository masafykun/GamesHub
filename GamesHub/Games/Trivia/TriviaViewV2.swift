import SwiftUI

// MARK: - Models

enum TriviaGamePhase {
    case playing
    case showingResult(correct: Bool)
    case gameOver
}

// MARK: - Question Bank

struct TriviaQuestionBank {
    static let all: [TriviaQuestion] = [
        // Easy
        TriviaQuestion(
            text: "What is the chemical symbol for water?",
            options: ["H2O", "CO2", "O2", "NaCl"],
            correctIndex: 0,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "How many planets are in our solar system?",
            options: ["7", "8", "9", "10"],
            correctIndex: 1,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "Who painted the Mona Lisa?",
            options: ["Michelangelo", "Raphael", "Leonardo da Vinci", "Donatello"],
            correctIndex: 2,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "What is the largest ocean on Earth?",
            options: ["Atlantic", "Indian", "Arctic", "Pacific"],
            correctIndex: 3,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "In what year did World War II end?",
            options: ["1943", "1944", "1945", "1946"],
            correctIndex: 2,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "What is the speed of light (approximate, in km/s)?",
            options: ["150,000", "300,000", "500,000", "1,000,000"],
            correctIndex: 1,
            difficulty: .easy
        ),
        TriviaQuestion(
            text: "Which element has the atomic number 1?",
            options: ["Helium", "Oxygen", "Hydrogen", "Carbon"],
            correctIndex: 2,
            difficulty: .easy
        ),
        // Medium
        TriviaQuestion(
            text: "What year was the Eiffel Tower completed?",
            options: ["1876", "1889", "1901", "1912"],
            correctIndex: 1,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "Which scientist proposed the theory of general relativity?",
            options: ["Isaac Newton", "Niels Bohr", "Albert Einstein", "Max Planck"],
            correctIndex: 2,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "What is the powerhouse of the cell?",
            options: ["Nucleus", "Ribosome", "Golgi apparatus", "Mitochondria"],
            correctIndex: 3,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "Which country launched the first artificial satellite?",
            options: ["USA", "USSR", "China", "Germany"],
            correctIndex: 1,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "What is the most abundant gas in Earth's atmosphere?",
            options: ["Oxygen", "Carbon Dioxide", "Nitrogen", "Argon"],
            correctIndex: 2,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "Who wrote 'The Origin of Species'?",
            options: ["Gregor Mendel", "Louis Pasteur", "Carl Linnaeus", "Charles Darwin"],
            correctIndex: 3,
            difficulty: .medium
        ),
        TriviaQuestion(
            text: "In which year did the Berlin Wall fall?",
            options: ["1987", "1988", "1989", "1990"],
            correctIndex: 2,
            difficulty: .medium
        ),
        // Hard
        TriviaQuestion(
            text: "What is the half-life of Carbon-14?",
            options: ["1,430 years", "5,730 years", "14,300 years", "57,300 years"],
            correctIndex: 1,
            difficulty: .hard
        ),
        TriviaQuestion(
            text: "Which treaty ended the Thirty Years' War?",
            options: ["Treaty of Utrecht", "Peace of Westphalia", "Treaty of Paris", "Congress of Vienna"],
            correctIndex: 1,
            difficulty: .hard
        ),
        TriviaQuestion(
            text: "What is the Chandrasekhar limit approximately equal to?",
            options: ["0.8 solar masses", "1.0 solar masses", "1.4 solar masses", "2.0 solar masses"],
            correctIndex: 2,
            difficulty: .hard
        ),
        TriviaQuestion(
            text: "Which element was the first to be discovered by spectroscopy?",
            options: ["Cesium", "Rubidium", "Helium", "Thallium"],
            correctIndex: 2,
            difficulty: .hard
        ),
        TriviaQuestion(
            text: "In what year was the Magna Carta signed?",
            options: ["1215", "1265", "1315", "1415"],
            correctIndex: 0,
            difficulty: .hard
        ),
        TriviaQuestion(
            text: "What is the Planck length approximately?",
            options: ["1.6 × 10⁻³⁵ m", "1.6 × 10⁻²⁵ m", "9.1 × 10⁻³¹ m", "6.6 × 10⁻³⁴ m"],
            correctIndex: 0,
            difficulty: .hard
        )
    ]

    static func questions(for difficulty: TriviaDifficulty) -> [TriviaQuestion] {
        all.filter { $0.difficulty == difficulty }.shuffled()
    }

    static func adaptedQuestions(difficulty: TriviaDifficulty) -> [TriviaQuestion] {
        let easy = all.filter { $0.difficulty == .easy }.shuffled()
        let medium = all.filter { $0.difficulty == .medium }.shuffled()
        let hard = all.filter { $0.difficulty == .hard }.shuffled()

        switch difficulty {
        case .easy:
            return Array((easy + medium + hard).prefix(20))
        case .medium:
            return Array((medium + easy + hard).prefix(20))
        case .hard:
            return Array((hard + medium + easy).prefix(20))
        }
    }
}

// MARK: - Main View

struct TriviaViewV2: View {
    // Adaptive difficulty state
    @State var roundScores: [Int] = []
    @State private var currentDifficulty: TriviaDifficulty = .medium

    // Game state
    @State private var questions: [TriviaQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var phase: TriviaGamePhase = .playing
    @State private var selectedOption: Int? = nil

    // Timer state
    @State private var timeRemaining: Double = 15.0
    @State private var timer: Timer? = nil

    // Animation state
    @State private var questionOpacity: Double = 1.0
    @State private var questionOffset: CGFloat = 0
    @State private var badgePulse: Bool = false
    @State private var scoreReveal: Bool = false
    @State private var progressPulse: Bool = false

    private var currentQuestion: TriviaQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var movingAverage: Double {
        guard !roundScores.isEmpty else { return 50.0 }
        let last5 = Array(roundScores.suffix(5))
        return Double(last5.reduce(0, +)) / Double(last5.count)
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            VStack(spacing: 0) {
                switch phase {
                case .playing, .showingResult:
                    gamePlayView
                case .gameOver:
                    gameOverView
                }
            }
        }
        .onAppear {
            startGame()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.18),
                Color(red: 0.08, green: 0.03, blue: 0.22),
                Color(red: 0.03, green: 0.10, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .offset(x: -120, y: -200)
                    .blur(radius: 60)
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .offset(x: 140, y: 100)
                    .blur(radius: 50)
                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .offset(x: -60, y: 250)
                    .blur(radius: 40)
            }
        )
    }

    // MARK: - Game Play View

    private var gamePlayView: some View {
        VStack(spacing: 20) {
            // Header
            headerView
                .padding(.top, 8)

            // Progress bar
            progressBarView

            // Timer ring
            timerView

            // Question card
            if let question = currentQuestion {
                questionCard(question: question)
                    .opacity(questionOpacity)
                    .offset(x: questionOffset)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Answer options
            if let question = currentQuestion {
                answerGrid(question: question)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    private var headerView: some View {
        HStack {
            // Score badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(score)")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("/ \(questions.count)")
                    .foregroundColor(.white.opacity(0.6))
            }
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Difficulty badge
            difficultyBadge
        }
        .padding(.horizontal, 20)
    }

    private var difficultyBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: currentDifficulty.icon)
                .font(.system(size: 12))
            Text(currentDifficulty.rawValue)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(currentDifficulty.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(currentDifficulty.color.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(currentDifficulty.color.opacity(badgePulse ? 0.8 : 0.3), lineWidth: 1)
                )
        )
        .scaleEffect(badgePulse ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: badgePulse)
        .onAppear { badgePulse = true }
    }

    private var progressBarView: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: questions.isEmpty ? 0 : geo.size.width * CGFloat(currentIndex) / CGFloat(questions.count),
                        height: 4
                    )
                    .animation(.easeInOut(duration: 0.4), value: currentIndex)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 20)
    }

    private var timerView: some View {
        ZStack {
            // Outer ring track
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 5)
                .frame(width: 70, height: 70)

            // Timer progress ring
            Circle()
                .trim(from: 0, to: CGFloat(timeRemaining / 15.0))
                .stroke(
                    timerColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timeRemaining)

            // Timer text
            VStack(spacing: 0) {
                Text("\(Int(ceil(timeRemaining)))")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                Text("sec")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var timerColor: Color {
        if timeRemaining > 8 { return .cyan }
        if timeRemaining > 4 { return .orange }
        return .red
    }

    private func questionCard(question: TriviaQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Q number
            HStack {
                Text("Q \(currentIndex + 1) of \(questions.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                // Difficulty pip
                HStack(spacing: 3) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(pipColor(index: i, difficulty: question.difficulty))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Text(question.text)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
    }

    private func pipColor(index: Int, difficulty: TriviaDifficulty) -> Color {
        let filled: Int
        switch difficulty {
        case .easy: filled = 1
        case .medium: filled = 2
        case .hard: filled = 3
        }
        return index < filled ? difficulty.color : Color.white.opacity(0.2)
    }

    private func answerGrid(question: TriviaQuestion) -> some View {
        VStack(spacing: 12) {
            ForEach(0..<question.options.count, id: \.self) { i in
                answerButton(index: i, question: question)
            }
        }
    }

    private func answerButton(index: Int, question: TriviaQuestion) -> some View {
        let isSelected = selectedOption == index
        let isCorrect = index == question.correctIndex
        let showResult: Bool
        if case .showingResult = phase { showResult = true } else { showResult = false }

        let buttonColor: Color = {
            if !showResult { return .white.opacity(0.08) }
            if isCorrect { return .green.opacity(0.3) }
            if isSelected && !isCorrect { return .red.opacity(0.3) }
            return .white.opacity(0.04)
        }()

        let borderColor: Color = {
            if !showResult { return .white.opacity(0.15) }
            if isCorrect { return .green.opacity(0.8) }
            if isSelected && !isCorrect { return .red.opacity(0.8) }
            return .white.opacity(0.08)
        }()

        let textColor: Color = {
            if !showResult { return .white }
            if isCorrect { return .green }
            if isSelected && !isCorrect { return .red }
            return .white.opacity(0.4)
        }()

        return Button(action: {
            guard case .playing = phase else { return }
            handleAnswer(index: index, question: question)
        }) {
            HStack(spacing: 12) {
                // Option letter
                Text(["A", "B", "C", "D"][index])
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(borderColor == .white.opacity(0.08) || !showResult ? .white.opacity(0.5) : borderColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(showResult && isCorrect ? Color.green.opacity(0.2) :
                                  showResult && isSelected && !isCorrect ? Color.red.opacity(0.2) :
                                  Color.white.opacity(0.06))
                    )

                Text(question.options[index])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Result icon
                if showResult {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                            .transition(.scale.combined(with: .opacity))
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(buttonColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(borderColor, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isSelected && showResult ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showResult)
        }
        .disabled(showResult)
    }

    // MARK: - Game Over View

    private var gameOverView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                // Trophy / result icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .blur(radius: 0)

                    Image(systemName: scoreIcon)
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(scoreReveal ? 1.0 : 0.3)
                .opacity(scoreReveal ? 1.0 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: scoreReveal)

                // Score display
                VStack(spacing: 8) {
                    Text("Round Complete!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(score)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("/ \(questions.count)")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Text(scoreMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(scoreReveal ? 1.0 : 0)
                .offset(y: scoreReveal ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: scoreReveal)

                // Stats glass card
                statsCard
                    .opacity(scoreReveal ? 1.0 : 0)
                    .offset(y: scoreReveal ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: scoreReveal)

                // Next difficulty preview
                nextDifficultyCard
                    .opacity(scoreReveal ? 1.0 : 0)
                    .offset(y: scoreReveal ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: scoreReveal)

                // Play again button
                Button(action: restartGame) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 20))
                        Text("Play Again")
                            .font(.system(size: 18, weight: .bold))
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 30)
                .opacity(scoreReveal ? 1.0 : 0)
                .offset(y: scoreReveal ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: scoreReveal)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            scoreReveal = false
            withAnimation {
                scoreReveal = true
            }
        }
    }

    private var statsCard: some View {
        VStack(spacing: 16) {
            Text("Round Stats")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                statItem(label: "Correct", value: "\(score)", color: .green)
                Divider()
                    .frame(width: 1, height: 40)
                    .background(Color.white.opacity(0.15))
                statItem(label: "Wrong", value: "\(questions.count - score)", color: .red)
                Divider()
                    .frame(width: 1, height: 40)
                    .background(Color.white.opacity(0.15))
                statItem(label: "Accuracy", value: questions.isEmpty ? "0%" : "\(Int(Double(score) / Double(questions.count) * 100))%", color: .cyan)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var nextDifficultyCard: some View {
        let next = nextDifficulty()
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Round")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    HStack(spacing: 6) {
                        Image(systemName: next.icon)
                            .font(.system(size: 14))
                        Text(next.rawValue)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(next.color)
                }

                Spacer()

                // Moving average
                VStack(alignment: .trailing, spacing: 4) {
                    Text("5-Round Avg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.0f%%", roundScores.isEmpty ? 0 : movingAverage / Double(questions.isEmpty ? 1 : questions.count) * 100))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // History dots
            if !roundScores.isEmpty {
                HStack(spacing: 6) {
                    Text("History:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    ForEach(Array(roundScores.suffix(5).enumerated()), id: \.offset) { _, s in
                        let pct = questions.isEmpty ? 0.0 : Double(s) / Double(questions.count)
                        Circle()
                            .fill(pct >= 0.7 ? Color.green : pct >= 0.4 ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(next.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(next.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var scoreIcon: String {
        guard !questions.isEmpty else { return "star.fill" }
        let pct = Double(score) / Double(questions.count)
        if pct >= 0.8 { return "trophy.fill" }
        if pct >= 0.5 { return "star.fill" }
        return "medal.fill"
    }

    private var scoreMessage: String {
        guard !questions.isEmpty else { return "" }
        let pct = Double(score) / Double(questions.count)
        if pct >= 0.9 { return "Outstanding! You're a genius!" }
        if pct >= 0.7 { return "Great job! Well done!" }
        if pct >= 0.5 { return "Good effort! Keep practicing!" }
        return "Keep learning, you'll get there!"
    }

    // MARK: - Game Logic

    private func startGame() {
        stopTimer()
        questions = TriviaQuestionBank.adaptedQuestions(difficulty: currentDifficulty)
        currentIndex = 0
        score = 0
        phase = .playing
        selectedOption = nil
        questionOpacity = 1.0
        questionOffset = 0
        scoreReveal = false
        startTimer()
    }

    private func restartGame() {
        currentDifficulty = nextDifficulty()
        startGame()
    }

    private func nextDifficulty() -> TriviaDifficulty {
        guard !roundScores.isEmpty, !questions.isEmpty else { return .medium }
        let avgPct = movingAverage / Double(questions.count)
        if avgPct >= 0.75 { return .hard }
        if avgPct >= 0.45 { return .medium }
        return .easy
    }

    private func handleAnswer(index: Int, question: TriviaQuestion) {
        stopTimer()
        selectedOption = index
        let correct = index == question.correctIndex
        if correct { score += 1 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            phase = .showingResult(correct: correct)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        withAnimation(.easeOut(duration: 0.25)) {
            questionOpacity = 0
            questionOffset = -30
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            selectedOption = nil
            let nextIndex = currentIndex + 1
            if nextIndex >= questions.count {
                finishGame()
            } else {
                currentIndex = nextIndex
                phase = .playing
                timeRemaining = 15.0
                withAnimation(.easeIn(duration: 0.25)) {
                    questionOpacity = 1
                    questionOffset = 0
                }
                startTimer()
            }
        }
    }

    private func finishGame() {
        stopTimer()
        roundScores.append(score)
        if roundScores.count > 5 { roundScores = Array(roundScores.suffix(5)) }
        phase = .gameOver
    }

    private func startTimer() {
        timeRemaining = 15.0
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining <= 0 {
                // Time's up — auto wrong answer
                if case .playing = phase, let q = currentQuestion {
                    handleAnswer(index: -1, question: q)
                }
            } else {
                timeRemaining -= 0.1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    TriviaViewV2()
}
