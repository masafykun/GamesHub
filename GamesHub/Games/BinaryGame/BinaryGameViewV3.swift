import SwiftUI

// MARK: - LCG Seeded RNG
struct BGmLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Supporting Types (V3)
enum BGmV3Phase {
    case start, playing, finished
}

struct BGmV3Question {
    let binary: String
    let correct: Int
    let choices: [Int]
}

// MARK: - Main View V3 (Neumorphism + Seeded Generation)
struct BinaryGameViewV3: View {
    @State private var phase: BGmV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var questions: [BGmV3Question] = []
    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: Int? = nil
    @State private var showFeedback: Bool = false
    @State private var timeRemaining: Int = 15
    @State private var timer: Timer? = nil

    let totalQuestions = 20

    var currentQuestion: BGmV3Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            switch phase {
            case .start:
                BGmV3StartScreen(seedInt: seedInt, onStart: startGame)
            case .playing:
                if let q = currentQuestion {
                    BGmV3PlayScreen(
                        question: q,
                        questionNumber: currentIndex + 1,
                        total: totalQuestions,
                        score: score,
                        timeRemaining: timeRemaining,
                        seedInt: seedInt,
                        selectedAnswer: selectedAnswer,
                        showFeedback: showFeedback,
                        onSelect: handleAnswer
                    )
                }
            case .finished:
                BGmV3ResultScreen(score: score, total: totalQuestions, seedInt: seedInt, onRestart: resetGame)
            }
        }
    }

    func startGame() {
        var rng = BGmLCG(seed: seedInt)
        questions = (0..<totalQuestions).map { _ in BGmV3Generator.generate(rng: &rng) }
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
        seedInt += 1
        phase = .start
        timer?.invalidate()
    }
}

// MARK: - Generator V3
enum BGmV3Generator {
    static func generate(rng: inout BGmLCG) -> BGmV3Question {
        let bits = 4 + rng.nextInt(3) // 4, 5, or 6 bits
        let maxVal = Int(pow(2.0, Double(bits))) - 1
        let value = rng.nextInt(maxVal + 1)
        let binary = String(value, radix: 2).padLeft(toLength: bits, withPad: "0")
        var choices = Set<Int>([value])
        while choices.count < 4 {
            choices.insert(rng.nextInt(64))
        }
        // Shuffle using LCG
        var arr = Array(choices)
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            arr.swapAt(i, j)
        }
        return BGmV3Question(binary: binary, correct: value, choices: arr)
    }
}

// MARK: - Start Screen V3
struct BGmV3StartScreen: View {
    let seedInt: Int
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Binary Blitz")
                    .font(.largeTitle).bold()
                Text("Seeded Edition")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Text("Convert binary to decimal!\n20 questions, 15s each.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            Button(action: onStart) {
                Text("Start Game")
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding(32)
    }
}

// MARK: - Play Screen V3
struct BGmV3PlayScreen: View {
    let question: BGmV3Question
    let questionNumber: Int
    let total: Int
    let score: Int
    let timeRemaining: Int
    let seedInt: Int
    let selectedAnswer: Int?
    let showFeedback: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Q \(questionNumber)/\(total)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Score: \(score)")
                        .font(.headline).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text("\(timeRemaining)s")
                        .font(.title3).bold()
                        .foregroundStyle(timeRemaining <= 5 ? .red : .primary)
                }
            }
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            // Progress
            ProgressView(value: Double(questionNumber), total: Double(total))
                .tint(.blue)
                .padding(.horizontal)

            // Binary display
            VStack(spacing: 8) {
                Text("What is this in decimal?")
                    .font(.caption).foregroundStyle(.secondary)
                Text(question.binary)
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            // Choices
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(question.choices, id: \.self) { choice in
                    BGmV3ChoiceButton(
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

// MARK: - Choice Button V3
struct BGmV3ChoiceButton: View {
    let value: Int
    let correct: Int
    let selected: Int?
    let showFeedback: Bool
    let onTap: () -> Void

    var overlayColor: Color {
        guard showFeedback else { return .clear }
        if value == correct { return .green.opacity(0.2) }
        if value == selected { return .red.opacity(0.2) }
        return .clear
    }

    var body: some View {
        ZStack {
            Text("\(value)")
                .font(.title2).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .neumorphicCard(radius: 14)
            if showFeedback && (value == correct || value == selected) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(overlayColor)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Result Screen V3
struct BGmV3ResultScreen: View {
    let score: Int
    let total: Int
    let seedInt: Int
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

            VStack(spacing: 12) {
                Text(grade)
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(Color.accentColor)
                Text("\(score) / \(total) correct")
                    .font(.title3)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .neumorphicCard(radius: 20)
            .padding(.horizontal)

            Button(action: onRestart) {
                Text("Play Again (New Seed)")
                    .font(.headline)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding()
    }
}

#Preview { BinaryGameViewV3() }
