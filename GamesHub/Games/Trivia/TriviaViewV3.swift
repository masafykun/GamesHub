import SwiftUI

// MARK: - Data Models

// MARK: - Main View

struct TriviaViewV3: View {

    // MARK: - All 20 hardcoded questions
    private let allQuestions: [TriviaQuestion] = [
        TriviaQuestion(
            text: "What is the chemical symbol for gold?",
            options: ["Go", "Gd", "Au", "Ag"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "Which planet is known as the Red Planet?",
            options: ["Venus", "Mars", "Jupiter", "Saturn"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "In what year did World War II end?",
            options: ["1943", "1944", "1945", "1946"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "What is the speed of light (approx.) in km/s?",
            options: ["150,000", "300,000", "450,000", "600,000"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "Who painted the Mona Lisa?",
            options: ["Raphael", "Michelangelo", "Donatello", "Leonardo da Vinci"],
            correctIndex: 3
        ),
        TriviaQuestion(
            text: "What is the powerhouse of the cell?",
            options: ["Nucleus", "Ribosome", "Mitochondria", "Golgi apparatus"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "Which element has atomic number 1?",
            options: ["Helium", "Oxygen", "Carbon", "Hydrogen"],
            correctIndex: 3
        ),
        TriviaQuestion(
            text: "The Great Wall of China was primarily built during which dynasty?",
            options: ["Han", "Tang", "Ming", "Qing"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "What is the largest ocean on Earth?",
            options: ["Atlantic", "Indian", "Arctic", "Pacific"],
            correctIndex: 3
        ),
        TriviaQuestion(
            text: "Which scientist proposed the theory of general relativity?",
            options: ["Isaac Newton", "Albert Einstein", "Niels Bohr", "Max Planck"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "How many bones are in the adult human body?",
            options: ["196", "206", "216", "226"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "In which country was the first Olympic Games held in modern times?",
            options: ["France", "Italy", "Greece", "Germany"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "What gas do plants absorb from the atmosphere?",
            options: ["Oxygen", "Nitrogen", "Carbon Dioxide", "Hydrogen"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "Who was the first person to walk on the Moon?",
            options: ["Buzz Aldrin", "Yuri Gagarin", "Neil Armstrong", "John Glenn"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "What is the hardest natural substance on Earth?",
            options: ["Quartz", "Diamond", "Titanium", "Obsidian"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "The French Revolution began in which year?",
            options: ["1776", "1789", "1799", "1804"],
            correctIndex: 1
        ),
        TriviaQuestion(
            text: "What is the smallest prime number?",
            options: ["0", "1", "2", "3"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "Which organ produces insulin?",
            options: ["Liver", "Kidney", "Pancreas", "Stomach"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "How many continents are on Earth?",
            options: ["5", "6", "7", "8"],
            correctIndex: 2
        ),
        TriviaQuestion(
            text: "What is the chemical formula for water?",
            options: ["HO", "H2O", "H3O", "H2O2"],
            correctIndex: 1
        )
    ]

    // MARK: - State

    @State var seedInt: Int = 1
    @State private var orderedQuestions: [TriviaQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: Int? = nil
    @State private var timeRemaining: Double = 15
    @State private var gameOver: Bool = false
    @State private var advanceTimer: Timer? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var showResult: Bool = false

    // MARK: - LCG Shuffle

    private func lcgShuffle(seed: Int) -> [TriviaQuestion] {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407

        var indices = Array(0..<allQuestions.count)
        for i in stride(from: indices.count - 1, through: 1, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(s >> 33) % (i + 1)
            indices.swapAt(i, j)
        }
        return indices.map { allQuestions[$0] }
    }

    // MARK: - Computed

    private var currentQuestion: TriviaQuestion? {
        guard currentIndex < orderedQuestions.count else { return nil }
        return orderedQuestions[currentIndex]
    }

    private var timerProgress: Double {
        timeRemaining / 15.0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            if gameOver {
                scoreView
            } else if let question = currentQuestion {
                questionView(question: question)
            }
        }
        .onAppear {
            startGame()
        }
    }

    // MARK: - Question View

    private func questionView(question: TriviaQuestion) -> some View {
        VStack(spacing: 20) {

            // Header: Seed + Progress
            HStack {
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)

                Spacer()

                Text("\(currentIndex + 1) / \(orderedQuestions.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)
            }
            .padding(.horizontal)

            // Timer Bar
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(timerColor)
                    Text(String(format: "%.0fs", timeRemaining))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(timerColor)
                    Spacer()
                    Text("Score: \(score)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(timerColor)
                            .frame(width: geo.size.width * CGFloat(timerProgress), height: 8)
                            .animation(.linear(duration: 0.25), value: timerProgress)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal)

            // Question Card
            Text(question.text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(20)
                .frame(maxWidth: .infinity)
                .neumorphicCard(radius: 18)
                .padding(.horizontal)

            // Answer Buttons
            VStack(spacing: 14) {
                ForEach(0..<question.options.count, id: \.self) { idx in
                    answerButton(label: question.options[idx], index: idx, question: question)
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 10)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func answerButton(label: String, index: Int, question: TriviaQuestion) -> some View {
        let isSelected = selectedAnswer == index
        let isCorrect = index == question.correctIndex
        let hasAnswered = selectedAnswer != nil

        let bgColor: Color = {
            if !hasAnswered { return Color(.systemGray6) }
            if isCorrect { return Color.green.opacity(0.25) }
            if isSelected && !isCorrect { return Color.red.opacity(0.25) }
            return Color(.systemGray6)
        }()

        let borderColor: Color = {
            if !hasAnswered { return Color.clear }
            if isCorrect { return Color.green }
            if isSelected && !isCorrect { return Color.red }
            return Color.clear
        }()

        Button(action: {
            guard selectedAnswer == nil else { return }
            handleAnswer(index)
        }) {
            HStack(spacing: 12) {
                Text(optionLabel(index))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(hasAnswered ? (isCorrect ? .green : (isSelected ? .red : .secondary)) : .secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(hasAnswered ? (isCorrect ? Color.green.opacity(0.15) : (isSelected ? Color.red.opacity(0.15) : Color(.systemGray5))) : Color(.systemGray5))
                    )

                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if hasAnswered && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if hasAnswered && isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 2)
            )
            .shadow(color: .white.opacity(0.8), radius: 5, x: -3, y: -3)
            .shadow(color: Color(.systemGray4), radius: 5, x: 3, y: 3)
            .scaleEffect(isSelected && hasAnswered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .disabled(hasAnswered)
    }

    // MARK: - Score View

    private var scoreView: some View {
        VStack(spacing: 28) {
            // Seed display
            Text("SEED: #\(seedInt - 1)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .neumorphicCard(radius: 10)

            // Trophy Icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 100, height: 100)
                    .shadow(color: .white.opacity(0.8), radius: 10, x: -6, y: -6)
                    .shadow(color: Color(.systemGray4), radius: 10, x: 6, y: 6)

                Text(scoreEmoji)
                    .font(.system(size: 48))
            }

            // Score Card
            VStack(spacing: 10) {
                Text("Game Over")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("\(score) / \(orderedQuestions.count)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text(scoreMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .neumorphicCard(radius: 20)
            .padding(.horizontal)

            // Restart Button
            Button(action: restartGame) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Timer Color

    private var timerColor: Color {
        if timeRemaining > 8 { return .green }
        if timeRemaining > 4 { return .orange }
        return .red
    }

    // MARK: - Score Helpers

    private var scoreEmoji: String {
        let pct = Double(score) / Double(max(orderedQuestions.count, 1))
        if pct >= 0.9 { return "🏆" }
        if pct >= 0.7 { return "🌟" }
        if pct >= 0.5 { return "👍" }
        return "📚"
    }

    private var scoreMessage: String {
        let pct = Double(score) / Double(max(orderedQuestions.count, 1))
        if pct >= 0.9 { return "Outstanding! You're a trivia master!" }
        if pct >= 0.7 { return "Great job! Well done!" }
        if pct >= 0.5 { return "Not bad! Keep practicing!" }
        return "Better luck next time!"
    }

    private func optionLabel(_ index: Int) -> String {
        ["A", "B", "C", "D"][index]
    }

    // MARK: - Game Logic

    private func startGame() {
        orderedQuestions = lcgShuffle(seed: seedInt)
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        timeRemaining = 15
        gameOver = false
        startCountdown()
    }

    private func restartGame() {
        stopTimers()
        seedInt += 1
        startGame()
    }

    private func handleAnswer(_ index: Int) {
        guard let question = currentQuestion else { return }
        selectedAnswer = index
        stopTimers()

        if index == question.correctIndex {
            score += 1
        }

        scheduleAdvance()
    }

    private func scheduleAdvance() {
        advanceTimer?.invalidate()
        advanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        advanceTimer?.invalidate()
        advanceTimer = nil

        let nextIndex = currentIndex + 1
        if nextIndex >= orderedQuestions.count {
            stopTimers()
            gameOver = true
        } else {
            currentIndex = nextIndex
            selectedAnswer = nil
            timeRemaining = 15
            startCountdown()
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            if timeRemaining <= 0 {
                // Time's up — treat as wrong answer
                if selectedAnswer == nil {
                    selectedAnswer = -1
                    stopTimers()
                    scheduleAdvance()
                }
            } else {
                timeRemaining = max(0, timeRemaining - 0.25)
            }
        }
    }

    private func stopTimers() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}

// MARK: - Preview

#Preview {
    TriviaViewV3()
}
