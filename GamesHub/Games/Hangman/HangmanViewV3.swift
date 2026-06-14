import SwiftUI

// MARK: - Word List

private let hangmanV3WordList: [(word: String, hint: String)] = [
    ("SWIFT", "Programming language"),
    ("XCODE", "Apple IDE"),
    ("APPLE", "Tech company"),
    ("IPHONE", "Mobile device"),
    ("TABLET", "Computing device"),
    ("GALAXY", "Collection of stars"),
    ("PLANET", "Orbits a star"),
    ("OCEAN", "Large body of water"),
    ("FOREST", "Dense trees area"),
    ("BRIDGE", "Connects two places"),
    ("CASTLE", "Medieval fortress"),
    ("DRAGON", "Mythical creature"),
    ("WIZARD", "Magic practitioner"),
    ("PYTHON", "Scripting language"),
    ("KOTLIN", "Android language"),
    ("GUITAR", "String instrument"),
    ("VIOLIN", "Bowed instrument"),
    ("CINEMA", "Movie theater"),
    ("JUNGLE", "Tropical forest"),
    ("DESERT", "Arid landscape"),
    ("MUSEUM", "Art and history"),
    ("LIBRARY", "Books and knowledge"),
    ("COMPASS", "Navigation tool"),
    ("LANTERN", "Light source"),
    ("FEATHER", "Bird covering"),
    ("CRYSTAL", "Clear mineral"),
    ("BALLOON", "Inflated object"),
    ("CAPTAIN", "Ship commander"),
    ("DOLPHIN", "Intelligent marine mammal"),
    ("PYRAMID", "Ancient monument"),
    ("VOLCANO", "Erupting mountain"),
    ("THUNDER", "Storm sound"),
    ("BLANKET", "Bed covering")
]

// MARK: - LCG Seed Helper

private func hangmanV3LCGIndex(seedInt: Int, count: Int) -> Int {
    var s = UInt64(seedInt)
    s = s &* 6364136223846793005 &+ 1442695040888963407
    return Int(s % UInt64(count))
}

// MARK: - Game State

struct HangmanV3GameState {
    var currentWord: String = ""
    var currentHint: String = ""
    var guessedLetters: Set<Character> = []
    var wrongGuesses: Int = 0
    var isGameOver: Bool = false
    var isWon: Bool = false

    mutating func start(seedInt: Int) {
        let idx = hangmanV3LCGIndex(seedInt: seedInt, count: hangmanV3WordList.count)
        let entry = hangmanV3WordList[idx]
        currentWord = entry.word
        currentHint = entry.hint
        guessedLetters = []
        wrongGuesses = 0
        isGameOver = false
        isWon = false
    }

    mutating func guessLetter(_ letter: Character) {
        guard !isGameOver, !guessedLetters.contains(letter) else { return }
        guessedLetters.insert(letter)
        if !currentWord.contains(letter) {
            wrongGuesses += 1
            if wrongGuesses >= 6 {
                isGameOver = true
                isWon = false
            }
        } else {
            let revealed = currentWord.filter { guessedLetters.contains($0) }
            if revealed.count == currentWord.count {
                isGameOver = true
                isWon = true
            }
        }
    }

    func displayWord() -> [Character?] {
        currentWord.map { guessedLetters.contains($0) ? $0 : nil }
    }
}

// MARK: - Neumorphic Hangman Drawing

struct HangmanV3DrawingView: View {
    let wrongGuesses: Int

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let strokeColor = Color.primary
            let lineWidth: CGFloat = 3.5

            // Gallows base
            var basePath = Path()
            basePath.move(to: CGPoint(x: w * 0.1, y: h * 0.92))
            basePath.addLine(to: CGPoint(x: w * 0.9, y: h * 0.92))
            context.stroke(basePath, with: .color(strokeColor), lineWidth: lineWidth)

            // Vertical pole
            var polePath = Path()
            polePath.move(to: CGPoint(x: w * 0.3, y: h * 0.92))
            polePath.addLine(to: CGPoint(x: w * 0.3, y: h * 0.05))
            context.stroke(polePath, with: .color(strokeColor), lineWidth: lineWidth)

            // Horizontal beam
            var beamPath = Path()
            beamPath.move(to: CGPoint(x: w * 0.3, y: h * 0.05))
            beamPath.addLine(to: CGPoint(x: w * 0.65, y: h * 0.05))
            context.stroke(beamPath, with: .color(strokeColor), lineWidth: lineWidth)

            // Rope
            var ropePath = Path()
            ropePath.move(to: CGPoint(x: w * 0.65, y: h * 0.05))
            ropePath.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
            context.stroke(ropePath, with: .color(strokeColor), lineWidth: lineWidth)

            // Head (part 1)
            if wrongGuesses >= 1 {
                let headRect = CGRect(x: w * 0.565, y: h * 0.18, width: w * 0.17, height: h * 0.14)
                var headPath = Path()
                headPath.addEllipse(in: headRect)
                context.stroke(headPath, with: .color(strokeColor), lineWidth: lineWidth)
            }

            // Body (part 2)
            if wrongGuesses >= 2 {
                var bodyPath = Path()
                bodyPath.move(to: CGPoint(x: w * 0.65, y: h * 0.32))
                bodyPath.addLine(to: CGPoint(x: w * 0.65, y: h * 0.60))
                context.stroke(bodyPath, with: .color(strokeColor), lineWidth: lineWidth)
            }

            // Left arm (part 3)
            if wrongGuesses >= 3 {
                var leftArmPath = Path()
                leftArmPath.move(to: CGPoint(x: w * 0.65, y: h * 0.38))
                leftArmPath.addLine(to: CGPoint(x: w * 0.48, y: h * 0.52))
                context.stroke(leftArmPath, with: .color(strokeColor), lineWidth: lineWidth)
            }

            // Right arm (part 4)
            if wrongGuesses >= 4 {
                var rightArmPath = Path()
                rightArmPath.move(to: CGPoint(x: w * 0.65, y: h * 0.38))
                rightArmPath.addLine(to: CGPoint(x: w * 0.82, y: h * 0.52))
                context.stroke(rightArmPath, with: .color(strokeColor), lineWidth: lineWidth)
            }

            // Left leg (part 5)
            if wrongGuesses >= 5 {
                var leftLegPath = Path()
                leftLegPath.move(to: CGPoint(x: w * 0.65, y: h * 0.60))
                leftLegPath.addLine(to: CGPoint(x: w * 0.48, y: h * 0.80))
                context.stroke(leftLegPath, with: .color(strokeColor), lineWidth: lineWidth)
            }

            // Right leg (part 6)
            if wrongGuesses >= 6 {
                var rightLegPath = Path()
                rightLegPath.move(to: CGPoint(x: w * 0.65, y: h * 0.60))
                rightLegPath.addLine(to: CGPoint(x: w * 0.82, y: h * 0.80))
                context.stroke(rightLegPath, with: .color(strokeColor), lineWidth: lineWidth)
            }
        }
    }
}

// MARK: - Word Display

struct HangmanV3WordDisplay: View {
    let displayChars: [Character?]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<displayChars.count, id: \.self) { index in
                VStack(spacing: 3) {
                    Text(displayChars[index].map { String($0) } ?? " ")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .frame(width: 22, height: 26)
                        .foregroundColor(.primary)
                    Rectangle()
                        .frame(width: 22, height: 2.5)
                        .foregroundColor(Color.primary.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Neumorphic Letter Button

struct HangmanV3LetterButton: View {
    let letter: Character
    let isGuessed: Bool
    let isCorrect: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color { Color(.systemGray6) }

    var body: some View {
        Button(action: action) {
            Text(String(letter))
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundColor(labelColor)
                .background(
                    ZStack {
                        if isGuessed {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isCorrect ? Color.green.opacity(0.25) : Color.red.opacity(0.2))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bgColor)
                                .shadow(
                                    color: shadowDark,
                                    radius: 3,
                                    x: 2,
                                    y: 2
                                )
                                .shadow(
                                    color: shadowLight,
                                    radius: 3,
                                    x: -2,
                                    y: -2
                                )
                        }
                    }
                )
        }
        .disabled(isGuessed)
        .buttonStyle(.plain)
    }

    private var labelColor: Color {
        if !isGuessed { return .primary }
        return isCorrect ? .green : Color.red.opacity(0.8)
    }

    private var shadowDark: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.15)
    }

    private var shadowLight: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.85)
    }
}

// MARK: - Alphabet Grid

struct HangmanV3AlphabetGrid: View {
    let guessedLetters: Set<Character>
    let wordLetters: Set<Character>
    let onTap: (Character) -> Void

    private let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(letters, id: \.self) { letter in
                HangmanV3LetterButton(
                    letter: letter,
                    isGuessed: guessedLetters.contains(letter),
                    isCorrect: guessedLetters.contains(letter) && wordLetters.contains(letter),
                    action: { onTap(letter) }
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Neumorphic Wrong Guess Dots

struct HangmanV3WrongGuessDots: View {
    let wrongGuesses: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .frame(width: 14, height: 14)
                    .foregroundColor(index < wrongGuesses ? .red : Color(.systemGray4))
                    .shadow(
                        color: index < wrongGuesses ? Color.red.opacity(0.4) : Color.clear,
                        radius: 4, x: 0, y: 0
                    )
            }
            Text("\(wrongGuesses)/6")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Game Over Overlay

struct HangmanV3GameOverOverlay: View {
    let isWon: Bool
    let word: String
    let seedInt: Int
    let onRestart: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text(isWon ? "You Won!" : "Game Over")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(isWon ? .green : .red)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                if !isWon {
                    VStack(spacing: 4) {
                        Text("The word was:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(word)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Great job!")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Button(action: onRestart) {
                    Text("Next Word")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isWon ? Color.green : Color.blue)
                                .shadow(
                                    color: (isWon ? Color.green : Color.blue).opacity(0.45),
                                    radius: 8, x: 0, y: 4
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.6)
                            : Color.black.opacity(0.18),
                        radius: 20, x: 0, y: 8
                    )
            )
            .padding(.horizontal, 36)
        }
    }
}

// MARK: - Main View

struct HangmanViewV3: View {
    @State var seedInt: Int = 1
    @State private var gameState = HangmanV3GameState()

    @Environment(\.colorScheme) private var colorScheme

    private var wordLetters: Set<Character> {
        Set(gameState.currentWord)
    }

    private var shadowDark: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.55)
            : Color.black.opacity(0.14)
    }

    private var shadowLight: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.white.opacity(0.9)
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hangman")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }

                    Spacer()

                    Button(action: restartGame) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                            Text("New")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                                .shadow(color: Color.blue.opacity(0.4), radius: 5, x: 0, y: 3)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                // MARK: Wrong Guesses + Hint
                VStack(alignment: .leading, spacing: 6) {
                    HangmanV3WrongGuessDots(wrongGuesses: gameState.wrongGuesses)
                    Text("Hint: \(gameState.currentHint)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // MARK: Gallows Drawing (neumorphic card)
                HangmanV3DrawingView(wrongGuesses: gameState.wrongGuesses)
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .shadow(color: shadowDark, radius: 6, x: 4, y: 4)
                            .shadow(color: shadowLight, radius: 6, x: -4, y: -4)
                            .padding(.horizontal, 20)
                    )
                    .padding(.bottom, 14)

                // MARK: Word Display (neumorphic card)
                HangmanV3WordDisplay(displayChars: gameState.displayWord())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .shadow(color: shadowDark, radius: 5, x: 3, y: 3)
                            .shadow(color: shadowLight, radius: 5, x: -3, y: -3)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Spacer(minLength: 8)

                // MARK: Alphabet Grid
                HangmanV3AlphabetGrid(
                    guessedLetters: gameState.guessedLetters,
                    wordLetters: wordLetters,
                    onTap: { letter in
                        gameState.guessLetter(letter)
                    }
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }

            // MARK: Game Over Overlay
            if gameState.isGameOver {
                HangmanV3GameOverOverlay(
                    isWon: gameState.isWon,
                    word: gameState.currentWord,
                    seedInt: seedInt,
                    onRestart: restartGame
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gameState.isGameOver)
        .onAppear {
            gameState.start(seedInt: seedInt)
        }
    }

    private func restartGame() {
        seedInt += 1
        gameState.start(seedInt: seedInt)
    }
}
