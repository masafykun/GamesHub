import SwiftUI

// MARK: - LCG Random

struct TRcLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

enum TRcV3Phase {
    case start, playing, finished
}

struct TRcV3WordBank {
    static let common: [String] = [
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
        "any", "these", "give", "day", "most", "between", "result", "process",
        "system", "reflect", "journey", "balance", "dynamic", "method", "factor"
    ]

    static func generate(seed: Int, count: Int) -> [String] {
        var rng = TRcLCG(seed: seed)
        var pool = common
        var result: [String] = []
        while result.count < count && !pool.isEmpty {
            let idx = rng.nextInt(pool.count)
            result.append(pool[idx])
            pool.remove(at: idx)
            if pool.isEmpty { pool = common }
        }
        return result
    }
}

struct TRcV3LetterState: Identifiable {
    let id = UUID()
    let char: Character
    var status: TRcV3LetterStatus = .pending
}

enum TRcV3LetterStatus {
    case pending, correct, incorrect
}

// MARK: - Main View

struct TypeRaceViewV3: View {
    @State private var phase: TRcV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var wordQueue: [String] = []
    @State private var currentIndex: Int = 0
    @State private var userInput: String = ""
    @State private var correctWords: Int = 0
    @State private var totalCharsTyped: Int = 0
    @State private var correctCharsTyped: Int = 0
    @State private var startTime: Date = Date()
    @State private var letterStates: [TRcV3LetterState] = []
    @FocusState private var fieldFocused: Bool

    private let totalWords = 20

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

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
            Text("TypeRace")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                Text("Seeded Edition")
                    .font(.caption)
                    .tracking(2)
                    .foregroundColor(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            VStack(spacing: 12) {
                Text("Type 20 words as fast as you can.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Each run uses a unique seed for reproducible word order.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            Button(action: startGame) {
                Text("Start")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .frame(width: 180, height: 54)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding()
    }

    var playingScreen: some View {
        VStack(spacing: 24) {
            HStack {
                Text("\(currentIndex)/\(totalWords)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text("\(correctWords) correct")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            TRcV3ProgressDots(current: currentIndex, total: totalWords)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 16) {
                TRcV3LetterDisplay(letters: letterStates)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .neumorphicCard(radius: 20)
                    .padding(.horizontal)

                TextField("Type here...", text: $userInput)
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .padding(14)
                    .neumorphicCard(radius: 14)
                    .padding(.horizontal)
                    .onSubmit { submitWord() }
                    .onChange(of: userInput) { newValue in
                        updateLetterStates(input: newValue)
                        if newValue.last == " " {
                            userInput = String(newValue.dropLast())
                            submitWord()
                        }
                    }
            }

            Spacer()
        }
        .padding(.vertical)
        .onAppear { fieldFocused = true }
    }

    var finishedScreen: some View {
        VStack(spacing: 24) {
            Text("Finished!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("SEED: #\(seedInt - 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            VStack(spacing: 14) {
                TRcV3ResultRow(label: "WPM", value: String(format: "%.1f", wpm))
                Divider()
                TRcV3ResultRow(label: "Accuracy", value: String(format: "%.1f%%", accuracy))
                Divider()
                TRcV3ResultRow(label: "Correct Words", value: "\(correctWords)/\(totalWords)")
            }
            .padding(20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .frame(width: 180, height: 54)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding()
    }

    // MARK: - Actions

    func startGame() {
        wordQueue = TRcV3WordBank.generate(seed: seedInt, count: totalWords)
        currentIndex = 0
        userInput = ""
        correctWords = 0
        totalCharsTyped = 0
        correctCharsTyped = 0
        startTime = Date()
        phase = .playing
        fieldFocused = true
        refreshLetterStates()
    }

    func refreshLetterStates() {
        letterStates = currentWord.map { TRcV3LetterState(char: $0) }
    }

    func updateLetterStates(input: String) {
        let word = currentWord
        letterStates = word.enumerated().map { i, ch in
            var state = TRcV3LetterState(char: ch)
            if i < input.count {
                let inputChar = input[input.index(input.startIndex, offsetBy: i)]
                state.status = inputChar == ch ? .correct : .incorrect
            }
            return state
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
        if typed == target { correctWords += 1 }
        userInput = ""
        currentIndex += 1
        if currentIndex >= totalWords {
            phase = .finished
            fieldFocused = false
            seedInt += 1
        } else {
            refreshLetterStates()
        }
    }
}

// MARK: - Supporting Views

struct TRcV3LetterDisplay: View {
    let letters: [TRcV3LetterState]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(letters) { letter in
                Text(String(letter.char))
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundColor(colorFor(letter.status))
                    .animation(.easeInOut(duration: 0.1), value: letter.status)
            }
        }
    }

    func colorFor(_ status: TRcV3LetterStatus) -> Color {
        switch status {
        case .pending: return .primary
        case .correct: return .green
        case .incorrect: return .red
        }
    }
}

struct TRcV3ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let dotSize: CGFloat = 6
            let spacing: CGFloat = 4
            let dotsPerRow = Int((geo.size.width + spacing) / (dotSize + spacing))
            let rows = Int(ceil(Double(total) / Double(max(1, dotsPerRow))))
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<dotsPerRow, id: \.self) { col in
                            let idx = row * dotsPerRow + col
                            if idx < total {
                                Circle()
                                    .fill(idx < current ? Color.blue : Color(.systemGray4))
                                    .frame(width: dotSize, height: dotSize)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(height: 20)
    }
}

struct TRcV3ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
    }
}

#Preview { TypeRaceViewV3() }
