import SwiftUI

// MARK: - Private Models

private struct FlagEntry {
    let flag: String
    let country: String
}

private struct QuizQuestion {
    let flag: String
    let correctAnswer: String
    let choices: [String]
}

// MARK: - View Model

private class FlagQuizViewModel: ObservableObject {
    @Published var questions: [QuizQuestion] = []
    @Published var currentIndex: Int = 0
    @Published var score: Int = 0
    @Published var selectedAnswer: String? = nil
    @Published var isAnswered: Bool = false
    @Published var quizDone: Bool = false
    @Published var timeRemaining: Int = 10

    private let allFlags: [FlagEntry] = [
        FlagEntry(flag: "🇯🇵", country: "Japan"),
        FlagEntry(flag: "🇺🇸", country: "United States"),
        FlagEntry(flag: "🇬🇧", country: "United Kingdom"),
        FlagEntry(flag: "🇫🇷", country: "France"),
        FlagEntry(flag: "🇩🇪", country: "Germany"),
        FlagEntry(flag: "🇮🇹", country: "Italy"),
        FlagEntry(flag: "🇨🇳", country: "China"),
        FlagEntry(flag: "🇰🇷", country: "South Korea"),
        FlagEntry(flag: "🇧🇷", country: "Brazil"),
        FlagEntry(flag: "🇦🇺", country: "Australia"),
        FlagEntry(flag: "🇨🇦", country: "Canada"),
        FlagEntry(flag: "🇷🇺", country: "Russia"),
        FlagEntry(flag: "🇮🇳", country: "India"),
        FlagEntry(flag: "🇲🇽", country: "Mexico"),
        FlagEntry(flag: "🇪🇸", country: "Spain"),
        FlagEntry(flag: "🇵🇹", country: "Portugal"),
        FlagEntry(flag: "🇳🇱", country: "Netherlands"),
        FlagEntry(flag: "🇸🇪", country: "Sweden"),
        FlagEntry(flag: "🇨🇭", country: "Switzerland"),
        FlagEntry(flag: "🇦🇷", country: "Argentina"),
        FlagEntry(flag: "🇿🇦", country: "South Africa"),
        FlagEntry(flag: "🇬🇷", country: "Greece"),
        FlagEntry(flag: "🇹🇷", country: "Turkey"),
        FlagEntry(flag: "🇸🇦", country: "Saudi Arabia"),
        FlagEntry(flag: "🇹🇭", country: "Thailand"),
        FlagEntry(flag: "🇪🇬", country: "Egypt"),
        FlagEntry(flag: "🇳🇬", country: "Nigeria"),
        FlagEntry(flag: "🇵🇱", country: "Poland"),
        FlagEntry(flag: "🇺🇦", country: "Ukraine"),
        FlagEntry(flag: "🇮🇩", country: "Indonesia")
    ]

    private var advanceTask: Task<Void, Never>? = nil

    func startQuiz() {
        advanceTask?.cancel()
        let shuffled = allFlags.shuffled().prefix(10)
        var generated: [QuizQuestion] = []
        for entry in shuffled {
            let wrong = allFlags.filter { $0.country != entry.country }.shuffled().prefix(3).map { $0.country }
            let choices = ([entry.country] + wrong).shuffled()
            generated.append(QuizQuestion(flag: entry.flag, correctAnswer: entry.country, choices: choices))
        }
        questions = generated
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        isAnswered = false
        quizDone = false
        timeRemaining = 10
    }

    func selectAnswer(_ answer: String) {
        guard !isAnswered else { return }
        selectedAnswer = answer
        isAnswered = true
        if answer == questions[currentIndex].correctAnswer {
            score += 1
        }
        scheduleAdvance()
    }

    func timeOut() {
        guard !isAnswered else { return }
        isAnswered = true
        selectedAnswer = nil
        scheduleAdvance()
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                advance()
            }
        }
    }

    private func advance() {
        if currentIndex + 1 >= questions.count {
            quizDone = true
        } else {
            currentIndex += 1
            selectedAnswer = nil
            isAnswered = false
            timeRemaining = 10
        }
    }

    func tickTimer() {
        guard !isAnswered && !quizDone && !questions.isEmpty else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            timeOut()
        }
    }
}

// MARK: - Main View

struct FlagQuizView: View {
    @StateObject private var vm = FlagQuizViewModel()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if vm.questions.isEmpty {
                startScreen
            } else if vm.quizDone {
                scoreScreen
            } else {
                gameScreen
            }
        }
        .onReceive(timer) { _ in
            vm.tickTimer()
        }
    }

    // MARK: Start Screen
    private var startScreen: some View {
        VStack(spacing: 32) {
            Text("🌍")
                .font(.system(size: 80))
            Text("Flag Quiz")
                .font(.largeTitle.bold())
            Text("Guess the country from its flag!\n10 questions · 10 seconds each")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: { vm.startQuiz() }) {
                Text("Start Quiz")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: Game Screen
    private var gameScreen: some View {
        let question = vm.questions[vm.currentIndex]
        return VStack(spacing: 24) {
            // Header
            HStack {
                Text("Q \(vm.currentIndex + 1)/10")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                timerView
                Spacer()
                Text("Score: \(vm.score)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            // Flag
            Text(question.flag)
                .font(.system(size: 80))
                .padding(.vertical, 8)

            Text("Which country is this?")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            // Answer buttons
            VStack(spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    answerButton(choice, question: question)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isAnswered)
    }

    private var timerView: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                .frame(width: 44, height: 44)
            Circle()
                .trim(from: 0, to: CGFloat(vm.timeRemaining) / 10.0)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: vm.timeRemaining)
            Text("\(vm.timeRemaining)")
                .font(.caption.bold())
                .foregroundColor(timerColor)
        }
    }

    private var timerColor: Color {
        vm.timeRemaining > 5 ? .green : vm.timeRemaining > 3 ? .orange : .red
    }

    @ViewBuilder
    private func answerButton(_ choice: String, question: QuizQuestion) -> some View {
        let isSelected = vm.selectedAnswer == choice
        let isCorrect = choice == question.correctAnswer
        let bg: Color = {
            if !vm.isAnswered { return Color(.secondarySystemBackground) }
            if isCorrect { return .green.opacity(0.85) }
            if isSelected { return .red.opacity(0.85) }
            return Color(.secondarySystemBackground).opacity(0.6)
        }()
        let fg: Color = (vm.isAnswered && (isCorrect || isSelected)) ? .white : .primary

        Button(action: { vm.selectAnswer(choice) }) {
            HStack {
                Text(choice)
                    .font(.body.weight(.medium))
                    .foregroundColor(fg)
                Spacer()
                if vm.isAnswered {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : ""))
                        .foregroundColor(fg)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(bg, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(vm.isAnswered)
    }

    // MARK: Score Screen
    private var scoreScreen: some View {
        VStack(spacing: 28) {
            Text(scoreEmoji)
                .font(.system(size: 80))
            Text("\(vm.score)/10 Correct!")
                .font(.largeTitle.bold())
            Text(scoreMessage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { vm.startQuiz() }) {
                Text("Play Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var scoreEmoji: String {
        switch vm.score {
        case 10: return "🏆"
        case 8...9: return "🥇"
        case 6...7: return "🥈"
        case 4...5: return "🥉"
        default: return "📚"
        }
    }

    private var scoreMessage: String {
        switch vm.score {
        case 10: return "Perfect score! You're a geography genius!"
        case 8...9: return "Excellent! Almost flawless!"
        case 6...7: return "Good job! Keep exploring the world."
        case 4...5: return "Not bad! A little more practice helps."
        default: return "Keep studying those flags!"
        }
    }
}
