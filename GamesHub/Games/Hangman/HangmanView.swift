import SwiftUI

// MARK: - Difficulty

enum HangmanDifficulty {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    // Easy  → short words (3-5 letters)
    // Medium → mix
    // Hard  → long words (6-9 letters)
    var preferShort: Bool { self == .easy }
    var preferLong: Bool  { self == .hard }
}

// MARK: - Word Bank

struct HangmanWord {
    let word: String
    let hint: String
    var isShort: Bool { word.count <= 5 }
}

// MARK: - Game State

struct HangmanGameState {

    static let allWords: [HangmanWord] = [
        // Short (3-5 letters)
        HangmanWord(word: "CAT",    hint: "Household pet"),
        HangmanWord(word: "DOG",    hint: "Man's best friend"),
        HangmanWord(word: "SUN",    hint: "Our nearest star"),
        HangmanWord(word: "FIRE",   hint: "Hot and bright"),
        HangmanWord(word: "TREE",   hint: "Has leaves and bark"),
        HangmanWord(word: "BOOK",   hint: "You read it"),
        HangmanWord(word: "FISH",   hint: "Swims in water"),
        HangmanWord(word: "MOON",   hint: "Earth's satellite"),
        HangmanWord(word: "RAIN",   hint: "Falling water drops"),
        HangmanWord(word: "BIRD",   hint: "Feathered flyer"),
        HangmanWord(word: "CLOUD",  hint: "Floats in the sky"),
        HangmanWord(word: "GRAPE",  hint: "Grows in a bunch"),
        HangmanWord(word: "PIANO",  hint: "Has 88 keys"),
        HangmanWord(word: "SWORD",  hint: "Knight's weapon"),
        HangmanWord(word: "TIGER",  hint: "Striped big cat"),
        // Long (6-9 letters)
        HangmanWord(word: "SWIFT",      hint: "Apple's language"),
        HangmanWord(word: "PYTHON",     hint: "Scripting language"),
        HangmanWord(word: "KOTLIN",     hint: "Android language"),
        HangmanWord(word: "GUITAR",     hint: "String instrument"),
        HangmanWord(word: "VIOLIN",     hint: "Bowed instrument"),
        HangmanWord(word: "CINEMA",     hint: "Movie theater"),
        HangmanWord(word: "JUNGLE",     hint: "Tropical forest"),
        HangmanWord(word: "DESERT",     hint: "Arid landscape"),
        HangmanWord(word: "COMPASS",    hint: "Navigation tool"),
        HangmanWord(word: "LANTERN",    hint: "Light source"),
        HangmanWord(word: "FEATHER",    hint: "Bird covering"),
        HangmanWord(word: "CRYSTAL",    hint: "Clear mineral"),
        HangmanWord(word: "BALLOON",    hint: "Inflated object"),
        HangmanWord(word: "CAPTAIN",    hint: "Ship commander"),
        HangmanWord(word: "DOLPHIN",    hint: "Intelligent marine mammal"),
        HangmanWord(word: "PYRAMID",    hint: "Ancient monument"),
        HangmanWord(word: "VOLCANO",    hint: "Erupting mountain"),
        HangmanWord(word: "THUNDER",    hint: "Storm sound"),
        HangmanWord(word: "BLANKET",    hint: "Bed covering"),
        HangmanWord(word: "LIBRARY",    hint: "Books and knowledge"),
        HangmanWord(word: "ELEPHANT",   hint: "Largest land animal"),
        HangmanWord(word: "MOUNTAIN",   hint: "High natural peak"),
        HangmanWord(word: "CALENDAR",   hint: "Tracks days and months"),
        HangmanWord(word: "UNIVERSE",   hint: "Everything that exists"),
        HangmanWord(word: "ARCHITECT",  hint: "Designs buildings"),
    ]

    var currentWord: HangmanWord
    var guessedLetters: Set<Character>
    var wrongGuesses: Int
    var isGameOver: Bool
    var isWon: Bool
    var difficulty: HangmanDifficulty

    init(difficulty: HangmanDifficulty = .medium) {
        self.difficulty = difficulty
        self.currentWord = HangmanGameState.pickWord(for: difficulty)
        self.guessedLetters = []
        self.wrongGuesses = 0
        self.isGameOver = false
        self.isWon = false
    }

    static func pickWord(for difficulty: HangmanDifficulty) -> HangmanWord {
        let pool: [HangmanWord]
        switch difficulty {
        case .easy:
            pool = allWords.filter { $0.isShort }
        case .hard:
            pool = allWords.filter { !$0.isShort }
        case .medium:
            pool = allWords
        }
        return pool.randomElement() ?? allWords[0]
    }

    mutating func startNewGame() {
        currentWord = HangmanGameState.pickWord(for: difficulty)
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
        currentWord.word.map { guessedLetters.contains($0) ? $0 : nil }
    }

    // Score: letters in word - wrong guesses × 2 (min 0)
    var roundScore: Int {
        max(0, currentWord.word.count - wrongGuesses * 2)
    }
}

// MARK: - Hangman Drawing 

struct HangmanDrawingView: View {
    let wrongGuesses: Int
    let difficulty: HangmanDifficulty

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let strokeColor = Color.primary
            let lw: CGFloat = 3.5

            // Gallows
            drawLine(context: context, from: CGPoint(x: w*0.08, y: h*0.92), to: CGPoint(x: w*0.92, y: h*0.92), color: strokeColor, lw: lw)
            drawLine(context: context, from: CGPoint(x: w*0.28, y: h*0.92), to: CGPoint(x: w*0.28, y: h*0.05), color: strokeColor, lw: lw)
            drawLine(context: context, from: CGPoint(x: w*0.28, y: h*0.05), to: CGPoint(x: w*0.65, y: h*0.05), color: strokeColor, lw: lw)
            drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.05), to: CGPoint(x: w*0.65, y: h*0.17), color: strokeColor, lw: lw)

            // Head
            if wrongGuesses >= 1 {
                var head = Path()
                head.addEllipse(in: CGRect(x: w*0.565, y: h*0.17, width: w*0.17, height: h*0.15))
                context.stroke(head, with: .color(strokeColor), lineWidth: lw)
            }
            // Body
            if wrongGuesses >= 2 {
                drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.32), to: CGPoint(x: w*0.65, y: h*0.60), color: strokeColor, lw: lw)
            }
            // Left arm
            if wrongGuesses >= 3 {
                drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.38), to: CGPoint(x: w*0.46, y: h*0.52), color: strokeColor, lw: lw)
            }
            // Right arm
            if wrongGuesses >= 4 {
                drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.38), to: CGPoint(x: w*0.84, y: h*0.52), color: strokeColor, lw: lw)
            }
            // Left leg
            if wrongGuesses >= 5 {
                drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.60), to: CGPoint(x: w*0.46, y: h*0.82), color: strokeColor, lw: lw)
            }
            // Right leg
            if wrongGuesses >= 6 {
                drawLine(context: context, from: CGPoint(x: w*0.65, y: h*0.60), to: CGPoint(x: w*0.84, y: h*0.82), color: strokeColor, lw: lw)
            }
        }
    }

    private func drawLine(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, lw: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        context.stroke(p, with: .color(color), lineWidth: lw)
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
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundColor(fgColor)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bgColor)
                        if !isGuessed {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .disabled(isGuessed)
        .scaleEffect(isGuessed ? 0.92 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isGuessed)
    }

    private var fgColor: Color {
        if !isGuessed { return .primary }
        return .white
    }

    private var bgColor: Color {
        if !isGuessed { return Color.clear }
        return isCorrect ? Color.green.opacity(0.8) : Color.red.opacity(0.75)
    }

    private var borderColor: Color {
        if !isGuessed { return Color.primary.opacity(0.2) }
        return isCorrect ? .green : .red.opacity(0.8)
    }
}

// MARK: - Word Display 

struct HangmanWordDisplay: View {
    let displayChars: [Character?]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<displayChars.count, id: \.self) { i in
                VStack(spacing: 3) {
                    Text(displayChars[i].map { String($0) } ?? " ")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .frame(width: 22, height: 26)
                        .foregroundColor(.primary)
                        .transition(.scale.combined(with: .opacity))
                        .id("\(i)-\(displayChars[i] != nil)")
                    Rectangle()
                        .frame(width: 22, height: 2)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: displayChars.map { $0?.description ?? "_" }.joined())
    }
}

// MARK: - Difficulty Badge

struct HangmanDifficultyBadge: View {
    let difficulty: HangmanDifficulty

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
            Text(difficulty.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(difficulty.color.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Score History Bar

struct HangmanScoreBar: View {
    let scores: [Int]
    let maxScore: Int = 10

    var body: some View {
        HStack(spacing: 4) {
            Text("Recent:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            ForEach(0..<5, id: \.self) { i in
                if i < scores.count {
                    let s = min(scores[scores.count - min(5, scores.count) + (i - (5 - min(5, scores.count)))], maxScore)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 14, height: CGFloat(s) / CGFloat(maxScore) * 20 + 4)
                        .frame(height: 24, alignment: .bottom)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 14, height: 4)
                        .frame(height: 24, alignment: .bottom)
                }
            }
            if !scores.isEmpty {
                let avg = scores.suffix(5).reduce(0, +) / scores.suffix(5).count
                Text("avg \(avg)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Game Over Overlay 

struct HangmanGameOverOverlay: View {
    let isWon: Bool
    let word: String
    let score: Int
    let difficulty: HangmanDifficulty
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                // Emoji
                Text(isWon ? "🎉" : "💀")
                    .font(.system(size: 52))

                Text(isWon ? "You Won!" : "Game Over")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(isWon ? .green : .red)

                if !isWon {
                    VStack(spacing: 4) {
                        Text("The word was:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(word)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Score")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(score)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Divider().frame(height: 32)
                    VStack(spacing: 2) {
                        Text("Next")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        HangmanDifficultyBadge(difficulty: difficulty)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 50)
                        .background(
                            LinearGradient(
                                colors: isWon ? [.green, .teal] : [.blue, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: (isWon ? Color.green : Color.blue).opacity(0.45), radius: 10, x: 0, y: 5)
                }
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 12)
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: true)
    }
}

// MARK: - Main View 

struct HangmanView: View {

    // Adaptive difficulty tracking
    @State private var roundScores: [Int] = []
    @State private var difficulty: HangmanDifficulty = .medium
    @State private var gameState: HangmanGameState = HangmanGameState(difficulty: .medium)
    @State private var showOverlay: Bool = false

    private var wordLetters: Set<Character> {
        Set(gameState.currentWord.word)
    }

    // Compute next difficulty from moving average of last 5 scores
    private func nextDifficulty(after scores: [Int]) -> HangmanDifficulty {
        let recent = Array(scores.suffix(5))
        guard !recent.isEmpty else { return .medium }
        let avg = recent.reduce(0, +) / recent.count
        // avg >= 6 → upgrade; avg <= 2 → downgrade
        switch difficulty {
        case .easy:
            return avg >= 6 ? .medium : .easy
        case .medium:
            if avg >= 6 { return .hard }
            if avg <= 2 { return .easy }
            return .medium
        case .hard:
            return avg <= 2 ? .medium : .hard
        }
    }

    private func handleGameOver() {
        let score = gameState.roundScore
        var updated = roundScores
        updated.append(score)
        if updated.count > 5 { updated = Array(updated.suffix(5)) }
        roundScores = updated
        difficulty = nextDifficulty(after: updated)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showOverlay = true
        }
    }

    private func restartGame() {
        withAnimation {
            showOverlay = false
        }
        var next = HangmanGameState(difficulty: difficulty)
        next.startNewGame()
        gameState = next
    }

    var body: some View {
        ZStack {
            // Background gradient — dark-mode compatible
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.18),
                    Color(red: 0.12, green: 0.14, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle background orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: -geo.size.width * 0.2, y: -60)
                    .blur(radius: 40)
                Circle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hangman")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        HangmanScoreBar(scores: roundScores)
                    }
                    Spacer()
                    HangmanDifficultyBadge(difficulty: difficulty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                // ── Wrong guess dots ────────────────────────────────
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .frame(width: 12, height: 12)
                            .foregroundColor(i < gameState.wrongGuesses
                                             ? Color.red.opacity(0.9)
                                             : Color.white.opacity(0.18))
                            .animation(.spring(response: 0.3), value: gameState.wrongGuesses)
                    }
                    Text("\(gameState.wrongGuesses)/6 wrong")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                // ── Hint ────────────────────────────────────────────
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow.opacity(0.8))
                    Text(gameState.currentWord.hint)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── Drawing panel (glassmorphism) ───────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                    HangmanDrawingView(wrongGuesses: gameState.wrongGuesses, difficulty: difficulty)
                        .padding(8)
                }
                .frame(height: 180)
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                // ── Word blanks ─────────────────────────────────────
                HangmanWordDisplay(displayChars: gameState.displayWord())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Spacer(minLength: 8)

                // ── Alphabet buttons (glass card) ───────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.10), lineWidth: 1)

                    VStack(spacing: 0) {
                        HangmanAlphabetGrid(
                            guessedLetters: gameState.guessedLetters,
                            wordLetters: wordLetters,
                            onTap: { letter in
                                gameState.guessLetter(letter)
                                if gameState.isGameOver {
                                    handleGameOver()
                                }
                            }
                        )
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }

            // ── Game over overlay ───────────────────────────────────
            if showOverlay {
                HangmanGameOverOverlay(
                    isWon: gameState.isWon,
                    word: gameState.currentWord.word,
                    score: gameState.roundScore,
                    difficulty: difficulty,
                    onRestart: restartGame
                )
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            gameState.startNewGame()
        }
    }
}

// MARK: - Alphabet Grid 

struct HangmanAlphabetGrid: View {
    let guessedLetters: Set<Character>
    let wordLetters: Set<Character>
    let onTap: (Character) -> Void

    private let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

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
        .padding(.horizontal, 10)
    }
}
