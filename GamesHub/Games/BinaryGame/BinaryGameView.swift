import SwiftUI

// MARK: - Supporting Types
enum BGmPhase {
    case start, playing, finished
}

struct BGmQuestion {
    let binary: String
    let correct: Int
    let choices: [Int]
}

// MARK: - Main View
struct BinaryGameView: View {
    @State private var phase: BGmPhase = .start
    @State private var questions: [BGmQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showFeedback: Bool = false
    @State private var timeRemaining: Int = 15
    @State private var timer: Timer? = nil

    let totalQuestions = 20

    var currentQuestion: BGmQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            switch phase {
            case .start:
                BGmStartScreen(onStart: startGame)
            case .playing:
                if let q = currentQuestion {
                    BGmPlayScreen(
                        question: q,
                        questionNumber: currentIndex + 1,
                        total: totalQuestions,
                        score: score,
                        timeRemaining: timeRemaining,
                        selectedAnswer: selectedAnswer,
                        showFeedback: showFeedback,
                        onSelect: handleAnswer
                    )
                }
            case .finished:
                BGmResultScreen(score: score, total: totalQuestions, onRestart: resetGame)
            }
        }
    }

    func startGame() {
        questions = (0..<totalQuestions).map { _ in BGmQuestionGenerator.generate() }
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        showFeedback = false
        phase = .playing
        startTimer()
    }

    func startTimer() {
        timeRemaining = 15
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                advanceQuestion()
            }
        }
    }

    func handleAnswer(_ choice: Int) {
        guard !showFeedback, let q = currentQuestion else { return }
        selectedAnswer = choice
        showFeedback = true
        if choice == q.correct { score += 1 }
        timer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            advanceQuestion()
        }
    }

    func advanceQuestion() {
        showFeedback = false
        selectedAnswer = nil
        if currentIndex + 1 >= totalQuestions {
            timer?.invalidate()
            phase = .finished
        } else {
            currentIndex += 1
            startTimer()
        }
    }

    func resetGame() {
        phase = .start
        timer?.invalidate()
    }
}

// MARK: - Question Generator
enum BGmQuestionGenerator {
    static func generate() -> BGmQuestion {
        let bits = Int.random(in: 4...6)
        let maxVal = Int(pow(2.0, Double(bits))) - 1
        let value = Int.random(in: 0...maxVal)
        let binary = String(value, radix: 2).padLeft(toLength: bits, withPad: "0")
        var choices = Set<Int>([value])
        while choices.count < 4 {
            choices.insert(Int.random(in: 0...63))
        }
        return BGmQuestion(binary: binary, correct: value, choices: choices.shuffled())
    }
}

extension String {
    func padLeft(toLength length: Int, withPad pad: String) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: pad, count: padCount) + self
    }
}

// MARK: - Start Screen
struct BGmStartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Text("Binary Blitz")
                .font(.largeTitle).bold()
            Text("Convert binary numbers\nto decimal as fast as you can!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("20 questions • 15s per question")
                .font(.subheadline).foregroundStyle(.secondary)
            Button(action: onStart) {
                Text("Start Game")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }
}

// MARK: - Play Screen
struct BGmPlayScreen: View {
    let question: BGmQuestion
    let questionNumber: Int
    let total: Int
    let score: Int
    let timeRemaining: Int
    let selectedAnswer: Int?
    let showFeedback: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Q \(questionNumber)/\(total)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("Score: \(score)")
                    .font(.subheadline).bold()
                Spacer()
                Text("⏱ \(timeRemaining)s")
                    .font(.subheadline)
                    .foregroundStyle(timeRemaining <= 5 ? .red : .secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(questionNumber), total: Double(total))
                .padding(.horizontal)

            VStack(spacing: 8) {
                Text("What is this binary number?")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(question.binary)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(question.choices, id: \.self) { choice in
                    BGmChoiceButton(
                        value: choice,
                        correct: question.correct,
                        selected: selectedAnswer,
                        showFeedback: showFeedback,
                        onTap: { onSelect(choice) }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Choice Button
struct BGmChoiceButton: View {
    let value: Int
    let correct: Int
    let selected: Int?
    let showFeedback: Bool
    let onTap: () -> Void

    var bgColor: Color {
        guard showFeedback else { return Color(.secondarySystemBackground) }
        if value == correct { return .green.opacity(0.3) }
        if value == selected { return .red.opacity(0.3) }
        return Color(.secondarySystemBackground)
    }

    var body: some View {
        Text("\(value)")
            .font(.title2).bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .onTapGesture { onTap() }
    }
}

// MARK: - Result Screen
struct BGmResultScreen: View {
    let score: Int
    let total: Int
    let onRestart: () -> Void

    var grade: String {
        let pct = Double(score) / Double(total)
        if pct >= 0.9 { return "S" }
        if pct >= 0.7 { return "A" }
        if pct >= 0.5 { return "B" }
        return "C"
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("Results")
                .font(.largeTitle).bold()
            Text("Grade: \(grade)")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(Color.accentColor)
            Text("\(score) / \(total) correct")
                .font(.title2)
            Button(action: onRestart) {
                Text("Play Again")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }
}

#Preview { BinaryGameView() }
