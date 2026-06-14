import SwiftUI

// MARK: - Word List
let wordleWordList = ["SWIFT", "CRANE", "SLATE", "APPLE", "BRAVE", "FLAME", "GHOST", "HONEY", "IVORY", "JOKER", "KNIFE", "LEMON", "MAPLE", "NIGHT", "OCEAN", "PIANO", "QUEST", "RIVER", "STONE", "TOWER", "ULTRA", "VAPOR", "WITTY", "XENON", "YACHT", "ZEBRA", "BREAD", "CLOUD", "DANCE", "EARTH", "FRESH", "GRAPE", "HAPPY", "IDEAL", "JUICE", "KINGS", "LIGHT", "MOUNT", "NOVEL", "OUTER", "PEACH", "QUEEN", "ROYAL", "SUGAR", "TIGER", "UNDER", "VIOLA", "WATCH", "EXTRA", "YUMMY", "AMBER", "BLOOM", "CRISP", "DRANK", "EAGLE", "FROWN", "GIANT", "HOTEL", "INPUT", "JAZZY"]

// MARK: - Enums

enum WordleTileState {
    case empty
    case correct
    case present
    case absent

    var backgroundColor: Color {
        switch self {
        case .empty:   return Color(.systemBackground)
        case .correct: return Color(red: 0.38, green: 0.65, blue: 0.40) // green
        case .present: return Color(red: 0.79, green: 0.69, blue: 0.29) // yellow
        case .absent:  return Color(red: 0.47, green: 0.49, blue: 0.51) // gray
        }
    }

    var foregroundColor: Color {
        switch self {
        case .empty:   return .primary
        default:       return .white
        }
    }

    var borderColor: Color {
        switch self {
        case .empty: return Color(.systemGray3)
        default:     return .clear
        }
    }
}

// MARK: - Models

struct WordleGuess {
    var letters: [String]
    var states: [WordleTileState]

    init() {
        letters = Array(repeating: "", count: 5)
        states  = Array(repeating: .empty, count: 5)
    }
}

// MARK: - ViewModel

class WordleViewModel: ObservableObject {
    @Published var guesses: [WordleGuess] = Array(repeating: WordleGuess(), count: 6)
    @Published var currentRow: Int = 0
    @Published var currentCol: Int = 0
    @Published var gameState: WordleGameState = .playing
    @Published var targetWord: String = ""
    @Published var letterKeyStates: [String: WordleTileState] = [:]

    init() {
        startNewGame()
    }

    func startNewGame() {
        guesses      = Array(repeating: WordleGuess(), count: 6)
        currentRow   = 0
        currentCol   = 0
        gameState    = .playing
        targetWord   = wordleWordList.randomElement() ?? "SWIFT"
        letterKeyStates = [:]
    }

    func typeLetter(_ letter: String) {
        guard gameState == .playing, currentCol < 5 else { return }
        guesses[currentRow].letters[currentCol] = letter
        currentCol += 1
    }

    func deleteLetter() {
        guard gameState == .playing, currentCol > 0 else { return }
        currentCol -= 1
        guesses[currentRow].letters[currentCol] = ""
    }

    func submitGuess() {
        guard gameState == .playing, currentCol == 5 else { return }

        let guess = guesses[currentRow].letters.joined()
        let result = evaluate(guess: guess, target: targetWord)
        guesses[currentRow].states = result

        // Update key states — correct > present > absent
        for (i, letter) in guesses[currentRow].letters.enumerated() {
            let newState = result[i]
            if let existing = letterKeyStates[letter] {
                if existing != .correct {
                    if newState == .correct || (newState == .present && existing == .absent) {
                        letterKeyStates[letter] = newState
                    }
                }
            } else {
                letterKeyStates[letter] = newState
            }
        }

        if guess == targetWord {
            gameState = .won
        } else if currentRow == 5 {
            gameState = .lost
        } else {
            currentRow += 1
            currentCol = 0
        }
    }

    private func evaluate(guess: String, target: String) -> [WordleTileState] {
        var result = Array(repeating: WordleTileState.absent, count: 5)
        var targetChars = Array(target)
        let guessChars  = Array(guess)

        // Pass 1: correct positions
        for i in 0..<5 {
            if guessChars[i] == targetChars[i] {
                result[i]      = .correct
                targetChars[i] = "_"
            }
        }

        // Pass 2: present elsewhere
        for i in 0..<5 {
            guard result[i] != .correct else { continue }
            if let idx = targetChars.firstIndex(of: guessChars[i]) {
                result[i]      = .present
                targetChars[idx] = "_"
            }
        }

        return result
    }
}

enum WordleGameState {
    case playing, won, lost
}

// MARK: - Main View

struct WordleView: View {
    @StateObject private var vm = WordleViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 12) {
                // Header
                Text("WORDLE")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .padding(.top, 8)

                Divider()

                // Grid
                WordleGridView(vm: vm)
                    .padding(.horizontal, 16)

                Spacer()

                // Keyboard
                WordleKeyboardView(vm: vm)
                    .padding(.bottom, 12)
            }

            // Overlays
            if vm.gameState == .won {
                WordleResultOverlay(
                    title: "Brilliant!",
                    subtitle: "You guessed the word!",
                    symbolName: "star.fill",
                    symbolColor: .yellow,
                    targetWord: vm.targetWord,
                    onRestart: { vm.startNewGame() }
                )
            } else if vm.gameState == .lost {
                WordleResultOverlay(
                    title: "Game Over",
                    subtitle: "Better luck next time",
                    symbolName: "xmark.circle.fill",
                    symbolColor: .red,
                    targetWord: vm.targetWord,
                    onRestart: { vm.startNewGame() }
                )
            }
        }
    }
}

// MARK: - Grid

struct WordleGridView: View {
    @ObservedObject var vm: WordleViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { col in
                        WordleTileView(
                            letter: vm.guesses[row].letters[col],
                            state: vm.guesses[row].states[col]
                        )
                    }
                }
            }
        }
    }
}

struct WordleTileView: View {
    let letter: String
    let state: WordleTileState

    var body: some View {
        Text(letter)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(state.foregroundColor)
            .frame(width: 58, height: 58)
            .background(state.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(state.borderColor, lineWidth: 2)
            )
            .cornerRadius(4)
    }
}

// MARK: - Keyboard

private let wordleKeyboardRows: [[String]] = [
    ["Q","W","E","R","T","Y","U","I","O","P"],
    ["A","S","D","F","G","H","J","K","L"],
    ["ENTER","Z","X","C","V","B","N","M","DELETE"]
]

struct WordleKeyboardView: View {
    @ObservedObject var vm: WordleViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(wordleKeyboardRows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        WordleKeyButton(key: key, state: vm.letterKeyStates[key] ?? .empty) {
                            switch key {
                            case "ENTER":  vm.submitGuess()
                            case "DELETE": vm.deleteLetter()
                            default:       vm.typeLetter(key)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

struct WordleKeyButton: View {
    let key: String
    let state: WordleTileState
    let action: () -> Void

    private var isSpecial: Bool { key == "ENTER" || key == "DELETE" }

    var body: some View {
        Button(action: action) {
            Text(key == "DELETE" ? "⌫" : key)
                .font(.system(size: isSpecial ? 13 : 17, weight: .semibold, design: .rounded))
                .foregroundColor(state == .empty ? .primary : .white)
                .frame(width: isSpecial ? 52 : 34, height: 50)
                .background(keyBackground)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var keyBackground: some View {
        switch state {
        case .empty:   Color(.systemGray4)
        case .correct: Color(red: 0.38, green: 0.65, blue: 0.40)
        case .present: Color(red: 0.79, green: 0.69, blue: 0.29)
        case .absent:  Color(red: 0.47, green: 0.49, blue: 0.51)
        }
    }
}

// MARK: - Result Overlay

struct WordleResultOverlay: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let symbolColor: Color
    let targetWord: String
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: symbolName)
                    .font(.system(size: 52))
                    .foregroundColor(symbolColor)

                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    Text("The word was")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(targetWord)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(Color(red: 0.38, green: 0.65, blue: 0.40))
                }

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 160, height: 46)
                        .background(Color(red: 0.38, green: 0.65, blue: 0.40))
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    WordleView()
}
