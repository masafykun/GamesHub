import SwiftUI

// MARK: - Supporting Types ()
enum BGmPhase {
    case start, playing, finished
}

struct BGmQuestion {
    let binary: String
    let correct: Int
    let choices: [Int]
}

// MARK: - Main View  (Glassmorphism + Adaptive Difficulty)
struct BinaryGameView: View {
    @State private var phase: BGmPhase = .start
    @State private var questions: [BGmQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showFeedback: Bool = false
    @State private var timeLimit: Int = 15
    @State private var timeRemaining: Int = 15
    @State private var timer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    let totalQuestions = 20
    let gradient = LinearGradient(
        colors: [Color(red: 0.25, green: 0.1, blue: 0.6), Color(red: 0.1, green: 0.5, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var currentQuestion: BGmQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var effectiveTimeLimit: Int { max(5, Int(Double(timeLimit) / speedMultiplier)) }

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()

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
                        effectiveTimeLimit: effectiveTimeLimit,
                        speedMultiplier: speedMultiplier,
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
        questions = (0..<totalQuestions).map { _ in BGmGenerator.generate(fast: speedMultiplier > 1.2) }
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        showFeedback = false
        phase = .playing
        startTimer()
    }

    func startTimer() {
        timeRemaining = effectiveTimeLimit
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                recordResult(false)
                advanceQuestion()
            }
        }
    }

    func handleAnswer(_ choice: Int) {
        guard !showFeedback, let q = currentQuestion else { return }
        selectedAnswer = choice
        showFeedback = true
        let correct = choice == q.correct
        if correct { score += 1 }
        recordResult(correct)
        timer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            advanceQuestion()
        }
    }

    func recordResult(_ result: Bool) {
        recentResults.append(result)
        if recentResults.count >= 5 {
            let last5 = recentResults.suffix(5)
            let trueCount = last5.filter { $0 }.count
            if trueCount > 4 {
                speedMultiplier = min(speedMultiplier * 1.2, 3.0)
            }
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
        recentResults = []
        speedMultiplier = 1.0
    }
}

// MARK: - Generator 
enum BGmGenerator {
    static func generate(fast: Bool) -> BGmQuestion {
        let bits = fast ? Int.random(in: 5...6) : Int.random(in: 4...6)
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

// MARK: - Glass Card Modifier
struct BGmGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func bgmGlassCard() -> some View {
        modifier(BGmGlassCard())
    }
}

// MARK: - Start Screen 
struct BGmStartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Binary Blitz")
                    .font(.largeTitle).bold().foregroundStyle(.white)
                Text("Adaptive Edition")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Text("Convert binary numbers to decimal.\nThe better you play, the faster it gets!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding()
                .bgmGlassCard()
            Button(action: onStart) {
                Text("Start Game")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.white.opacity(0.2))
                    .bgmGlassCard()
            }
        }
        .padding(32)
    }
}

// MARK: - Play Screen 
struct BGmPlayScreen: View {
    let question: BGmQuestion
    let questionNumber: Int
    let total: Int
    let score: Int
    let timeRemaining: Int
    let effectiveTimeLimit: Int
    let speedMultiplier: Double
    let selectedAnswer: Int?
    let showFeedback: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Q \(questionNumber)/\(total)")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text("Score: \(score)")
                        .font(.headline).bold().foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if speedMultiplier > 1.05 {
                        Text("x\(String(format: "%.1f", speedMultiplier)) speed")
                            .font(.caption).foregroundStyle(.yellow.opacity(0.9))
                    }
                    Text("\(timeRemaining)s")
                        .font(.title3).bold()
                        .foregroundStyle(timeRemaining <= 3 ? .red : .white)
                }
            }
            .padding()
            .bgmGlassCard()

            ProgressView(value: Double(timeRemaining), total: Double(effectiveTimeLimit))
                .tint(.white)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Text("What is this in decimal?")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(question.binary)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .bgmGlassCard()
            .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
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
        .padding(.vertical, 20)
    }
}

// MARK: - Choice Button 
struct BGmChoiceButton: View {
    let value: Int
    let correct: Int
    let selected: Int?
    let showFeedback: Bool
    let onTap: () -> Void

    var borderColor: Color {
        guard showFeedback else { return .white.opacity(0.3) }
        if value == correct { return .green }
        if value == selected { return .red }
        return .white.opacity(0.3)
    }

    var body: some View {
        Text("\(value)")
            .font(.title2).bold().foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: showFeedback && (value == correct || value == selected) ? 2 : 1)
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
            Text("Game Over")
                .font(.largeTitle).bold().foregroundStyle(.white)
            VStack(spacing: 8) {
                Text(grade)
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(.white)
                Text("\(score) / \(total) correct")
                    .font(.title3).foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .bgmGlassCard()
            .padding(.horizontal)

            Button(action: onRestart) {
                Text("Play Again")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.white.opacity(0.2))
                    .bgmGlassCard()
            }
        }
        .padding()
    }
}

#Preview { BinaryGameView() }

extension String {
    func padLeft(toLength length: Int, withPad pad: String) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: pad, count: padCount) + self
    }
}
