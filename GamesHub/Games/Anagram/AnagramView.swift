import SwiftUI

// MARK: - Letter Tile

struct AnagramLetterTile: Identifiable {
    let id = UUID()
    let character: Character
    var isSelected: Bool = false
    var selectionOrder: Int? = nil
}

// MARK: - Models

enum AnagramDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var wordLengthRange: ClosedRange<Int> {
        switch self {
        case .easy:   return 3...5
        case .medium: return 5...7
        case .hard:   return 7...10
        }
    }

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

// MARK: - Word Bank

private let anagramWordBank: [String] = [
    // 3-4 letter words (easy)
    "cat", "dog", "bat", "car", "sun", "run", "fan", "map", "cup", "art",
    "hat", "jet", "log", "mud", "net", "owl", "pan", "rat", "sit", "top",
    // 5-6 letter words (medium)
    "angel", "bread", "chair", "dream", "earth", "flame", "grace", "heart",
    "image", "juice", "kneel", "laser", "magic", "night", "ocean", "pizza",
    "queen", "river", "smile", "tiger", "ultra", "voice", "water", "xenon",
    "yacht", "zebra", "blast", "cloud", "dance", "eagle", "frost", "glare",
    "hazel", "ivory", "jewel", "karma", "lance", "maple", "noble", "orbit",
    // 7-10 letter words (hard)
    "captain", "diamond", "element", "fashion", "garland", "harvest",
    "iceberg", "journal", "kitchen", "lantern", "maximum", "network",
    "olympus", "penguin", "quarrel", "rainbow", "silicon", "thermal",
    "uniform", "venture", "warmest", "xylophone", "yearbook", "zeppelin",
    "absolute", "beautiful", "champion", "daughter", "electric", "fearless",
    "grateful", "hospital", "infinity", "jealousy", "keyboard", "laughter"
]

// MARK: - Main View

struct AnagramView: View {

    // MARK: Difficulty & Scoring
    @State private var difficulty: AnagramDifficulty = .easy
    @State private var roundScores: [Int] = []

    // MARK: Game State
    @State private var gamePhase: AnagramGamePhase = .idle
    @State private var currentWord: String = ""
    @State private var scrambledTiles: [AnagramLetterTile] = []
    @State private var selectedTiles: [AnagramLetterTile] = []
    @State private var wordIndex: Int = 0
    @State private var score: Int = 0
    @State private var timeRemaining: Double = 30
    @State private var shakeOffset: CGFloat = 0
    @State private var showCorrectFlash: Bool = false
    @State private var gameTimer: Timer? = nil
    @State private var usedWords: [String] = []

    private let totalWords = 20
    private let timePerWord: Double = 30

    // MARK: Body

    var body: some View {
        ZStack {
            anagramBackground
            switch gamePhase {
            case .idle:
                anagramIdleScreen
            case .playing:
                anagramPlayingScreen
            case .gameOver:
                anagramGameOverScreen
            }
        }
        .preferredColorScheme(.none)
        .onDisappear { stopTimer() }
    }

    // MARK: - Backgrounds

    private var anagramBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.18),
                Color(red: 0.10, green: 0.08, blue: 0.25),
                Color(red: 0.05, green: 0.12, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(anagramStarField)
    }

    private var anagramStarField: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.05...0.25)))
                    .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat((i * 137) % Int(geo.size.width)),
                        y: CGFloat((i * 97 + 50) % Int(geo.size.height))
                    )
            }
        }
    }

    // MARK: - Idle Screen

    private var anagramIdleScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Text("ANAGRAM")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Unscramble the word!")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.75))
            }

            anagramDifficultyBadge(difficulty)
                .scaleEffect(1.2)

            VStack(spacing: 10) {
                anagramGlassLabel("20 words • 30 seconds each")
                anagramGlassLabel("Difficulty adapts to your score")
            }

            Spacer()

            Button(action: startGame) {
                Text("Start Game")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .purple.opacity(0.4), radius: 12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 24)
    }

    private func anagramGlassLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    // MARK: - Playing Screen

    private var anagramPlayingScreen: some View {
        VStack(spacing: 0) {
            anagramHUD
            Spacer()
            anagramWordArea
            Spacer()
            anagramTileArea
            Spacer(minLength: 12)
            anagramControlRow
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
    }

    // HUD
    private var anagramHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(score)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            anagramDifficultyBadge(difficulty)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Word \(wordIndex)/\(totalWords)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(String(format: "%.0fs", timeRemaining))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(timeRemaining <= 8 ? .red : .white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 12)
        .overlay(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(timeRemaining / timePerWord), height: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .animation(.linear(duration: 0.1), value: timeRemaining)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }

    // Word area
    private var anagramWordArea: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                VStack(spacing: 10) {
                    Text("Unscramble:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 6) {
                        ForEach(Array(selectedTiles.enumerated()), id: \.element.id) { _, tile in
                            anagramAnswerCell(tile)
                        }
                        // Empty slots
                        ForEach(0..<(currentWord.count - selectedTiles.count), id: \.self) { _ in
                            anagramEmptyCell
                        }
                    }
                    .offset(x: shakeOffset)
                    .animation(.spring(response: 0.15, dampingFraction: 0.3), value: shakeOffset)
                }
                .padding(20)
            }
            .frame(height: 110)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(showCorrectFlash ? Color.green : Color.white.opacity(0.15), lineWidth: 2)
                    .animation(.easeOut(duration: 0.3), value: showCorrectFlash)
            )
        }
    }

    private func anagramAnswerCell(_ tile: AnagramLetterTile) -> some View {
        Text(String(tile.character).uppercased())
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 38, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(colors: [.cyan.opacity(0.8), .purple.opacity(0.8)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
            )
            .shadow(color: .cyan.opacity(0.3), radius: 4)
    }

    private var anagramEmptyCell: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.08))
            .frame(width: 38, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    // Scrambled tiles
    private var anagramTileArea: some View {
        VStack(spacing: 12) {
            Text("Tap letters in order")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            let columns = min(scrambledTiles.count, 6)
            let rows = Int(ceil(Double(scrambledTiles.count) / Double(columns)))
            VStack(spacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<columns, id: \.self) { col in
                            let idx = row * columns + col
                            if idx < scrambledTiles.count {
                                anagramScrambledTile(idx)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func anagramScrambledTile(_ idx: Int) -> some View {
        let tile = scrambledTiles[idx]
        return Button(action: { tapTile(at: idx) }) {
            Text(String(tile.character).uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(tile.isSelected ? .gray : .white)
                .frame(width: 48, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            tile.isSelected
                                ? AnyShapeStyle(Color.white.opacity(0.08))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.2, blue: 0.45),
                                        Color(red: 0.15, green: 0.15, blue: 0.35)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .shadow(
                            color: tile.isSelected ? .clear : .cyan.opacity(0.2),
                            radius: tile.isSelected ? 0 : 6
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            tile.isSelected ? Color.white.opacity(0.05) : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .scaleEffect(tile.isSelected ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: tile.isSelected)
        }
        .disabled(tile.isSelected)
    }

    // Controls
    private var anagramControlRow: some View {
        HStack(spacing: 16) {
            Button(action: clearSelection) {
                Label("Clear", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            Button(action: skipWord) {
                Label("Skip", systemImage: "forward.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Game Over Screen

    private var anagramGameOverScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)

                Text("Game Over!")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                    )

                // Score glass card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 16)

                    VStack(spacing: 16) {
                        Text("Final Score")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))

                        Text("\(score)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                            )

                        Text("out of \(totalWords)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(30)
                }
                .padding(.horizontal, 30)

                // Stats row
                HStack(spacing: 12) {
                    anagramStatPill(label: "Difficulty", value: difficulty.rawValue, color: difficulty.badgeColor)
                    anagramStatPill(label: "Avg (last 5)", value: anagramAverageScore, color: .cyan)
                }
                .padding(.horizontal, 20)

                // History
                if !roundScores.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Rounds")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.leading, 8)

                        HStack(spacing: 8) {
                            ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                                VStack(spacing: 4) {
                                    Text("\(s)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("/\(totalWords)")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: startGame) {
                    Text("Play Again")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .purple.opacity(0.4), radius: 12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func anagramStatPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Difficulty Badge

    private func anagramDifficultyBadge(_ diff: AnagramDifficulty) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(diff.badgeColor)
                .frame(width: 8, height: 8)
            Text(diff.rawValue)
                .font(.caption.bold())
                .foregroundColor(diff.badgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(diff.badgeColor.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Game Logic

    private func startGame() {
        score = 0
        wordIndex = 0
        usedWords = []
        loadNextWord()
        gamePhase = .playing
        startTimer()
    }

    private func loadNextWord() {
        let range = difficulty.wordLengthRange
        let filtered = anagramWordBank.filter {
            range.contains($0.count) && !usedWords.contains($0)
        }
        guard let word = filtered.randomElement() else {
            // fallback to any unused word
            let unused = anagramWordBank.filter { !usedWords.contains($0) }
            if let fallback = unused.randomElement() {
                setupWord(fallback)
            } else {
                endGame()
            }
            return
        }
        setupWord(word)
    }

    private func setupWord(_ word: String) {
        currentWord = word
        usedWords.append(word)
        selectedTiles = []
        var tiles = word.map { AnagramLetterTile(character: $0) }
        // Ensure scramble differs from original
        var attempts = 0
        repeat {
            tiles.shuffle()
            attempts += 1
        } while tiles.map({ $0.character }) == Array(word) && attempts < 20
        scrambledTiles = tiles
        timeRemaining = timePerWord
    }

    private func tapTile(at index: Int) {
        guard !scrambledTiles[index].isSelected else { return }
        scrambledTiles[index].isSelected = true
        selectedTiles.append(scrambledTiles[index])
        checkAnswer()
    }

    private func checkAnswer() {
        guard selectedTiles.count == currentWord.count else { return }
        let attempt = String(selectedTiles.map { $0.character })
        if attempt == currentWord {
            score += 1
            showCorrectFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showCorrectFlash = false
                advanceWord()
            }
        } else {
            triggerShake()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                clearSelection()
            }
        }
    }

    private func triggerShake() {
        let sequence: [CGFloat] = [10, -10, 8, -8, 5, -5, 0]
        for (i, offset) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                shakeOffset = offset
            }
        }
    }

    private func clearSelection() {
        for i in scrambledTiles.indices {
            scrambledTiles[i].isSelected = false
        }
        selectedTiles = []
    }

    private func skipWord() {
        advanceWord()
    }

    private func advanceWord() {
        wordIndex += 1
        if wordIndex >= totalWords {
            endGame()
        } else {
            loadNextWord()
        }
    }

    private func endGame() {
        stopTimer()
        roundScores.append(score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adjustDifficulty()
        gamePhase = .gameOver
    }

    // MARK: - Difficulty Adaptation

    private var anagramAverageScore: String {
        guard !roundScores.isEmpty else { return "-" }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        return String(format: "%.1f", avg)
    }

    private func adjustDifficulty() {
        guard !roundScores.isEmpty else { return }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        let ratio = avg / Double(totalWords)
        switch ratio {
        case ..<0.35:
            difficulty = .easy
        case 0.35..<0.65:
            difficulty = .medium
        default:
            difficulty = .hard
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard gamePhase == .playing else { return }
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                advanceWord()
            }
        }
    }

    private func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
}

// MARK: - Game Phase

enum AnagramGamePhase {
    case idle, playing, gameOver
}

// MARK: - Preview

#Preview {
    AnagramView()
}
