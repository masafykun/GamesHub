import SwiftUI

// MARK: - Model

struct HangmanWord {
    let word: String
    let hint: String
}

struct HangmanGameState {
    let wordList: [HangmanWord] = [
        HangmanWord(word: "SWIFT", hint: "Programming language"),
        HangmanWord(word: "XCODE", hint: "Apple IDE"),
        HangmanWord(word: "APPLE", hint: "Tech company"),
        HangmanWord(word: "IPHONE", hint: "Mobile device"),
        HangmanWord(word: "TABLET", hint: "Computing device"),
        HangmanWord(word: "GALAXY", hint: "Collection of stars"),
        HangmanWord(word: "PLANET", hint: "Orbits a star"),
        HangmanWord(word: "OCEAN", hint: "Large body of water"),
        HangmanWord(word: "FOREST", hint: "Dense trees area"),
        HangmanWord(word: "BRIDGE", hint: "Connects two places"),
        HangmanWord(word: "CASTLE", hint: "Medieval fortress"),
        HangmanWord(word: "DRAGON", hint: "Mythical creature"),
        HangmanWord(word: "WIZARD", hint: "Magic practitioner"),
        HangmanWord(word: "PYTHON", hint: "Scripting language"),
        HangmanWord(word: "KOTLIN", hint: "Android language"),
        HangmanWord(word: "GUITAR", hint: "String instrument"),
        HangmanWord(word: "VIOLIN", hint: "Bowed instrument"),
        HangmanWord(word: "CINEMA", hint: "Movie theater"),
        HangmanWord(word: "JUNGLE", hint: "Tropical forest"),
        HangmanWord(word: "DESERT", hint: "Arid landscape"),
        HangmanWord(word: "MUSEUM", hint: "Art and history"),
        HangmanWord(word: "LIBRARY", hint: "Books and knowledge"),
        HangmanWord(word: "COMPASS", hint: "Navigation tool"),
        HangmanWord(word: "LANTERN", hint: "Light source"),
        HangmanWord(word: "FEATHER", hint: "Bird covering"),
        HangmanWord(word: "CRYSTAL", hint: "Clear mineral"),
        HangmanWord(word: "BALLOON", hint: "Inflated object"),
        HangmanWord(word: "CAPTAIN", hint: "Ship commander"),
        HangmanWord(word: "DOLPHIN", hint: "Intelligent marine mammal"),
        HangmanWord(word: "PYRAMID", hint: "Ancient monument"),
        HangmanWord(word: "VOLCANO", hint: "Erupting mountain"),
        HangmanWord(word: "THUNDER", hint: "Storm sound"),
        HangmanWord(word: "BLANKET", hint: "Bed covering")
    ]

    var currentWord: HangmanWord
    var guessedLetters: Set<Character>
    var wrongGuesses: Int
    var isGameOver: Bool
    var isWon: Bool

    init() {
        currentWord = HangmanWord(word: "SWIFT", hint: "Programming language")
        guessedLetters = []
        wrongGuesses = 0
        isGameOver = false
        isWon = false
    }

    mutating func startNewGame() {
        currentWord = wordList.randomElement() ?? wordList[0]
        guessedLetters = []
        wrongGuesses = 0
        isGameOver = false
        isWon = false
    }

    mutating func guessLetter(_ letter: Character) {
        guard !isGameOver && !guessedLetters.contains(letter) else { return }
        guessedLetters.insert(letter)
        if !currentWord.word.contains(letter) {
            wrongGuesses += 1
            if wrongGuesses >= 6 {
                isGameOver = true
                isWon = false
            }
        } else {
            let revealed = currentWord.word.filter { guessedLetters.contains($0) }
            if revealed.count == currentWord.word.count {
                isGameOver = true
                isWon = true
            }
        }
    }

    func displayWord() -> [Character?] {
        return currentWord.word.map { guessedLetters.contains($0) ? $0 : nil }
    }
}

// MARK: - Hangman Drawing

struct HangmanDrawingView: View {
    let wrongGuesses: Int

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let strokeColor = Color.primary
            let lineWidth: CGFloat = 3

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
                let headRect = CGRect(
                    x: w * 0.57,
                    y: h * 0.18,
                    width: w * 0.16,
                    height: h * 0.14
                )
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

// MARK: - Letter Button

struct HangmanLetterButton: View {
    let letter: Character
    let isGuessed: Bool
    let isCorrect: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(letter))
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .foregroundColor(buttonForeground)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(buttonBorder, lineWidth: 1)
                )
        }
        .disabled(isGuessed)
    }

    private var buttonForeground: Color {
        if !isGuessed { return .primary }
        return isCorrect ? .white : .white
    }

    private var buttonBackground: Color {
        if !isGuessed { return Color(.systemBackground) }
        return isCorrect ? .green : .red.opacity(0.8)
    }

    private var buttonBorder: Color {
        if !isGuessed { return Color.secondary.opacity(0.4) }
        return isCorrect ? .green : .red
    }
}

// MARK: - Word Display

struct HangmanWordDisplay: View {
    let displayChars: [Character?]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<displayChars.count, id: \.self) { index in
                VStack(spacing: 2) {
                    Text(displayChars[index].map { String($0) } ?? " ")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .frame(width: 24, height: 28)
                        .foregroundColor(.primary)
                    Rectangle()
                        .frame(width: 24, height: 2)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Alphabet Grid

struct HangmanAlphabetGrid: View {
    let guessedLetters: Set<Character>
    let wordLetters: Set<Character>
    let onTap: (Character) -> Void

    private let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(letters, id: \.self) { letter in
                HangmanLetterButton(
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

// MARK: - Main View

struct HangmanView: View {
    @State private var gameState = HangmanGameState()

    private var wordLetters: Set<Character> {
        Set(gameState.currentWord.word)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Hangman")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        gameState.startNewGame()
                    }) {
                        Label("New Game", systemImage: "arrow.clockwise.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Wrong guesses indicator
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .frame(width: 14, height: 14)
                            .foregroundColor(index < gameState.wrongGuesses ? .red : Color.secondary.opacity(0.3))
                    }
                    Text("\(gameState.wrongGuesses)/6 wrong")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                // Hint
                Text("Hint: \(gameState.currentWord.hint)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // Drawing + Word
                VStack(spacing: 12) {
                    HangmanDrawingView(wrongGuesses: gameState.wrongGuesses)
                        .frame(height: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)

                    HangmanWordDisplay(displayChars: gameState.displayWord())
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 12)

                // Alphabet grid
                HangmanAlphabetGrid(
                    guessedLetters: gameState.guessedLetters,
                    wordLetters: wordLetters,
                    onTap: { letter in
                        gameState.guessLetter(letter)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }

            // Game over overlay
            if gameState.isGameOver {
                HangmanGameOverOverlay(
                    isWon: gameState.isWon,
                    word: gameState.currentWord.word,
                    onRestart: {
                        gameState.startNewGame()
                    }
                )
            }
        }
        .onAppear {
            gameState.startNewGame()
        }
    }
}

// MARK: - Game Over Overlay

struct HangmanGameOverOverlay: View {
    let isWon: Bool
    let word: String
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isWon ? "You Won!" : "Game Over")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(isWon ? .green : .red)

                Text(isWon ? "Great job!" : "The word was:")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                if !isWon {
                    Text(word)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 50)
                        .background(isWon ? Color.green : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: (isWon ? Color.green : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 40)
        }
    }
}
