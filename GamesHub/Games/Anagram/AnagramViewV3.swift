import SwiftUI

// MARK: - LCG Seed Helpers

private func anagramLCGNext(_ s: inout UInt64) -> UInt64 {
    s = s &* 6364136223846793005 &+ 1442695040888963407
    return s
}

private func anagramLCGShuffle<T>(_ array: inout [T], seed: inout UInt64) {
    for i in stride(from: array.count - 1, through: 1, by: -1) {
        let j = Int(anagramLCGNext(&seed) % UInt64(i + 1))
        array.swapAt(i, j)
    }
}

// MARK: - Models

struct AnagramV3LetterTile: Identifiable {
    let id: Int
    let character: Character
    var isSelected: Bool = false
    var selectionIndex: Int? = nil
}

enum AnagramV3GamePhase {
    case menu
    case playing
    case finished
}

// MARK: - Word Bank

private let anagramV3WordBank: [String] = [
    "SWIFT", "APPLE", "PHONE", "CRANE", "GLOBE",
    "TIGER", "LUNAR", "PRIZE", "FLAME", "STORM",
    "BRAVE", "CLOUD", "DREAM", "FROST", "GROVE",
    "HEART", "IVORY", "JEWEL", "KNACK", "LEMON",
    "MAPLE", "NOBLE", "OPERA", "PLAZA", "QUEST",
    "RIVER", "SOLAR", "TRACE", "ULTRA", "VIVID"
]

// MARK: - Main View

struct AnagramViewV3: View {

    @State var seedInt: Int = 1
    @State private var phase: AnagramV3GamePhase = .menu

    // Game state
    @State private var wordList: [String] = []
    @State private var wordIndex: Int = 0
    @State private var tiles: [AnagramV3LetterTile] = []
    @State private var selectedOrder: [Int] = []
    @State private var timeLeft: Int = 30
    @State private var score: Int = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var isCorrect: Bool = false

    @State private var gameTimer: Timer? = nil

    var currentWord: String {
        guard wordIndex < wordList.count else { return "" }
        return wordList[wordIndex]
    }

    var typedWord: String {
        selectedOrder.compactMap { tileId in
            tiles.first(where: { $0.id == tileId })?.character
        }.map { String($0) }.joined()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            switch phase {
            case .menu:
                AnagramV3MenuView(seedInt: seedInt, onStart: startGame)
            case .playing:
                AnagramV3PlayView(
                    seedInt: seedInt,
                    wordIndex: wordIndex,
                    totalWords: wordList.count,
                    currentWord: currentWord,
                    tiles: tiles,
                    selectedOrder: selectedOrder,
                    timeLeft: timeLeft,
                    score: score,
                    shakeOffset: shakeOffset,
                    feedbackText: feedbackText,
                    showFeedback: showFeedback,
                    isCorrect: isCorrect,
                    onTap: selectTile,
                    onClear: clearSelection,
                    onUndo: deselectLast,
                    onSkip: skipWord
                )
            case .finished:
                AnagramV3ResultView(
                    seedInt: seedInt,
                    score: score,
                    total: wordList.count,
                    onRestart: restartGame
                )
            }
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        score = 0
        wordIndex = 0
        phase = .playing
        wordList = buildWordList()
        loadCurrentWord()
        startCountdown()
    }

    private func restartGame() {
        seedInt += 1
        startGame()
    }

    private func buildWordList() -> [String] {
        var s = UInt64(seedInt)
        _ = anagramLCGNext(&s)
        var pool = anagramV3WordBank
        anagramLCGShuffle(&pool, seed: &s)
        return Array(pool.prefix(20))
    }

    private func loadCurrentWord() {
        guard wordIndex < wordList.count else {
            endGame()
            return
        }
        let word = wordList[wordIndex]
        var chars = Array(word)

        // Deterministic scramble: seed derived from seedInt + wordIndex
        var s = UInt64(seedInt) &+ UInt64(wordIndex) &* 31337
        _ = anagramLCGNext(&s)
        anagramLCGShuffle(&chars, seed: &s)

        // Ensure scramble differs from original (try up to 5 times)
        var attempts = 0
        while String(chars) == word && attempts < 5 {
            anagramLCGShuffle(&chars, seed: &s)
            attempts += 1
        }

        tiles = chars.enumerated().map { idx, ch in
            AnagramV3LetterTile(id: idx, character: ch)
        }
        selectedOrder = []
        timeLeft = 30
    }

    private func selectTile(id: Int) {
        guard phase == .playing else { return }
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        guard !tiles[index].isSelected else { return }

        tiles[index].isSelected = true
        tiles[index].selectionIndex = selectedOrder.count
        selectedOrder.append(id)

        if selectedOrder.count == currentWord.count {
            checkAnswer()
        }
    }

    private func deselectLast() {
        guard !selectedOrder.isEmpty else { return }
        let lastId = selectedOrder.removeLast()
        if let index = tiles.firstIndex(where: { $0.id == lastId }) {
            tiles[index].isSelected = false
            tiles[index].selectionIndex = nil
        }
    }

    private func clearSelection() {
        for i in tiles.indices {
            tiles[i].isSelected = false
            tiles[i].selectionIndex = nil
        }
        selectedOrder = []
    }

    private func skipWord() {
        guard phase == .playing else { return }
        advanceWord()
    }

    private func checkAnswer() {
        if typedWord == currentWord {
            score += 1
            isCorrect = true
            showFeedbackBanner("Correct!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                advanceWord()
            }
        } else {
            isCorrect = false
            showFeedbackBanner("Wrong order!")
            triggerShake()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                clearSelection()
            }
        }
    }

    private func advanceWord() {
        wordIndex += 1
        if wordIndex >= wordList.count {
            endGame()
        } else {
            loadCurrentWord()
        }
    }

    private func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        phase = .finished
    }

    private func startCountdown() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard phase == .playing else { return }
            if timeLeft > 0 {
                timeLeft -= 1
            } else {
                skipWord()
            }
        }
    }

    private func triggerShake() {
        let offsets: [CGFloat] = [-10, 10, -8, 8, -5, 5, 0]
        var delay: Double = 0
        for offset in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    shakeOffset = offset
                }
            }
            delay += 0.06
        }
    }

    private func showFeedbackBanner(_ msg: String) {
        feedbackText = msg
        withAnimation(.easeIn(duration: 0.15)) { showFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
        }
    }
}

// MARK: - Menu View

struct AnagramV3MenuView: View {
    let seedInt: Int
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 10) {
                Text("ANAGRAM")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text("V3 · Procedural")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)
            }

            VStack(spacing: 0) {
                AnagramV3RuleRow(icon: "shuffle", text: "Tap letters in correct order")
                Divider().padding(.horizontal, 16)
                AnagramV3RuleRow(icon: "timer", text: "30 seconds per word")
                Divider().padding(.horizontal, 16)
                AnagramV3RuleRow(icon: "list.number", text: "20 words per round")
                Divider().padding(.horizontal, 16)
                AnagramV3RuleRow(icon: "arrow.forward.circle", text: "Skip if stuck")
                Divider().padding(.horizontal, 16)
                AnagramV3RuleRow(icon: "dice", text: "Seed determines word order")
            }
            .neumorphicCard(radius: 18)
            .padding(.horizontal, 24)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Game")
                        .fontWeight(.bold)
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

struct AnagramV3RuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// MARK: - Play View

struct AnagramV3PlayView: View {
    let seedInt: Int
    let wordIndex: Int
    let totalWords: Int
    let currentWord: String
    let tiles: [AnagramV3LetterTile]
    let selectedOrder: [Int]
    let timeLeft: Int
    let score: Int
    let shakeOffset: CGFloat
    let feedbackText: String
    let showFeedback: Bool
    let isCorrect: Bool
    let onTap: (Int) -> Void
    let onClear: () -> Void
    let onUndo: () -> Void
    let onSkip: () -> Void

    var selectedChars: [Character?] {
        var result: [Character?] = Array(repeating: nil, count: currentWord.count)
        for (pos, id) in selectedOrder.enumerated() {
            if let tile = tiles.first(where: { $0.id == id }), pos < currentWord.count {
                result[pos] = tile.character
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(width: 70, alignment: .leading)

                Spacer()

                VStack(spacing: 4) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                    Text("Word \(wordIndex + 1) of \(totalWords)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                AnagramV3TimerRing(timeLeft: timeLeft)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .neumorphicCard(radius: 0)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 24) {

                    // Answer slots
                    VStack(spacing: 10) {
                        Text("Spell the word")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(0..<currentWord.count, id: \.self) { i in
                                AnagramV3SlotView(character: i < selectedChars.count ? selectedChars[i] : nil)
                            }
                        }
                        .offset(x: shakeOffset)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .neumorphicCard(radius: 18)
                    .padding(.horizontal, 20)

                    // Feedback banner
                    ZStack {
                        if showFeedback {
                            Text(feedbackText)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(isCorrect ? .green : .red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .neumorphicCard(radius: 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        } else {
                            Color.clear.frame(height: 42)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showFeedback)

                    // Letter tiles
                    AnagramV3TileGrid(tiles: tiles, onTap: onTap)
                        .padding(.horizontal, 20)

                    // Controls
                    HStack(spacing: 12) {
                        AnagramV3ControlButton(label: "Clear", icon: "xmark.circle.fill", color: .secondary) {
                            onClear()
                        }
                        AnagramV3ControlButton(label: "Undo", icon: "arrow.uturn.backward", color: .secondary) {
                            onUndo()
                        }
                        AnagramV3ControlButton(label: "Skip", icon: "forward.fill", color: .orange) {
                            onSkip()
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - Slot View

struct AnagramV3SlotView: View {
    let character: Character?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
                .frame(width: 42, height: 50)
                .shadow(color: Color.white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: Color(.systemGray4), radius: 4, x: 2, y: 2)

            if let ch = character {
                Text(String(ch))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .transition(.scale.combined(with: .opacity))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: 24, height: 3)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: character != nil)
    }
}

// MARK: - Tile Grid

struct AnagramV3TileGrid: View {
    let tiles: [AnagramV3LetterTile]
    let onTap: (Int) -> Void

    let columns = [GridItem(.adaptive(minimum: 60), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tiles) { tile in
                AnagramV3TileButton(tile: tile, onTap: onTap)
            }
        }
    }
}

// MARK: - Tile Button

struct AnagramV3TileButton: View {
    let tile: AnagramV3LetterTile
    let onTap: (Int) -> Void

    @State private var pressed: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .frame(width: 60, height: 64)
                .shadow(
                    color: tile.isSelected ? Color.clear : Color.white.opacity(0.85),
                    radius: pressed ? 2 : 6, x: pressed ? -1 : -4, y: pressed ? -1 : -4
                )
                .shadow(
                    color: tile.isSelected ? Color.clear : Color(.systemGray4),
                    radius: pressed ? 2 : 6, x: pressed ? 1 : 4, y: pressed ? 1 : 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tile.isSelected
                              ? Color.accentColor.opacity(0.15)
                              : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tile.isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )

            Text(String(tile.character))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(tile.isSelected ? Color.accentColor.opacity(0.4) : .primary)
        }
        .scaleEffect(tile.isSelected ? 0.92 : (pressed ? 0.96 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: tile.isSelected)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed && !tile.isSelected { pressed = true }
                }
                .onEnded { _ in
                    if !tile.isSelected {
                        onTap(tile.id)
                    }
                    pressed = false
                }
        )
        .disabled(tile.isSelected)
    }
}

// MARK: - Control Button

struct AnagramV3ControlButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 14)
        }
    }
}

// MARK: - Timer Ring

struct AnagramV3TimerRing: View {
    let timeLeft: Int

    var ringColor: Color {
        if timeLeft > 15 { return .green }
        if timeLeft > 8 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4).opacity(0.4), lineWidth: 4)
                .frame(width: 52, height: 52)

            Circle()
                .trim(from: 0, to: CGFloat(timeLeft) / 30.0)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timeLeft)

            Text("\(timeLeft)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(ringColor)
        }
    }
}

// MARK: - Result View

struct AnagramV3ResultView: View {
    let seedInt: Int
    let score: Int
    let total: Int
    let onRestart: () -> Void

    var pct: Double { Double(score) / Double(total) }

    var badge: String {
        if pct >= 0.9 { return "trophy.fill" }
        if pct >= 0.7 { return "star.fill" }
        if pct >= 0.5 { return "hand.thumbsup.fill" }
        return "figure.run"
    }

    var badgeColor: Color {
        if pct >= 0.9 { return .yellow }
        if pct >= 0.7 { return .orange }
        if pct >= 0.5 { return .green }
        return .blue
    }

    var message: String {
        if pct >= 0.9 { return "Excellent!" }
        if pct >= 0.7 { return "Great Job!" }
        if pct >= 0.5 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Seed display
            Text("SEED: #\(seedInt)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .neumorphicCard(radius: 10)

            // Badge
            VStack(spacing: 12) {
                Image(systemName: badge)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(badgeColor)
                    .shadow(color: badgeColor.opacity(0.4), radius: 10)

                Text(message)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Score card
            VStack(spacing: 16) {
                Text("Final Score")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("\(score) / \(total)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray4).opacity(0.4))
                            .frame(height: 14)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(pct), height: 14)
                            .animation(.easeOut(duration: 0.9), value: pct)
                    }
                }
                .frame(height: 14)
            }
            .padding(24)
            .neumorphicCard(radius: 20)
            .padding(.horizontal, 24)

            // Buttons
            VStack(spacing: 12) {
                Button(action: onRestart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Seed & Play Again")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
