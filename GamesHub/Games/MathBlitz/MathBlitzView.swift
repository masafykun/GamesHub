import SwiftUI

enum MBlGamePhase {
    case start, playing, gameOver
}

enum MBlOperation {
    case add, subtract, multiply

    func symbol() -> String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        }
    }
}

struct MBlQuestion {
    let a: Int
    let b: Int
    let op: MBlOperation
    let answer: Int
    let choices: [Int]

    static func generate(difficulty: Int) -> MBlQuestion {
        let ops: [MBlOperation] = [.add, .subtract, .multiply]
        let op = ops[Int.random(in: 0..<ops.count)]
        let range = 5 + difficulty * 3
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
            let offset = Int.random(in: 1...10) * (Bool.random() ? 1 : -1)
            let w = answer + offset
            if w != answer && w >= 0 { wrongs.insert(w) }
        }
        var choices = Array(wrongs) + [answer]
        choices.shuffle()
        return MBlQuestion(a: a, b: b, op: op, answer: answer, choices: choices)
    }
}

struct MathBlitzView: View {
    @State private var phase: MBlGamePhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var question: MBlQuestion = MBlQuestion.generate(difficulty: 0)
    @State private var difficulty: Int = 0
    @State private var correctCount: Int = 0
    @State private var questionStartTime: Date = Date()
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = .green
    @State private var timer: Timer? = nil
    @State private var feedbackOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: playScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("MathBlitz")
                .font(.system(size: 44, weight: .black))
                .foregroundColor(.yellow)
            Text("Answer fast!\n+10 correct  -5 wrong\nSpeed bonus for quick answers")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .font(.subheadline)
            Button(action: startGame) {
                Text("START")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(width: 180, height: 52)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    var playScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Score: \(score)")
                    .font(.headline).foregroundColor(.yellow)
                Spacer()
                Text(String(format: "⏱ %.1f", timeLeft))
                    .font(.headline).foregroundColor(timeLeft < 10 ? .red : .white)
            }
            .padding(.horizontal)

            ProgressView(value: timeLeft, total: 30)
                .tint(timeLeft < 10 ? .red : .yellow)
                .padding(.horizontal)

            Spacer()

            Text("\(question.a) \(question.op.symbol()) \(question.b) = ?")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            Text(feedback)
                .font(.title2).bold()
                .foregroundColor(feedbackColor)
                .opacity(feedbackOpacity)
                .frame(height: 32)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(question.choices, id: \.self) { choice in
                    Text("\(choice)")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            Text("Time's Up!")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.yellow)
            Text("Score: \(score)")
                .font(.largeTitle).bold().foregroundColor(.white)
            Text("Correct: \(correctCount)")
                .foregroundColor(.green)
            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline).foregroundColor(.black)
                    .frame(width: 180, height: 52)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    func startGame() {
        score = 0
        timeLeft = 30
        correctCount = 0
        difficulty = 0
        phase = .playing
        question = MBlQuestion.generate(difficulty: difficulty)
        questionStartTime = Date()
        feedback = ""
        feedbackOpacity = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeLeft -= 0.1
            if timeLeft <= 0 {
                timeLeft = 0
                timer?.invalidate()
                phase = .gameOver
            }
        }
    }

    func handleAnswer(_ choice: Int) {
        let elapsed = Date().timeIntervalSince(questionStartTime)
        if choice == question.answer {
            let speedBonus = max(0, Int(5 - elapsed))
            score += 10 + speedBonus
            correctCount += 1
            feedback = "+\(10 + speedBonus)"
            feedbackColor = .green
            difficulty = correctCount / 3
        } else {
            score -= 5
            feedback = "-5"
            feedbackColor = .red
        }
        feedbackOpacity = 1
        withAnimation(.easeOut(duration: 0.8)) { feedbackOpacity = 0 }
        question = MBlQuestion.generate(difficulty: difficulty)
        questionStartTime = Date()
    }
}

#Preview { MathBlitzView() }
