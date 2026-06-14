import SwiftUI

struct MBlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum MBlV3Phase {
    case start, playing, gameOver
}

struct MBlV3Question {
    let a: Int
    let b: Int
    let opSymbol: String
    let answer: Int
    let choices: [Int]

    static func generate(lcg: inout MBlLCG, difficulty: Int) -> MBlV3Question {
        let opIdx = lcg.nextInt(3)
        let opSymbol: String
        let range = 5 + difficulty * 3
        var a = lcg.nextInt(max(1, range)) + 1
        var b = lcg.nextInt(max(1, range)) + 1
        let answer: Int
        switch opIdx {
        case 0:
            opSymbol = "+"
            answer = a + b
        case 1:
            opSymbol = "−"
            if b > a { let t = a; a = b; b = t }
            answer = a - b
        default:
            opSymbol = "×"
            answer = a * b
        }
        var wrongs = Set<Int>()
        while wrongs.count < 3 {
            let offset = lcg.nextInt(10) + 1
            let sign: Int = lcg.nextInt(2) == 0 ? 1 : -1
            let w = answer + offset * sign
            if w != answer && w >= 0 { wrongs.insert(w) }
        }
        var choices = Array(wrongs) + [answer]
        // Shuffle choices via LCG Fisher-Yates
        for i in stride(from: choices.count - 1, through: 1, by: -1) {
            let j = lcg.nextInt(i + 1)
            choices.swapAt(i, j)
        }
        return MBlV3Question(a: a, b: b, opSymbol: opSymbol, answer: answer, choices: choices)
    }
}

struct MathBlitzViewV3: View {
    @State private var phase: MBlV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var lcg: MBlLCG = MBlLCG(seed: 1)
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var question: MBlV3Question = {
        var g = MBlLCG(seed: 1)
        return MBlV3Question.generate(lcg: &g, difficulty: 0)
    }()
    @State private var difficulty: Int = 0
    @State private var correctCount: Int = 0
    @State private var questionStartTime: Date = Date()
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = .green
    @State private var feedbackOpacity: Double = 0
    @State private var timer: Timer? = nil
    @State private var pressedChoice: Int? = nil

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
                Text("Seeded Procedural Edition")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(28)
            .neumorphicCard(radius: 20)

            VStack(spacing: 8) {
                Text("+10 correct  •  -5 wrong")
                Text("Speed bonus for quick answers")
                Text("Reproducible with seed numbers!")
            }
            .font(.footnote)
            .foregroundColor(Color(.secondaryLabel))
            .multilineTextAlignment(.center)

            Button(action: startGame) {
                Text("START")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .frame(width: 180, height: 54)
                    .neumorphicCard(radius: 16)
            }
        }
        .padding()
    }

    var playScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.caption2).foregroundColor(Color(.tertiaryLabel))
                    Text("\(score)")
                        .font(.title2).bold().foregroundColor(Color(.label))
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.caption2).foregroundColor(Color(.tertiaryLabel))
                    Text(String(format: "%.1f", timeLeft))
                        .font(.title2).bold()
                        .foregroundColor(timeLeft < 10 ? .red : Color(.label))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            ProgressView(value: timeLeft, total: 30)
                .tint(Color(.systemIndigo))
                .padding(.horizontal)

            Spacer()

            Text("\(question.a) \(question.opSymbol) \(question.b) = ?")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .neumorphicCard(radius: 20)
                .padding(.horizontal)

            Text(feedback)
                .font(.title3).bold()
                .foregroundColor(feedbackColor)
                .opacity(feedbackOpacity)
                .frame(height: 28)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(question.choices, id: \.self) { choice in
                    Text("\(choice)")
                        .font(.title2).bold()
                        .foregroundColor(Color(.label))
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .neumorphicCard(radius: 16)
                        .scaleEffect(pressedChoice == choice ? 0.95 : 1.0)
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
                    .foregroundColor(Color(.label))
                Text("Final Score")
                    .font(.caption).foregroundColor(Color(.secondaryLabel))
                Text("\(score)")
                    .font(.system(size: 56, weight: .black)).foregroundColor(Color(.label))
                Text("Correct: \(correctCount)")
                    .foregroundColor(.green)
                Text("Difficulty reached: Level \(difficulty + 1)")
                    .font(.caption).foregroundColor(Color(.secondaryLabel))
                Text("Played seed: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(28)
            .neumorphicCard(radius: 24)
            .padding(.horizontal)

            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .frame(width: 200, height: 54)
                    .neumorphicCard(radius: 16)
            }
        }
    }

    func startGame() {
        seedInt += 1
        lcg = MBlLCG(seed: seedInt)
        score = 0
        timeLeft = 30
        correctCount = 0
        difficulty = 0
        phase = .playing
        question = MBlV3Question.generate(lcg: &lcg, difficulty: difficulty)
        questionStartTime = Date()
        feedback = ""
        feedbackOpacity = 0
        pressedChoice = nil
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
        pressedChoice = choice
        withAnimation(.easeOut(duration: 0.15)) { pressedChoice = nil }
        let elapsed = Date().timeIntervalSince(questionStartTime)
        if choice == question.answer {
            let speedBonus = max(0, Int(5 - elapsed))
            score += 10 + speedBonus
            correctCount += 1
            feedback = "+\(10 + speedBonus)"
            feedbackColor = .green
            difficulty = correctCount / 4
        } else {
            score -= 5
            feedback = "-5"
            feedbackColor = .red
        }
        feedbackOpacity = 1
        withAnimation(.easeOut(duration: 0.8)) { feedbackOpacity = 0 }
        question = MBlV3Question.generate(lcg: &lcg, difficulty: difficulty)
        questionStartTime = Date()
    }
}

#Preview { MathBlitzViewV3() }
