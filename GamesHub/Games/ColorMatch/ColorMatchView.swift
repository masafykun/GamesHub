import SwiftUI

// MARK: - Models

struct ColorMatchQuestion {
    let word: String
    let wordColor: Color
    let isMatch: Bool
}

enum ColorMatchNamedColor: CaseIterable {
    case red, green, blue, yellow, orange, purple

    var name: String {
        switch self {
        case .red: return "RED"
        case .green: return "GREEN"
        case .blue: return "BLUE"
        case .yellow: return "YELLOW"
        case .orange: return "ORANGE"
        case .purple: return "PURPLE"
        }
    }

    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

// MARK: - Game State

enum ColorMatchGameState {
    case idle
    case playing
    case finished
}

// MARK: - ViewModel

class ColorMatchViewModel: ObservableObject {
    static let totalQuestions = 30
    static let questionDuration: Double = 2.0

    @Published var gameState: ColorMatchGameState = .idle
    @Published var currentQuestion: ColorMatchQuestion? = nil
    @Published var questionIndex: Int = 0
    @Published var score: Int = 0
    @Published var streak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var timeRemaining: Double = ColorMatchViewModel.questionDuration
    @Published var feedbackText: String = ""
    @Published var showFeedback: Bool = false
    @Published var feedbackCorrect: Bool = true

    private var timer: Timer?
    private var questions: [ColorMatchQuestion] = []
    private var answered: Bool = false

    func startGame() {
        questions = ColorMatchViewModel.generateQuestions()
        questionIndex = 0
        score = 0
        streak = 0
        bestStreak = 0
        gameState = .playing
        loadQuestion()
    }

    func resetGame() {
        timer?.invalidate()
        timer = nil
        gameState = .idle
        currentQuestion = nil
        showFeedback = false
        feedbackText = ""
    }

    func answer(yes: Bool) {
        guard gameState == .playing, !answered, let question = currentQuestion else { return }
        answered = true
        let correct = (yes == question.isMatch)
        if correct {
            score += 1
            streak += 1
            if streak > bestStreak { bestStreak = streak }
            feedbackText = "Correct!"
            feedbackCorrect = true
        } else {
            streak = 0
            feedbackText = "Wrong!"
            feedbackCorrect = false
        }
        showFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.advanceQuestion()
        }
    }

    private func loadQuestion() {
        guard questionIndex < questions.count else {
            endGame()
            return
        }
        answered = false
        showFeedback = false
        currentQuestion = questions[questionIndex]
        timeRemaining = ColorMatchViewModel.questionDuration
        startTimer()
    }

    private func advanceQuestion() {
        timer?.invalidate()
        timer = nil
        questionIndex += 1
        if questionIndex >= questions.count {
            endGame()
        } else {
            loadQuestion()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = 1.0 / 60.0
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.timeRemaining -= interval
                if self.timeRemaining <= 0 && !self.answered {
                    self.answered = true
                    self.streak = 0
                    self.feedbackText = "Too slow!"
                    self.feedbackCorrect = false
                    self.showFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.advanceQuestion()
                    }
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        gameState = .finished
    }

    static func generateQuestions() -> [ColorMatchQuestion] {
        let allColors = ColorMatchNamedColor.allCases
        var result: [ColorMatchQuestion] = []
        for _ in 0..<totalQuestions {
            let wordColor = allColors.randomElement()!
            let isMatch = Bool.random()
            let displayColor: ColorMatchNamedColor
            if isMatch {
                displayColor = wordColor
            } else {
                var other = allColors.randomElement()!
                while other == wordColor {
                    other = allColors.randomElement()!
                }
                displayColor = other
            }
            result.append(ColorMatchQuestion(
                word: wordColor.name,
                wordColor: displayColor.color,
                isMatch: isMatch
            ))
        }
        return result
    }
}

// MARK: - Main View

struct ColorMatchView: View {
    @StateObject private var viewModel = ColorMatchViewModel()

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            switch viewModel.gameState {
            case .idle:
                ColorMatchStartScreen(viewModel: viewModel)
            case .playing:
                ColorMatchGameScreen(viewModel: viewModel)
            case .finished:
                ColorMatchResultScreen(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Start Screen

struct ColorMatchStartScreen: View {
    @ObservedObject var viewModel: ColorMatchViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("COLOR")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                Text("MATCH")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.red)
            }

            Text("Does the WORD match the COLOR?")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("30 questions · 2 seconds each")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Tap YES or NO as fast as you can!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { viewModel.startGame() }) {
                Text("START GAME")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                    )
                    .padding(.horizontal, 40)
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Game Screen

struct ColorMatchGameScreen: View {
    @ObservedObject var viewModel: ColorMatchViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(viewModel.questionIndex + 1) / \(ColorMatchViewModel.totalQuestions)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ColorMatchTimerBar(progress: viewModel.timeRemaining / ColorMatchViewModel.questionDuration)
                        .frame(width: 80, height: 8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                        Text("\(viewModel.streak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Spacer()

            // Question card
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(color: .white.opacity(0.8), radius: 8, x: -4, y: -4)
                    .shadow(color: Color(.systemGray4), radius: 8, x: 4, y: 4)

                if let question = viewModel.currentQuestion {
                    VStack(spacing: 16) {
                        Text("What color is this word?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(question.word)
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundColor(question.wordColor)
                            .shadow(color: question.wordColor.opacity(0.3), radius: 8, x: 0, y: 4)

                        Text("Does the word match its color?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                }

                // Feedback overlay
                if viewModel.showFeedback {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(viewModel.feedbackCorrect ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                    Text(viewModel.feedbackText)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 240)
            .padding(.horizontal, 24)

            Spacer()

            // YES / NO buttons
            HStack(spacing: 24) {
                Button(action: { viewModel.answer(yes: false) }) {
                    Text("NO")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red)
                                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }

                Button(action: { viewModel.answer(yes: true) }) {
                    Text("YES")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.green)
                                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Timer Bar

struct ColorMatchTimerBar: View {
    let progress: Double

    var barColor: Color {
        if progress > 0.5 { return .green }
        if progress > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(max(0, progress)))
                    .animation(.linear(duration: 1.0 / 60.0), value: progress)
            }
        }
    }
}

// MARK: - Result Screen

struct ColorMatchResultScreen: View {
    @ObservedObject var viewModel: ColorMatchViewModel

    var grade: String {
        let pct = Double(viewModel.score) / Double(ColorMatchViewModel.totalQuestions)
        switch pct {
        case 0.9...: return "S"
        case 0.75...: return "A"
        case 0.6...: return "B"
        case 0.4...: return "C"
        default: return "D"
        }
    }

    var gradeColor: Color {
        switch grade {
        case "S": return .purple
        case "A": return .blue
        case "B": return .green
        case "C": return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Game Over!")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            // Grade badge
            ZStack {
                Circle()
                    .fill(gradeColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(gradeColor, lineWidth: 4)
                    .frame(width: 120, height: 120)
                Text(grade)
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundColor(gradeColor)
            }

            // Stats
            VStack(spacing: 16) {
                ColorMatchStatRow(label: "Score", value: "\(viewModel.score) / \(ColorMatchViewModel.totalQuestions)")
                ColorMatchStatRow(label: "Accuracy", value: String(format: "%.0f%%", Double(viewModel.score) / Double(ColorMatchViewModel.totalQuestions) * 100))
                ColorMatchStatRow(label: "Best Streak", value: "\(viewModel.bestStreak)")
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .shadow(color: .white.opacity(0.8), radius: 6, x: -3, y: -3)
                    .shadow(color: Color(.systemGray4), radius: 6, x: 3, y: 3)
            )
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                Button(action: { viewModel.startGame() }) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        )
                        .padding(.horizontal, 40)
                }

                Button(action: { viewModel.resetGame() }) {
                    Text("MAIN MENU")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Stat Row

struct ColorMatchStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}
