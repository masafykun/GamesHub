import SwiftUI

// MARK: - Private Models (V3)

private struct FlagV3Entry {
    let flag: String
    let country: String
}

private struct FlagV3Question {
    let flag: String
    let correctAnswer: String
    let choices: [String]
}

// MARK: - Neumorphic Helpers (V3)

private struct FlagQuizV3NeuCard: ViewModifier {
    var isInset: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: isInset ? .clear : Color.black.opacity(0.18), radius: isInset ? 0 : 8, x: isInset ? 0 : 4, y: isInset ? 0 : 4)
            .shadow(color: isInset ? .clear : Color.white.opacity(0.7), radius: isInset ? 0 : 8, x: isInset ? 0 : -4, y: isInset ? 0 : -4)
            .overlay {
                if isInset {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.systemGray5))
                        )
                }
            }
    }
}

private extension View {
    func flagV3NeuCard(isInset: Bool = false) -> some View {
        self.modifier(FlagQuizV3NeuCard(isInset: isInset))
    }
}

// MARK: - View Model (V3)

private class FlagQuizV3ViewModel: ObservableObject {
    @Published var questions: [FlagV3Question] = []
    @Published var currentIndex: Int = 0
    @Published var score: Int = 0
    @Published var selectedAnswer: String? = nil
    @Published var isAnswered: Bool = false
    @Published var quizDone: Bool = false
    @Published var timeRemaining: Int = 10
    @Published var pressedButton: String? = nil

    private let allFlags: [FlagV3Entry] = [
        FlagV3Entry(flag: "🇯🇵", country: "Japan"),
        FlagV3Entry(flag: "🇺🇸", country: "United States"),
        FlagV3Entry(flag: "🇬🇧", country: "United Kingdom"),
        FlagV3Entry(flag: "🇫🇷", country: "France"),
        FlagV3Entry(flag: "🇩🇪", country: "Germany"),
        FlagV3Entry(flag: "🇮🇹", country: "Italy"),
        FlagV3Entry(flag: "🇨🇳", country: "China"),
        FlagV3Entry(flag: "🇰🇷", country: "South Korea"),
        FlagV3Entry(flag: "🇧🇷", country: "Brazil"),
        FlagV3Entry(flag: "🇦🇺", country: "Australia"),
        FlagV3Entry(flag: "🇨🇦", country: "Canada"),
        FlagV3Entry(flag: "🇷🇺", country: "Russia"),
        FlagV3Entry(flag: "🇮🇳", country: "India"),
        FlagV3Entry(flag: "🇲🇽", country: "Mexico"),
        FlagV3Entry(flag: "🇪🇸", country: "Spain"),
        FlagV3Entry(flag: "🇵🇹", country: "Portugal"),
        FlagV3Entry(flag: "🇳🇱", country: "Netherlands"),
        FlagV3Entry(flag: "🇸🇪", country: "Sweden"),
        FlagV3Entry(flag: "🇨🇭", country: "Switzerland"),
        FlagV3Entry(flag: "🇦🇷", country: "Argentina"),
        FlagV3Entry(flag: "🇿🇦", country: "South Africa"),
        FlagV3Entry(flag: "🇬🇷", country: "Greece"),
        FlagV3Entry(flag: "🇹🇷", country: "Turkey"),
        FlagV3Entry(flag: "🇸🇦", country: "Saudi Arabia"),
        FlagV3Entry(flag: "🇹🇭", country: "Thailand"),
        FlagV3Entry(flag: "🇪🇬", country: "Egypt"),
        FlagV3Entry(flag: "🇳🇬", country: "Nigeria"),
        FlagV3Entry(flag: "🇵🇱", country: "Poland"),
        FlagV3Entry(flag: "🇺🇦", country: "Ukraine"),
        FlagV3Entry(flag: "🇮🇩", country: "Indonesia")
    ]

    private var advanceTask: Task<Void, Never>? = nil

    func startQuiz() {
        advanceTask?.cancel()
        let shuffled = allFlags.shuffled().prefix(10)
        var generated: [FlagV3Question] = []
        for entry in shuffled {
            let wrong = allFlags.filter { $0.country != entry.country }.shuffled().prefix(3).map { $0.country }
            let choices = ([entry.country] + wrong).shuffled()
            generated.append(FlagV3Question(flag: entry.flag, correctAnswer: entry.country, choices: choices))
        }
        questions = generated
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        isAnswered = false
        quizDone = false
        timeRemaining = 10
        pressedButton = nil
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
            pressedButton = nil
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

// MARK: - Neumorphism View (V3)

struct FlagQuizViewV3: View {
    @StateObject private var vm = FlagQuizV3ViewModel()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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

    // MARK: - Start Screen
    private var startScreen: some View {
        VStack(spacing: 36) {
            VStack(spacing: 4) {
                Text("🌍")
                    .font(.system(size: 80))
                    .padding(24)
                    .flagV3NeuCard()
            }

            VStack(spacing: 8) {
                Text("Flag Quiz")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Guess the country from its flag\n10 questions · 10 seconds each")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            v3PrimaryButton(label: "Start Quiz", icon: "play.fill") {
                vm.startQuiz()
            }
        }
        .padding(32)
    }

    // MARK: - Game Screen
    private var gameScreen: some View {
        let question = vm.questions[vm.currentIndex]
        return ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Question")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(vm.currentIndex + 1) / 10")
                            .font(.headline.bold())
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    v3TimerView
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(vm.score)")
                            .font(.headline.bold())
                            .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.9))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .flagV3NeuCard()
                .padding(.horizontal)

                // Flag card
                VStack(spacing: 10) {
                    Text(question.flag)
                        .font(.system(size: 80))
                        .padding(.top, 8)

                    Text("Which country is this?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .flagV3NeuCard()
                .padding(.horizontal)

                // Progress bar
                v3ProgressBar
                    .padding(.horizontal)

                // Answer buttons
                VStack(spacing: 12) {
                    ForEach(question.choices, id: \.self) { choice in
                        v3AnswerButton(choice, question: question)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
    }

    private var v3TimerView: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 52, height: 52)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 3, y: 3)
                .shadow(color: Color.white.opacity(0.7), radius: 6, x: -3, y: -3)

            Circle()
                .stroke(Color(.systemGray4), lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: CGFloat(vm.timeRemaining) / 10.0)
                .stroke(v3TimerColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: vm.timeRemaining)

            Text("\(vm.timeRemaining)")
                .font(.caption.bold())
                .foregroundColor(v3TimerColor)
        }
    }

    private var v3TimerColor: Color {
        vm.timeRemaining > 5 ? Color(red: 0.2, green: 0.65, blue: 0.3) :
        vm.timeRemaining > 3 ? Color(red: 0.9, green: 0.55, blue: 0.1) :
        Color(red: 0.85, green: 0.2, blue: 0.2)
    }

    private var v3ProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 1, y: 1)
                    .shadow(color: Color.white.opacity(0.6), radius: 3, x: -1, y: -1)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.2, green: 0.5, blue: 0.9))
                    .frame(width: geo.size.width * CGFloat(vm.currentIndex + 1) / 10.0, height: 6)
                    .animation(.easeInOut, value: vm.currentIndex)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private func v3AnswerButton(_ choice: String, question: FlagV3Question) -> some View {
        let isSelected = vm.selectedAnswer == choice
        let isCorrect = choice == question.correctAnswer
        let isInset = vm.isAnswered && (isCorrect || isSelected)

        let bgColor: Color = {
            if !vm.isAnswered { return Color(.systemGray6) }
            if isCorrect { return Color(red: 0.88, green: 0.97, blue: 0.88) }
            if isSelected { return Color(red: 0.97, green: 0.88, blue: 0.88) }
            return Color(.systemGray6)
        }()
        let textColor: Color = {
            if !vm.isAnswered { return .primary }
            if isCorrect { return Color(red: 0.1, green: 0.5, blue: 0.15) }
            if isSelected { return Color(red: 0.6, green: 0.1, blue: 0.1) }
            return Color.primary.opacity(0.4)
        }()

        Button(action: { vm.selectAnswer(choice) }) {
            HStack {
                Text(choice)
                    .font(.body.weight(.medium))
                    .foregroundColor(textColor)
                Spacer()
                if vm.isAnswered && (isCorrect || isSelected) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? Color(red: 0.1, green: 0.55, blue: 0.2) : Color(red: 0.7, green: 0.15, blue: 0.15))
                        .font(.body)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isInset ? Color.clear : Color.black.opacity(0.15),
                radius: isInset ? 0 : 6, x: isInset ? 0 : 3, y: isInset ? 0 : 3
            )
            .shadow(
                color: isInset ? Color.clear : Color.white.opacity(0.7),
                radius: isInset ? 0 : 6, x: isInset ? 0 : -3, y: isInset ? 0 : -3
            )
            .overlay {
                if isInset {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isCorrect ? Color(red: 0.3, green: 0.7, blue: 0.35).opacity(0.5) :
                                        Color(red: 0.7, green: 0.3, blue: 0.3).opacity(0.5),
                            lineWidth: 1.5
                        )
                }
            }
        }
        .disabled(vm.isAnswered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isAnswered)
    }

    // MARK: - Primary Button Helper
    private func v3PrimaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(label)
                    .font(.headline)
            }
            .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 4, y: 4)
            .shadow(color: Color.white.opacity(0.7), radius: 8, x: -4, y: -4)
        }
    }

    // MARK: - Score Screen
    private var scoreScreen: some View {
        VStack(spacing: 28) {
            Text(v3ScoreEmoji)
                .font(.system(size: 80))
                .padding(24)
                .flagV3NeuCard()

            VStack(spacing: 10) {
                Text("\(vm.score)/10 Correct!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(v3ScoreMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .flagV3NeuCard()

            v3PrimaryButton(label: "Play Again", icon: "arrow.counterclockwise") {
                vm.startQuiz()
            }
        }
        .padding(32)
    }

    private var v3ScoreEmoji: String {
        switch vm.score {
        case 10: return "🏆"
        case 8...9: return "🥇"
        case 6...7: return "🥈"
        case 4...5: return "🥉"
        default: return "📚"
        }
    }

    private var v3ScoreMessage: String {
        switch vm.score {
        case 10: return "Perfect score! Geography master!"
        case 8...9: return "Excellent! Almost flawless!"
        case 6...7: return "Good job! Keep exploring the world."
        case 4...5: return "Not bad! A little more practice helps."
        default: return "Keep studying those flags!"
        }
    }
}
