import SwiftUI

// MARK: - Word Lists

private let wordleV2EasyWords: [String] = [
    "ADDED", "AIMED", "AIRED", "ATOMS", "BEADS", "BEATS", "BELLS", "BIKES",
    "BIRDS", "BITES", "BLEND", "BONES", "BOOKS", "BOOTS", "BOXES", "BURNS",
    "CALLS", "CARDS", "CASES", "CAVES", "CELLS", "CHIPS", "CHOSE", "CITED",
    "CLIPS", "CODES", "COINS", "COOKS", "CORES", "COSTS", "COVER", "CRABS",
    "DATES", "DEALS", "DIALS", "DOORS", "DROPS", "DRUMS", "DUSTS", "EDGES",
    "ELBOW", "ENTER", "ERODE", "FACES", "FACTS", "FALLS", "FARMS", "FEELS",
    "FEEDS", "FILES", "FILLS", "FINDS", "FIRES", "FLIES", "FLOOR", "FLOWS",
    "FOLKS", "FOODS", "FORMS", "FOUND"
]

private let wordleV2HardWords: [String] = [
    "ZYMOTIC", "KVETCH", "FJORD", "GLYPH", "PSYCH", "TRYST", "CRYPT",
    "SPHINX", "LYNCH", "GRAFT", "BLITZ", "FRITZ", "GYRATE", "SQUIB",
    "NYMPH", "BORAX", "EXPAT", "AXIOM", "INFIX", "ANNEX", "ERGOT", "BLEAT",
    "AMBIT", "VYING", "MIRTH", "STOIC", "NATAL", "REDUX", "ETHOS", "NEXUS",
    "ANGST", "REBUT", "GUILE", "INEPT", "VAPID", "TACIT", "PREEN", "BERTH",
    "FOYER", "GROUT", "SNOUT", "TROVE", "QUIRK", "KNACK", "BRINK", "CLEFT",
    "DWELT", "ENVOY", "EXPEL", "FETID", "GAUNT", "HOIST", "INANE", "JOUST",
    "KINKY", "LARVA", "MUTED", "NADIR", "OPTIC", "PATSY", "QUAFF", "RELIC"
]

// MARK: - Enums

enum WordleV2TileState {
    case empty, correct, present, absent

    var backgroundColor: Color {
        switch self {
        case .empty:   return Color.white.opacity(0.08)
        case .correct: return Color(red: 0.25, green: 0.72, blue: 0.48)
        case .present: return Color(red: 0.88, green: 0.72, blue: 0.20)
        case .absent:  return Color.white.opacity(0.25)
        }
    }

    var foregroundColor: Color { .white }

    var borderColor: Color {
        switch self {
        case .empty: return Color.white.opacity(0.30)
        default:     return .clear
        }
    }
}

enum WordleV2GameState { case playing, won, lost }
enum WordleV2Difficulty { case easy, hard }

// MARK: - Models

struct WordleV2Guess {
    var letters: [String]        = Array(repeating: "", count: 5)
    var states: [WordleV2TileState] = Array(repeating: .empty, count: 5)
    var revealed: [Bool]         = Array(repeating: false, count: 5)
}

// MARK: - ViewModel

class WordleV2ViewModel: ObservableObject {
    @Published var guesses: [WordleV2Guess] = Array(repeating: WordleV2Guess(), count: 6)
    @Published var currentRow: Int = 0
    @Published var currentCol: Int = 0
    @Published var gameState: WordleV2GameState = .playing
    @Published var targetWord: String = ""
    @Published var letterKeyStates: [String: WordleV2TileState] = [:]
    @Published var roundScores: [Int] = []
    @Published var difficulty: WordleV2Difficulty = .easy
    @Published var isRevealing: Bool = false

    init() { startNewGame() }

    var movingAverage: Double {
        guard !roundScores.isEmpty else { return 3.5 }
        let slice = roundScores.suffix(5)
        return Double(slice.reduce(0, +)) / Double(slice.count)
    }

    func startNewGame() {
        let avg = movingAverage
        if avg > 4.5 {
            difficulty = .hard
            targetWord = wordleV2HardWords.randomElement() ?? "STOIC"
        } else if avg < 3.0 {
            difficulty = .easy
            targetWord = wordleV2EasyWords.randomElement() ?? "FOUND"
        } else {
            // blend: pick from combined list
            let combined = wordleV2EasyWords + wordleV2HardWords
            targetWord = combined.randomElement() ?? "CRANE"
            difficulty = wordleV2HardWords.contains(targetWord) ? .hard : .easy
        }

        guesses         = Array(repeating: WordleV2Guess(), count: 6)
        currentRow      = 0
        currentCol      = 0
        gameState       = .playing
        letterKeyStates = [:]
        isRevealing     = false
    }

    func typeLetter(_ letter: String) {
        guard gameState == .playing, currentCol < 5, !isRevealing else { return }
        guesses[currentRow].letters[currentCol] = letter
        currentCol += 1
    }

    func deleteLetter() {
        guard gameState == .playing, currentCol > 0, !isRevealing else { return }
        currentCol -= 1
        guesses[currentRow].letters[currentCol] = ""
    }

    func submitGuess() {
        guard gameState == .playing, currentCol == 5, !isRevealing else { return }

        let guess  = guesses[currentRow].letters.joined()
        let result = evaluateV2(guess: guess, target: targetWord)
        guesses[currentRow].states = result

        isRevealing = true

        // Animate reveal col by col
        for col in 0..<5 {
            let delay = Double(col) * 0.18
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.guesses[self.currentRow].revealed[col] = true
                }
            }
        }

        // After all tiles revealed, update state
        DispatchQueue.main.asyncAfter(deadline: .now() + 5 * 0.18 + 0.3) {
            // Update key states
            for (i, letter) in self.guesses[self.currentRow].letters.enumerated() {
                let newState = result[i]
                if let existing = self.letterKeyStates[letter] {
                    if existing != .correct {
                        if newState == .correct || (newState == .present && existing == .absent) {
                            self.letterKeyStates[letter] = newState
                        }
                    }
                } else {
                    self.letterKeyStates[letter] = newState
                }
            }

            self.isRevealing = false

            if guess == self.targetWord {
                let score = 7 - self.currentRow  // currentRow is 0-indexed attempt number at time of win
                self.roundScores.append(score)
                self.gameState = .won
            } else if self.currentRow == 5 {
                self.roundScores.append(0)
                self.gameState = .lost
            } else {
                self.currentRow += 1
                self.currentCol  = 0
            }
        }
    }

    private func evaluateV2(guess: String, target: String) -> [WordleV2TileState] {
        var result      = Array(repeating: WordleV2TileState.absent, count: 5)
        var targetChars = Array(target)
        let guessChars  = Array(guess)

        for i in 0..<5 where guessChars[i] == targetChars[i] {
            result[i]      = .correct
            targetChars[i] = "_"
        }
        for i in 0..<5 {
            guard result[i] != .correct else { continue }
            if let idx = targetChars.firstIndex(of: guessChars[i]) {
                result[i]         = .present
                targetChars[idx]  = "_"
            }
        }
        return result
    }
}

// MARK: - Main View

struct WordleViewV2: View {
    @StateObject private var vm = WordleV2ViewModel()

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.07, blue: 0.18), Color(red: 0.12, green: 0.06, blue: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 10) {
                // Header
                VStack(spacing: 4) {
                    Text("WORDLE V2")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)

                    HStack(spacing: 8) {
                        WordleV2DifficultyBadge(difficulty: vm.difficulty)
                        if !vm.roundScores.isEmpty {
                            Text("Avg: \(String(format: "%.1f", vm.movingAverage))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.top, 10)

                // Grid
                WordleV2GridView(vm: vm)
                    .padding(.horizontal, 16)

                Spacer()

                // Keyboard – glassmorphism background
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)

                    WordleV2KeyboardView(vm: vm)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            // Overlays
            if vm.gameState == .won {
                WordleV2ResultOverlay(
                    title: "Outstanding!",
                    subtitle: "Word guessed correctly",
                    symbolName: "trophy.fill",
                    symbolColor: .yellow,
                    targetWord: vm.targetWord,
                    score: vm.roundScores.last ?? 0,
                    onRestart: { vm.startNewGame() }
                )
            } else if vm.gameState == .lost {
                WordleV2ResultOverlay(
                    title: "Game Over",
                    subtitle: "The word slipped away",
                    symbolName: "xmark.circle",
                    symbolColor: .red,
                    targetWord: vm.targetWord,
                    score: 0,
                    onRestart: { vm.startNewGame() }
                )
            }
        }
    }
}

// MARK: - Difficulty Badge

struct WordleV2DifficultyBadge: View {
    let difficulty: WordleV2Difficulty

    var body: some View {
        Text(difficulty == .hard ? "Hard Mode" : "Easy Mode")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(difficulty == .hard
                    ? Color(red: 0.88, green: 0.20, blue: 0.20).opacity(0.8)
                    : Color(red: 0.20, green: 0.72, blue: 0.48).opacity(0.8))
            )
            .foregroundColor(.white)
    }
}

// MARK: - Grid

struct WordleV2GridView: View {
    @ObservedObject var vm: WordleV2ViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { col in
                        WordleV2TileView(
                            letter: vm.guesses[row].letters[col],
                            state: vm.guesses[row].states[col],
                            revealed: vm.guesses[row].revealed[col],
                            isCurrentRow: row == vm.currentRow && vm.guesses[row].revealed.allSatisfy({ !$0 })
                        )
                    }
                }
            }
        }
    }
}

struct WordleV2TileView: View {
    let letter: String
    let state: WordleV2TileState
    let revealed: Bool
    let isCurrentRow: Bool

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            if revealed || !isCurrentRow && state != .empty {
                // Colored revealed tile
                RoundedRectangle(cornerRadius: 8)
                    .fill(state.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                Text(letter)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                // Frosted glass unconfirmed tile
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(letter.isEmpty ? 0.20 : 0.55), lineWidth: letter.isEmpty ? 1 : 2)
                    )
                    .blur(radius: letter.isEmpty ? 0 : 0)
                Text(letter)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 58, height: 58)
        .rotation3DEffect(.degrees(revealed ? 0 : 0), axis: (x: 1, y: 0, z: 0))
        .onChange(of: revealed) { newVal in
            if newVal {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    rotation = 360
                }
            }
        }
        .scaleEffect(letter.isEmpty ? 1.0 : (isCurrentRow ? 1.05 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: letter)
    }
}

// MARK: - Keyboard

private let wordleV2KeyboardRows: [[String]] = [
    ["Q","W","E","R","T","Y","U","I","O","P"],
    ["A","S","D","F","G","H","J","K","L"],
    ["ENTER","Z","X","C","V","B","N","M","DELETE"]
]

struct WordleV2KeyboardView: View {
    @ObservedObject var vm: WordleV2ViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(wordleV2KeyboardRows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        WordleV2KeyButton(key: key, state: vm.letterKeyStates[key] ?? .empty) {
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
    }
}

struct WordleV2KeyButton: View {
    let key: String
    let state: WordleV2TileState
    let action: () -> Void

    private var isSpecial: Bool { key == "ENTER" || key == "DELETE" }

    var body: some View {
        Button(action: action) {
            Text(key == "DELETE" ? "⌫" : key)
                .font(.system(size: isSpecial ? 12 : 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: isSpecial ? 50 : 33, height: 46)
                .background(keyBg)
                .cornerRadius(7)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var keyBg: some View {
        switch state {
        case .empty:
            Color.white.opacity(0.18)
        case .correct:
            Color(red: 0.25, green: 0.72, blue: 0.48)
        case .present:
            Color(red: 0.88, green: 0.72, blue: 0.20)
        case .absent:
            Color.white.opacity(0.10)
        }
    }
}

// MARK: - Result Overlay

struct WordleV2ResultOverlay: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let symbolColor: Color
    let targetWord: String
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.60).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: symbolName)
                    .font(.system(size: 56))
                    .foregroundColor(symbolColor)

                Text(title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                VStack(spacing: 4) {
                    Text("The word was")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(targetWord)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(Color(red: 0.25, green: 0.72, blue: 0.48))
                }

                if score > 0 {
                    Text("Score: +\(score)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }

                Button(action: onRestart) {
                    Text("Next Round")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 160, height: 46)
                        .background(Color(red: 0.25, green: 0.72, blue: 0.48))
                        .cornerRadius(12)
                }
                .padding(.top, 4)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding(.horizontal, 28)
        }
    }
}

#Preview {
    WordleViewV2()
}
