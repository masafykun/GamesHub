import SwiftUI

// MARK: - Models

enum TRcGamePhase {
    case start, playing, finished
}

struct TRcWordList {
    static let words: [String] = [
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
        "any", "these", "give", "day", "most", "us", "great", "between", "need"
    ]
}

// MARK: - Main View

struct TypeRaceView: View {
    @State private var phase: TRcGamePhase = .start
    @State private var wordQueue: [String] = []
    @State private var currentIndex: Int = 0
    @State private var userInput: String = ""
    @State private var correctWords: Int = 0
    @State private var totalCharsTyped: Int = 0
    @State private var correctCharsTyped: Int = 0
    @State private var startTime: Date = Date()
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
            Color(.systemBackground).ignoresSafeArea()

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

            Text("Type 20 words as fast as you can.\nHit return after each word.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: startGame) {
                Text("Start")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 180, height: 54)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    var playingScreen: some View {
        VStack(spacing: 28) {
            HStack {
                Text("\(currentIndex)/\(totalWords)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(correctWords) correct")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.green)
            }
            .padding(.horizontal)

            Spacer()

            Text(currentWord)
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

            TRcInputField(text: $userInput, onSubmit: submitWord)
                .focused($fieldFocused)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
        .onAppear { fieldFocused = true }
    }

    var finishedScreen: some View {
        VStack(spacing: 24) {
            Text("Finished!")
                .font(.system(size: 40, weight: .bold, design: .rounded))

            VStack(spacing: 12) {
                TRcStatRow(label: "WPM", value: String(format: "%.1f", wpm))
                TRcStatRow(label: "Accuracy", value: String(format: "%.1f%%", accuracy))
                TRcStatRow(label: "Correct Words", value: "\(correctWords)/\(totalWords)")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 180, height: 54)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    // MARK: - Actions

    func startGame() {
        wordQueue = Array(TRcWordList.words.shuffled().prefix(totalWords))
        currentIndex = 0
        userInput = ""
        correctWords = 0
        totalCharsTyped = 0
        correctCharsTyped = 0
        startTime = Date()
        phase = .playing
        fieldFocused = true
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
        }
    }
}

// MARK: - Supporting Views

struct TRcInputField: View {
    @Binding var text: String
    var onSubmit: () -> Void

    var body: some View {
        TextField("Type here...", text: $text)
            .font(.title3.monospaced())
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1.5)
                    )
            )
            .onSubmit { onSubmit() }
            .onChange(of: text) { newValue in
                if newValue.last == " " {
                    text = String(newValue.dropLast())
                    onSubmit()
                }
            }
    }
}

struct TRcStatRow: View {
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

#Preview { TypeRaceView() }
