import SwiftUI

// MARK: - Models

enum TRcV2Phase {
    case start, playing, finished
}

struct TRcV2Words {
    static let pool: [String] = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "it",
        "for", "not", "on", "with", "he", "as", "you", "do", "at", "this",
        "but", "his", "by", "from", "they", "we", "say", "her", "she", "or",
        "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him", "know",
        "take", "people", "into", "year", "your", "good", "some", "could",
        "them", "see", "other", "than", "then", "now", "look", "only", "come",
        "its", "over", "think", "also", "back", "after", "use", "two", "how",
        "our", "work", "first", "well", "way", "even", "new", "want", "because",
        "any", "these", "give", "day", "most", "between", "journey", "reflect",
        "dynamic", "system", "process", "result", "method", "factor", "balance"
    ]
}

struct TRcDifficultyConfig {
    var timeLimitEnabled: Bool
    var timeLimit: Double  // seconds per word, 0 = no limit
    var minWordLength: Int

    static let easy = TRcDifficultyConfig(timeLimitEnabled: false, timeLimit: 0, minWordLength: 0)

    func increased() -> TRcDifficultyConfig {
        TRcDifficultyConfig(
            timeLimitEnabled: true,
            timeLimit: max(2.0, (timeLimit == 0 ? 5.0 : timeLimit) * 0.8),
            minWordLength: minWordLength + 1
        )
    }
}

// MARK: - Main View

struct TypeRaceViewV2: View {
    @State private var phase: TRcV2Phase = .start
    @State private var wordQueue: [String] = []
    @State private var currentIndex: Int = 0
    @State private var userInput: String = ""
    @State private var correctWords: Int = 0
    @State private var totalCharsTyped: Int = 0
    @State private var correctCharsTyped: Int = 0
    @State private var startTime: Date = Date()
    @State private var recentResults: [Bool] = []
    @State private var config: TRcDifficultyConfig = .easy
    @State private var wordStartTime: Date = Date()
    @State private var timeRemaining: Double = 0
    @State private var timer: Timer? = nil
    @FocusState private var fieldFocused: Bool

    private let totalWords = 20
    private let gradientColors: [Color] = [Color(red: 0.3, green: 0.1, blue: 0.7), Color(red: 0.1, green: 0.4, blue: 0.9)]

    var currentWord: String {
        guard currentIndex < wordQueue.count else { return "" }
        return wordQueue[currentIndex]
    }

    var wpm: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 0 else { return 0 }
        return Double(correctWords) / elapsed * 60.0
    }

    var accuracy: Double {
        guard totalCharsTyped > 0 else { return 100.0 }
        return Double(correctCharsTyped) / Double(totalCharsTyped) * 100.0
    }

    var difficultyLabel: String {
        if !config.timeLimitEnabled { return "Easy" }
        let limit = config.timeLimit
        if limit >= 4 { return "Medium" }
        if limit >= 3 { return "Hard" }
        return "Expert"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                playingScreen
            case .finished:
                finishedScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("TypeRace")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Adaptive Edition")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2)
            }

            glassCard {
                VStack(spacing: 10) {
                    Text("Type 20 words as fast as you can.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                    Text("Performance-based difficulty adapts in real-time.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }

            Button(action: startGame) {
                Text("Start Racing")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(width: 200, height: 52)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding()
    }

    var playingScreen: some View {
        VStack(spacing: 20) {
            HStack {
                glassTag(text: "\(currentIndex)/\(totalWords)")
                Spacer()
                glassTag(text: difficultyLabel)
                Spacer()
                glassTag(text: "\(correctWords) correct")
            }
            .padding(.horizontal)

            if config.timeLimitEnabled && timeRemaining > 0 {
                TRcV2TimerBar(progress: timeRemaining / config.timeLimit, color: timeBarColor)
                    .frame(height: 6)
                    .padding(.horizontal)
            }

            Spacer()

            glassCard {
                Text(currentWord)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal)

            glassCard {
                TextField("Type here...", text: $userInput)
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .onSubmit { submitWord() }
                    .onChange(of: userInput) { newValue in
                        if newValue.last == " " {
                            userInput = String(newValue.dropLast())
                            submitWord()
                        }
                    }
                    .padding(.vertical, 4)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
        .onAppear { fieldFocused = true }
    }

    var finishedScreen: some View {
        VStack(spacing: 24) {
            Text("Race Over!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            glassCard {
                VStack(spacing: 16) {
                    TRcV2ResultRow(label: "WPM", value: String(format: "%.1f", wpm), color: .yellow)
                    TRcV2ResultRow(label: "Accuracy", value: String(format: "%.1f%%", accuracy), color: .green)
                    TRcV2ResultRow(label: "Correct", value: "\(correctWords)/\(totalWords)", color: .white)
                    TRcV2ResultRow(label: "Peak Difficulty", value: difficultyLabel, color: .orange)
                }
                .padding(8)
            }
            .padding(.horizontal)

            Button(action: startGame) {
                Text("Race Again")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(width: 200, height: 52)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding()
    }

    // MARK: - Glass Helpers

    @ViewBuilder
    func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    func glassTag(text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    var timeBarColor: Color {
        guard config.timeLimit > 0 else { return .green }
        let ratio = timeRemaining / config.timeLimit
        if ratio > 0.6 { return .green }
        if ratio > 0.3 { return .yellow }
        return .red
    }

    // MARK: - Actions

    func startGame() {
        let filtered = config.minWordLength > 0
            ? TRcV2Words.pool.filter { $0.count >= config.minWordLength }
            : TRcV2Words.pool
        let source = filtered.isEmpty ? TRcV2Words.pool : filtered
        wordQueue = Array(source.shuffled().prefix(totalWords))
        currentIndex = 0
        userInput = ""
        correctWords = 0
        totalCharsTyped = 0
        correctCharsTyped = 0
        recentResults = []
        config = .easy
        startTime = Date()
        phase = .playing
        fieldFocused = true
        startWordTimer()
    }

    func startWordTimer() {
        timer?.invalidate()
        timer = nil
        wordStartTime = Date()
        guard config.timeLimitEnabled, config.timeLimit > 0 else { return }
        timeRemaining = config.timeLimit
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(wordStartTime)
            timeRemaining = max(0, config.timeLimit - elapsed)
            if timeRemaining <= 0 {
                skipWord(correct: false)
            }
        }
    }

    func skipWord(correct: Bool) {
        timer?.invalidate()
        timer = nil
        recentResults.append(correct)
        if !correct {
            totalCharsTyped += currentWord.count
        }
        userInput = ""
        currentIndex += 1
        checkDifficultyAdaptation()
        if currentIndex >= totalWords {
            phase = .finished
            fieldFocused = false
        } else {
            startWordTimer()
        }
    }

    func submitWord() {
        let typed = userInput.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return }

        let target = currentWord
        totalCharsTyped += typed.count
        let matchLen = min(typed.count, target.count)
        var correct = 0
        for i in 0..<matchLen {
            if typed[typed.index(typed.startIndex, offsetBy: i)] ==
               target[target.index(target.startIndex, offsetBy: i)] {
                correct += 1
            }
        }
        correctCharsTyped += correct
        let isCorrect = typed == target
        if isCorrect { correctWords += 1 }
        skipWord(correct: isCorrect)
    }

    func checkDifficultyAdaptation() {
        guard recentResults.count >= 5 else { return }
        let last5 = recentResults.suffix(5)
        let trueCount = last5.filter { $0 }.count
        if trueCount > 4 {
            config = config.increased()
            recentResults = []
        }
    }
}

// MARK: - Supporting Views

struct TRcV2TimerBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
                    .animation(.linear(duration: 0.05), value: progress)
            }
        }
    }
}

struct TRcV2ResultRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
    }
}

#Preview { TypeRaceViewV2() }
