import SwiftUI

enum MBlV2Phase {
    case start, playing, gameOver
}

enum MBlV2Operation {
    case add, subtract, multiply

    func symbol() -> String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        }
    }
}

struct MBlV2Question {
    let a: Int
    let b: Int
    let op: MBlV2Operation
    let answer: Int
    let choices: [Int]

    static func generate(difficulty: Int) -> MBlV2Question {
        let ops: [MBlV2Operation] = [.add, .subtract, .multiply]
        let op = ops[Int.random(in: 0..<ops.count)]
        let range = 5 + difficulty * 4
        var a = Int.random(in: 1...max(1, range))
        var b = Int.random(in: 1...max(1, range))
        if op == .subtract && b > a { swap(&a, &b) }
        let answer: Int
        switch op {
        case .add: answer = a + b
        case .subtract: answer = a - b
        case .multiply: answer = a * b
        }
        var wrongs = Set<Int>()
        while wrongs.count < 3 {
            let offset = Int.random(in: 1...12) * (Bool.random() ? 1 : -1)
            let w = answer + offset
            if w != answer && w >= 0 { wrongs.insert(w) }
        }
        var choices = Array(wrongs) + [answer]
        choices.shuffle()
        return MBlV2Question(a: a, b: b, op: op, answer: answer, choices: choices)
    }
}

struct MathBlitzViewV2: View {
    @State private var phase: MBlV2Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var question: MBlV2Question = MBlV2Question.generate(difficulty: 0)
    @State private var difficulty: Int = 0
    @State private var correctCount: Int = 0
    @State private var questionStartTime: Date = Date()
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = .green
    @State private var feedbackOpacity: Double = 0
    @State private var timer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var timerInterval: Double = 0.1
    @State private var selectedChoice: Int? = nil

    let gradient = LinearGradient(
        colors: [Color(red: 0.1, green: 0.05, blue: 0.3), Color(red: 0.2, green: 0.1, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: playScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("MathBlitz")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Adaptive Difficulty Mode")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: 8) {
                Text("+10 correct  •  -5 wrong")
                Text("Speed bonus for quick answers")
                Text("Difficulty adapts to your skill!")
            }
            .font(.footnote)
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)

            Button(action: startGame) {
                Text("START GAME")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
        .padding()
    }

    var playScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(score)")
                        .font(.title2).bold().foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Text(String(format: "%.1f", timeLeft))
                        .font(.title2).bold()
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            ProgressView(value: timeLeft, total: 30)
                .tint(.purple)
                .padding(.horizontal)

            if difficulty > 0 {
                Text("Level \(difficulty + 1)")
                    .font(.caption).foregroundColor(.purple.opacity(0.9))
            }

            Spacer()

            Text("\(question.a) \(question.op.symbol()) \(question.b) = ?")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

            Text(feedback)
                .font(.title3).bold()
                .foregroundColor(feedbackColor)
                .opacity(feedbackOpacity)
                .frame(height: 28)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    Text("\(choice)")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(selectedChoice == choice ? 0.8 : 0.25), lineWidth: selectedChoice == choice ? 2 : 1))
                        .onTapGesture { handleAnswer(choice) }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Time's Up!")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Final Score")
                    .font(.caption).foregroundColor(.white.opacity(0.6))
                Text("\(score)")
                    .font(.system(size: 56, weight: .black)).foregroundColor(.white)
                Text("Correct answers: \(correctCount)")
                    .foregroundColor(.green.opacity(0.9))
                Text("Max difficulty: Level \(difficulty + 1)")
                    .font(.caption).foregroundColor(.white.opacity(0.6))
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline).foregroundColor(.white)
                    .frame(width: 200, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
    }

    func startGame() {
        score = 0
        timeLeft = 30
        correctCount = 0
        difficulty = 0
        recentResults = []
        timerInterval = 0.1
        selectedChoice = nil
        phase = .playing
        question = MBlV2Question.generate(difficulty: difficulty)
        questionStartTime = Date()
        feedback = ""
        feedbackOpacity = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            timeLeft -= timerInterval
            if timeLeft <= 0 {
                timeLeft = 0
                timer?.invalidate()
                phase = .gameOver
            }
        }
    }

    func checkAdaptiveDifficulty() {
        guard recentResults.count >= 5 else { return }
        let last5 = recentResults.suffix(5)
        let trueCount = last5.filter { $0 }.count
        if trueCount > 4 {
            difficulty = min(difficulty + 1, 6)
            timerInterval = max(0.08, timerInterval * 0.8)
        }
    }

    func handleAnswer(_ choice: Int) {
        selectedChoice = choice
        let elapsed = Date().timeIntervalSince(questionStartTime)
        let correct = choice == question.answer
        recentResults.append(correct)
        if correct {
            let speedBonus = max(0, Int(5 - elapsed))
            score += 10 + speedBonus
            correctCount += 1
            feedback = "+\(10 + speedBonus)"
            feedbackColor = .green
        } else {
            score -= 5
            feedback = "-5"
            feedbackColor = .red
        }
        feedbackOpacity = 1
        withAnimation(.easeOut(duration: 0.7)) { feedbackOpacity = 0 }
        checkAdaptiveDifficulty()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectedChoice = nil
            question = MBlV2Question.generate(difficulty: difficulty)
            questionStartTime = Date()
        }
    }
}

#Preview { MathBlitzViewV2() }
