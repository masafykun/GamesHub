import SwiftUI

// MARK: - Neumorphism Extension


// MARK: - Enums

enum WordleV3TileState {
    case empty, correct, present, absent

    var fillColor: Color {
        switch self {
        case .empty:   return Color(.systemGray6)
        case .correct: return Color(red: 0.36, green: 0.67, blue: 0.42)
        case .present: return Color(red: 0.84, green: 0.72, blue: 0.27)
        case .absent:  return Color(red: 0.58, green: 0.58, blue: 0.60)
        }
    }

    var textColor: Color {
        switch self {
        case .empty: return Color(.label)
        default:     return .white
        }
    }
}

enum WordleV3GameState { case playing, won, lost }

// MARK: - Models

struct WordleV3Guess {
    var letters: [String]           = Array(repeating: "", count: 5)
    var states: [WordleV3TileState] = Array(repeating: .empty, count: 5)
}

// MARK: - ViewModel

class WordleV3ViewModel: ObservableObject {
    @Published var guesses: [WordleV3Guess] = Array(repeating: WordleV3Guess(), count: 6)
    @Published var currentRow: Int = 0
    @Published var currentCol: Int = 0
    @Published var gameState: WordleV3GameState = .playing
    @Published var targetWord: String = ""
    @Published var letterKeyStates: [String: WordleV3TileState] = [:]
    @Published var gameNumber: Int = 1

    init() {
        startGame(number: 1)
    }

    func startGame(number: Int) {
        gameNumber      = number
        targetWord      = wordleWordList[number % wordleWordList.count]
        guesses         = Array(repeating: WordleV3Guess(), count: 6)
        currentRow      = 0
        currentCol      = 0
        gameState       = .playing
        letterKeyStates = [:]
    }

    func restart() {
        startGame(number: gameNumber + 1)
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

        let guess  = guesses[currentRow].letters.joined()
        let result = evaluateV3(guess: guess, target: targetWord)
        guesses[currentRow].states = result

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

    private func evaluateV3(guess: String, target: String) -> [WordleV3TileState] {
        var result      = Array(repeating: WordleV3TileState.absent, count: 5)
        var targetChars = Array(target)
        let guessChars  = Array(guess)

        for i in 0..<5 where guessChars[i] == targetChars[i] {
            result[i]      = .correct
            targetChars[i] = "_"
        }
        for i in 0..<5 {
            guard result[i] != .correct else { continue }
            if let idx = targetChars.firstIndex(of: guessChars[i]) {
                result[i]        = .present
                targetChars[idx] = "_"
            }
        }
        return result
    }
}

// MARK: - Main View

struct WordleViewV3: View {
    @StateObject private var vm = WordleV3ViewModel()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 12) {
                // Header
                WordleV3HeaderView(gameNumber: vm.gameNumber)

                // Grid
                WordleV3GridView(vm: vm)
                    .padding(.horizontal, 16)

                Spacer()

                // Keyboard
                WordleV3KeyboardView(vm: vm)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 16)
                    .neumorphicCard(radius: 24)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // Overlays
            if vm.gameState == .won {
                WordleV3ResultOverlay(
                    title: "Solved!",
                    subtitle: "Puzzle #\(vm.gameNumber) complete",
                    isWin: true,
                    targetWord: vm.targetWord,
                    onRestart: { vm.restart() }
                )
            } else if vm.gameState == .lost {
                WordleV3ResultOverlay(
                    title: "Missed It",
                    subtitle: "Puzzle #\(vm.gameNumber) failed",
                    isWin: false,
                    targetWord: vm.targetWord,
                    onRestart: { vm.restart() }
                )
            }
        }
    }
}

// MARK: - Header

struct WordleV3HeaderView: View {
    let gameNumber: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("WORDLE V3")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(Color(.label))
                .tracking(4)

            Text("SEED: #\(gameNumber)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .neumorphicCard(radius: 10)
        }
        .padding(.top, 12)
    }
}

// MARK: - Grid

struct WordleV3GridView: View {
    @ObservedObject var vm: WordleV3ViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { col in
                        WordleV3TileView(
                            letter: vm.guesses[row].letters[col],
                            state: vm.guesses[row].states[col]
                        )
                    }
                }
            }
        }
    }
}

struct WordleV3TileView: View {
    let letter: String
    let state: WordleV3TileState

    var body: some View {
        ZStack {
            if state == .empty {
                // Neumorphic inset for empty tiles
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.white.opacity(0.85), radius: 4, x: -3, y: -3)
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 3, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                letter.isEmpty
                                    ? Color(.systemGray4)
                                    : Color(.systemGray2),
                                lineWidth: letter.isEmpty ? 1.5 : 2
                            )
                    )
            } else {
                // Colored state tile with neumorphic shadow
                RoundedRectangle(cornerRadius: 10)
                    .fill(state.fillColor)
                    .frame(width: 56, height: 56)
                    .shadow(color: state.fillColor.opacity(0.50), radius: 5, x: 3, y: 4)
                    .shadow(color: Color.white.opacity(0.60), radius: 4, x: -3, y: -3)
            }

            Text(letter)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(state.textColor)
        }
        .frame(width: 56, height: 56)
        .scaleEffect(letter.isEmpty ? 1.0 : 1.04)
        .animation(.spring(response: 0.2, dampingFraction: 0.55), value: letter)
    }
}

// MARK: - Keyboard

private let wordleV3KeyboardRows: [[String]] = [
    ["Q","W","E","R","T","Y","U","I","O","P"],
    ["A","S","D","F","G","H","J","K","L"],
    ["ENTER","Z","X","C","V","B","N","M","DELETE"]
]

struct WordleV3KeyboardView: View {
    @ObservedObject var vm: WordleV3ViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(wordleV3KeyboardRows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        WordleV3KeyButton(key: key, state: vm.letterKeyStates[key] ?? .empty) {
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
        .padding(.vertical, 12)
    }
}

struct WordleV3KeyButton: View {
    let key: String
    let state: WordleV3TileState
    let action: () -> Void

    private var isSpecial: Bool { key == "ENTER" || key == "DELETE" }

    var body: some View {
        Button(action: action) {
            Text(key == "DELETE" ? "⌫" : key)
                .font(.system(size: isSpecial ? 12 : 15, weight: .semibold, design: .rounded))
                .foregroundColor(state == .empty ? Color(.label) : .white)
                .frame(width: isSpecial ? 50 : 32, height: 44)
                .background(state.fillColor)
                .cornerRadius(8)
                .shadow(color: state == .empty
                            ? Color.white.opacity(0.85)
                            : state.fillColor.opacity(0.45),
                        radius: 4, x: -2, y: -2)
                .shadow(color: state == .empty
                            ? Color.black.opacity(0.16)
                            : Color.black.opacity(0.25),
                        radius: 4, x: 2, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Result Overlay

struct WordleV3ResultOverlay: View {
    let title: String
    let subtitle: String
    let isWin: Bool
    let targetWord: String
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.40).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: isWin ? "trophy.fill" : "xmark.circle")
                    .font(.system(size: 56))
                    .foregroundColor(isWin ? .yellow : .red)
                    .shadow(color: (isWin ? Color.yellow : Color.red).opacity(0.35),
                            radius: 10, x: 0, y: 5)

                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(.label))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))

                VStack(spacing: 4) {
                    Text("The word was")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                    Text(targetWord)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(isWin
                            ? Color(red: 0.36, green: 0.67, blue: 0.42)
                            : Color(.secondaryLabel))
                }
                .padding(14)
                .neumorphicCard(radius: 14)

                Button(action: onRestart) {
                    Text("Next Puzzle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 160, height: 46)
                        .background(
                            isWin
                                ? Color(red: 0.36, green: 0.67, blue: 0.42)
                                : Color(red: 0.55, green: 0.55, blue: 0.60)
                        )
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 4)
                }
            }
            .padding(32)
            .background(Color(.systemGray6))
            .cornerRadius(24)
            .shadow(color: Color.white.opacity(0.85), radius: 10, x: -6, y: -6)
            .shadow(color: Color.black.opacity(0.20), radius: 10, x: 6, y: 6)
            .padding(.horizontal, 28)
        }
    }
}

#Preview {
    WordleViewV3()
}
