import SwiftUI

enum TriviaDifficulty: String, CaseIterable {
    case easy, medium, hard
    var icon: String {
        switch self { case .easy: return "star"; case .medium: return "star.fill"; case .hard: return "flame.fill" }
    }
    var color: Color {
        switch self { case .easy: return .green; case .medium: return .orange; case .hard: return .red }
    }
}

struct TriviaQuestion {
    let text: String
    let options: [String]
    let correctIndex: Int
    var difficulty: TriviaDifficulty = .medium
}

struct TriviaView: View {
    private let questions: [TriviaQuestion] = [
        TriviaQuestion(text: "What is the chemical symbol for gold?", options: ["Ag", "Au", "Fe", "Gd"], correctIndex: 1),
        TriviaQuestion(text: "How many bones are in the adult human body?", options: ["196", "206", "216", "226"], correctIndex: 1),
        TriviaQuestion(text: "Which planet is known as the Red Planet?", options: ["Venus", "Jupiter", "Mars", "Saturn"], correctIndex: 2),
        TriviaQuestion(text: "Who painted the Mona Lisa?", options: ["Michelangelo", "Raphael", "Leonardo da Vinci", "Donatello"], correctIndex: 2),
        TriviaQuestion(text: "What is the speed of light (approx.) in km/s?", options: ["150,000", "300,000", "450,000", "600,000"], correctIndex: 1),
        TriviaQuestion(text: "In what year did World War II end?", options: ["1943", "1944", "1945", "1946"], correctIndex: 2),
        TriviaQuestion(text: "What is the largest ocean on Earth?", options: ["Atlantic", "Indian", "Arctic", "Pacific"], correctIndex: 3),
        TriviaQuestion(text: "Who wrote 'Romeo and Juliet'?", options: ["Charles Dickens", "William Shakespeare", "Jane Austen", "Mark Twain"], correctIndex: 1),
        TriviaQuestion(text: "What is the powerhouse of the cell?", options: ["Nucleus", "Ribosome", "Mitochondria", "Golgi body"], correctIndex: 2),
        TriviaQuestion(text: "Which element has the atomic number 1?", options: ["Helium", "Oxygen", "Hydrogen", "Carbon"], correctIndex: 2),
        TriviaQuestion(text: "What is the capital of Australia?", options: ["Sydney", "Melbourne", "Brisbane", "Canberra"], correctIndex: 3),
        TriviaQuestion(text: "How many sides does a hexagon have?", options: ["5", "6", "7", "8"], correctIndex: 1),
        TriviaQuestion(text: "Which scientist proposed the theory of general relativity?", options: ["Isaac Newton", "Niels Bohr", "Albert Einstein", "Stephen Hawking"], correctIndex: 2),
        TriviaQuestion(text: "In which year did the Titanic sink?", options: ["1910", "1912", "1914", "1916"], correctIndex: 1),
        TriviaQuestion(text: "What is the longest river in the world?", options: ["Amazon", "Yangtze", "Mississippi", "Nile"], correctIndex: 3),
        TriviaQuestion(text: "Which gas makes up most of Earth's atmosphere?", options: ["Oxygen", "Carbon Dioxide", "Nitrogen", "Argon"], correctIndex: 2),
        TriviaQuestion(text: "Who was the first person to walk on the Moon?", options: ["Buzz Aldrin", "Yuri Gagarin", "Neil Armstrong", "John Glenn"], correctIndex: 2),
        TriviaQuestion(text: "What is the smallest prime number?", options: ["0", "1", "2", "3"], correctIndex: 2),
        TriviaQuestion(text: "Which country invented paper?", options: ["Japan", "Egypt", "China", "India"], correctIndex: 2),
        TriviaQuestion(text: "How many planets are in our solar system?", options: ["7", "8", "9", "10"], correctIndex: 1),
    ]

    @State private var currentIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: Int? = nil
    @State private var gameOver: Bool = false
    @State private var timeRemaining: Double = 15.0
    @State private var timer: Foundation.Timer? = nil
    @State private var advanceTimer: Foundation.Timer? = nil

    var currentQuestion: TriviaQuestion {
        questions[currentIndex]
    }

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18)
                .ignoresSafeArea()

            if gameOver {
                TriviaGameOverView(score: score, total: questions.count, onRestart: restartGame)
            } else {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Q \(currentIndex + 1)/\(questions.count)")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("Score: \(score)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal)

                    // Timer bar
                    TriviaTimerBar(timeRemaining: timeRemaining, total: 15.0)
                        .padding(.horizontal)

                    // Question card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 4, y: 4)
                            .shadow(color: .white.opacity(0.05), radius: 6, x: -3, y: -3)

                        Text(currentQuestion.text)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(24)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 130)
                    .padding(.horizontal)

                    // Answer buttons
                    VStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { index in
                            TriviaOptionButton(
                                text: currentQuestion.options[index],
                                index: index,
                                selectedAnswer: selectedAnswer,
                                correctIndex: currentQuestion.correctIndex,
                                onTap: {
                                    handleAnswer(index)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            startQuestion()
        }
        .onDisappear {
            stopTimers()
        }
    }

    private func startQuestion() {
        timeRemaining = 15.0
        selectedAnswer = nil
        stopTimers()

        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                timeExpired()
            }
        }
    }

    private func handleAnswer(_ index: Int) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = index
        timer?.invalidate()
        timer = nil

        if index == currentQuestion.correctIndex {
            score += 1
        }

        scheduleAdvance()
    }

    private func timeExpired() {
        guard selectedAnswer == nil else { return }
        timer?.invalidate()
        timer = nil
        selectedAnswer = -1
        scheduleAdvance()
    }

    private func scheduleAdvance() {
        advanceTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        advanceTimer?.invalidate()
        advanceTimer = nil

        if currentIndex + 1 >= questions.count {
            gameOver = true
        } else {
            currentIndex += 1
            startQuestion()
        }
    }

    private func restartGame() {
        stopTimers()
        currentIndex = 0
        score = 0
        selectedAnswer = nil
        gameOver = false
        startQuestion()
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        advanceTimer?.invalidate()
        advanceTimer = nil
    }
}

struct TriviaTimerBar: View {
    let timeRemaining: Double
    let total: Double

    var fraction: Double {
        max(0, min(1, timeRemaining / total))
    }

    var barColor: Color {
        if fraction > 0.5 { return .green }
        if fraction > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 6)
                    .fill(barColor)
                    .frame(width: geo.size.width * fraction, height: 10)
                    .animation(.linear(duration: 0.1), value: fraction)
            }
        }
        .frame(height: 10)
    }
}

struct TriviaOptionButton: View {
    let text: String
    let index: Int
    let selectedAnswer: Int?
    let correctIndex: Int
    let onTap: () -> Void

    var backgroundColor: Color {
        guard let selected = selectedAnswer else {
            return Color(red: 0.2, green: 0.2, blue: 0.32)
        }
        if index == correctIndex {
            return Color.green.opacity(0.75)
        }
        if index == selected && selected != correctIndex {
            return Color.red.opacity(0.75)
        }
        return Color(red: 0.2, green: 0.2, blue: 0.32).opacity(0.5)
    }

    var borderColor: Color {
        guard let selected = selectedAnswer else {
            return Color.white.opacity(0.1)
        }
        if index == correctIndex {
            return Color.green
        }
        if index == selected && selected != correctIndex {
            return Color.red
        }
        return Color.white.opacity(0.05)
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(["A", "B", "C", "D"][index])
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())

                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                if let selected = selectedAnswer {
                    if index == correctIndex {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if index == selected && selected != correctIndex {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 3)
        }
        .disabled(selectedAnswer != nil)
        .animation(.easeInOut(duration: 0.25), value: selectedAnswer)
    }
}

struct TriviaGameOverView: View {
    let score: Int
    let total: Int
    let onRestart: () -> Void

    var percentage: Int {
        Int(Double(score) / Double(total) * 100)
    }

    var grade: String {
        switch percentage {
        case 90...100: return "Outstanding!"
        case 70..<90: return "Great Job!"
        case 50..<70: return "Not Bad!"
        case 30..<50: return "Keep Practicing"
        default: return "Better Luck Next Time"
        }
    }

    var gradeColor: Color {
        switch percentage {
        case 90...100: return .yellow
        case 70..<90: return .green
        case 50..<70: return .blue
        case 30..<50: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Game Over!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .frame(width: 180, height: 180)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 5, y: 5)
                    .shadow(color: .white.opacity(0.05), radius: 8, x: -4, y: -4)

                VStack(spacing: 6) {
                    Text("\(score)/\(total)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(percentage)%")
                        .font(.title2)
                        .foregroundColor(gradeColor)
                }
            }

            Text(grade)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(gradeColor)

            VStack(spacing: 6) {
                Text("Correct Answers: \(score)")
                    .foregroundColor(.green.opacity(0.9))
                Text("Wrong Answers: \(total - score)")
                    .foregroundColor(.red.opacity(0.9))
            }
            .font(.body)

            Spacer()

            Button(action: onRestart) {
                Text("Play Again")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
