import SwiftUI

// MARK: - Private Models ()

private struct FlagEntry {
    let flag: String
    let country: String
}

private struct FlagQuestion {
    let flag: String
    let correctAnswer: String
    let choices: [String]
}

// MARK: - View Model ()

private class FlagQuizViewModel: ObservableObject {
    @Published var questions: [FlagQuestion] = []
    @Published var currentIndex: Int = 0
    @Published var score: Int = 0
    @Published var selectedAnswer: String? = nil
    @Published var isAnswered: Bool = false
    @Published var quizDone: Bool = false
    @Published var timeRemaining: Int = 10
    @Published var flagScale: CGFloat = 1.0
    @Published var cardOpacity: Double = 1.0

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
        var generated: [FlagQuestion] = []
        for entry in shuffled {
            let wrong = allFlags.filter { $0.country != entry.country }.shuffled().prefix(3).map { $0.country }
            let choices = ([entry.country] + wrong).shuffled()
            generated.append(FlagQuestion(flag: entry.flag, correctAnswer: entry.country, choices: choices))
        }
        questions = generated
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        isAnswered = false
        quizDone = false
        timeRemaining = 10
        flagScale = 1.0
        cardOpacity = 1.0
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
        withAnimation(.easeOut(duration: 0.3)) {
            cardOpacity = 0.0
            flagScale = 0.8
        }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                if currentIndex + 1 >= questions.count {
                    quizDone = true
                } else {
                    currentIndex += 1
                    selectedAnswer = nil
                    isAnswered = false
                    timeRemaining = 10
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    cardOpacity = 1.0
                    flagScale = 1.0
                }
            }
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

// MARK: - Glassmorphism View ()

struct FlagQuizView: View {
    @StateObject private var vm = FlagQuizViewModel()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let gradientColors: [Color] = [
        Color(red: 0.05, green: 0.05, blue: 0.25),
        Color(red: 0.12, green: 0.05, blue: 0.30),
        Color(red: 0.05, green: 0.10, blue: 0.35)
    ]

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Ambient orbs
            ambientOrbs

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

    // MARK: - Ambient Orbs
    private var ambientOrbs: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 200)
        }
    }

    // MARK: - Glass Card Modifier
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    // MARK: - Start Screen
    private var startScreen: some View {
        VStack(spacing: 32) {
            Text("🌍")
                .font(.system(size: 90))
                .shadow(color: .blue.opacity(0.6), radius: 20)

            VStack(spacing: 8) {
                Text("Flag Quiz")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(red: 0.7, green: 0.8, blue: 1.0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("Guess the country from its flag!\n10 questions · 10 seconds each")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            glassCard {
                Button(action: { vm.startQuiz() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("Start Quiz")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                }
            }
            .shadow(color: Color.cyan.opacity(0.4), radius: 20)
        }
        .padding(32)
    }

    // MARK: - Game Screen
    private var gameScreen: some View {
        let question = vm.questions[vm.currentIndex]
        return ScrollView {
            VStack(spacing: 20) {
                // Header bar
                glassCard {
                    HStack {
                        Label("\(vm.currentIndex + 1)/10", systemImage: "flag.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        v2TimerView
                        Spacer()
                        Label("\(vm.score)", systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .padding(.horizontal)

                // Flag card
                glassCard {
                    VStack(spacing: 12) {
                        Text(question.flag)
                            .font(.system(size: 80))
                            .scaleEffect(vm.flagScale)
                            .shadow(color: .white.opacity(0.3), radius: 10)

                        Text("Which country is this?")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                }
                .opacity(vm.cardOpacity)
                .padding(.horizontal)

                // Answer buttons
                VStack(spacing: 10) {
                    ForEach(question.choices, id: \.self) { choice in
                        v2AnswerButton(choice, question: question)
                    }
                }
                .opacity(vm.cardOpacity)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
    }

    private var v2TimerView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 46, height: 46)
            Circle()
                .trim(from: 0, to: CGFloat(vm.timeRemaining) / 10.0)
                .stroke(
                    LinearGradient(colors: v2TimerGradient, startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 46, height: 46)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: vm.timeRemaining)
                .shadow(color: v2TimerGradient.first?.opacity(0.6) ?? .clear, radius: 6)
            Text("\(vm.timeRemaining)")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
    }

    private var v2TimerGradient: [Color] {
        vm.timeRemaining > 5 ? [.cyan, .green] : vm.timeRemaining > 3 ? [.yellow, .orange] : [.orange, .red]
    }

    @ViewBuilder
    private func v2AnswerButton(_ choice: String, question: FlagQuestion) -> some View {
        let isSelected = vm.selectedAnswer == choice
        let isCorrect = choice == question.correctAnswer
        let accentColor: Color = {
            if !vm.isAnswered { return .clear }
            if isCorrect { return .green }
            if isSelected { return .red }
            return .clear
        }()
        let showGlow = vm.isAnswered && (isCorrect || isSelected)

        Button(action: { vm.selectAnswer(choice) }) {
            HStack {
                Text(choice)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                if vm.isAnswered {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : ""))
                        .foregroundColor(isCorrect ? .green : .red)
                        .opacity(isCorrect || isSelected ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if vm.isAnswered && (isCorrect || isSelected) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accentColor.opacity(0.25))
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                showGlow ? accentColor.opacity(0.7) : Color.white.opacity(0.1),
                                lineWidth: showGlow ? 1.5 : 1
                            )
                    )
            }
            .shadow(color: showGlow ? accentColor.opacity(0.4) : Color.purple.opacity(0.2), radius: showGlow ? 12 : 6)
        }
        .disabled(vm.isAnswered)
        .animation(.easeInOut(duration: 0.2), value: vm.isAnswered)
    }

    // MARK: - Score Screen
    private var scoreScreen: some View {
        VStack(spacing: 28) {
            Text(v2ScoreEmoji)
                .font(.system(size: 90))
                .shadow(color: .yellow.opacity(0.5), radius: 20)

            glassCard {
                VStack(spacing: 12) {
                    Text("\(vm.score)/10 Correct!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color(red: 0.7, green: 0.85, blue: 1.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    Text(v2ScoreMessage)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
            }
            .shadow(color: Color.cyan.opacity(0.4), radius: 20)

            glassCard {
                Button(action: { vm.startQuiz() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Play Again")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                }
            }
            .shadow(color: Color.purple.opacity(0.4), radius: 20)
        }
        .padding(32)
    }

    private var v2ScoreEmoji: String {
        switch vm.score {
        case 10: return "🏆"
        case 8...9: return "🥇"
        case 6...7: return "🥈"
        case 4...5: return "🥉"
        default: return "📚"
        }
    }

    private var v2ScoreMessage: String {
        switch vm.score {
        case 10: return "Perfect score! Geography master!"
        case 8...9: return "Excellent! Almost flawless!"
        case 6...7: return "Good job! Keep exploring the world."
        case 4...5: return "Not bad! A little more practice helps."
        default: return "Keep studying those flags!"
        }
    }
}
