import SwiftUI

// MARK: - Models

struct AnagramWord {
    let word: String
    var scrambled: [Character]
}

struct AnagramLetterTile: Identifiable {
    let id = UUID()
    let character: Character
    var isSelected: Bool = false
    var selectionOrder: Int? = nil
}

// MARK: - Game State

enum AnagramGameState {
    case idle
    case playing
    case finished
}

// MARK: - View Model

class AnagramViewModel: ObservableObject {

    private let wordList: [String] = [
        "SWIFT", "APPLE", "PHONE", "CRANE", "GLOBE",
        "TIGER", "LUNAR", "PRIZE", "FLAME", "STORM",
        "BRAVE", "CLOUD", "DREAM", "FROST", "GROVE",
        "HEART", "IVORY", "JEWEL", "KNACK", "LEMON"
    ]

    @Published var currentWordIndex: Int = 0
    @Published var tiles: [AnagramLetterTile] = []
    @Published var selectedOrder: [UUID] = []
    @Published var timeLeft: Int = 30
    @Published var score: Int = 0
    @Published var gameState: AnagramGameState = .idle
    @Published var shakeOffset: CGFloat = 0
    @Published var feedbackMessage: String = ""
    @Published var showFeedback: Bool = false

    private var timer: Timer?
    private var shakeTimer: Timer?

    var currentWord: String {
        guard currentWordIndex < wordList.count else { return "" }
        return wordList[currentWordIndex]
    }

    var totalWords: Int { wordList.count }

    var typedWord: String {
        selectedOrder.compactMap { id in
            tiles.first(where: { $0.id == id })?.character
        }.map { String($0) }.joined()
    }

    func startGame() {
        score = 0
        currentWordIndex = 0
        gameState = .playing
        loadCurrentWord()
        startTimer()
    }

    func loadCurrentWord() {
        guard currentWordIndex < wordList.count else {
            endGame()
            return
        }
        let word = wordList[currentWordIndex]
        let chars = Array(word)
        // Shuffle until different from the original
        var shuffled = chars.shuffled()
        var attempts = 0
        while shuffled == chars && attempts < 10 {
            shuffled = chars.shuffled()
            attempts += 1
        }
        tiles = shuffled.map { AnagramLetterTile(character: $0) }
        selectedOrder = []
        timeLeft = 30
    }

    func selectTile(id: UUID) {
        guard gameState == .playing else { return }
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        guard !tiles[index].isSelected else { return }

        tiles[index].isSelected = true
        tiles[index].selectionOrder = selectedOrder.count
        selectedOrder.append(id)

        // Check if all letters selected
        if selectedOrder.count == currentWord.count {
            checkAnswer()
        }
    }

    func deselectLast() {
        guard !selectedOrder.isEmpty else { return }
        let lastId = selectedOrder.removeLast()
        if let index = tiles.firstIndex(where: { $0.id == lastId }) {
            tiles[index].isSelected = false
            tiles[index].selectionOrder = nil
        }
        // Update selection orders
        for i in tiles.indices {
            if tiles[i].selectionOrder != nil {
                if let pos = selectedOrder.firstIndex(of: tiles[i].id) {
                    tiles[i].selectionOrder = pos
                }
            }
        }
    }

    func clearSelection() {
        for i in tiles.indices {
            tiles[i].isSelected = false
            tiles[i].selectionOrder = nil
        }
        selectedOrder = []
    }

    func skipWord() {
        guard gameState == .playing else { return }
        nextWord()
    }

    private func checkAnswer() {
        let answer = typedWord
        if answer == currentWord {
            score += 1
            showFeedbackMessage("Correct!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.nextWord()
            }
        } else {
            triggerShake()
            showFeedbackMessage("Wrong order!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.clearSelection()
            }
        }
    }

    private func nextWord() {
        currentWordIndex += 1
        if currentWordIndex >= wordList.count {
            endGame()
        } else {
            loadCurrentWord()
        }
    }

    private func endGame() {
        gameState = .finished
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeLeft > 0 {
                self.timeLeft -= 1
            } else {
                self.skipWord()
            }
        }
    }

    private func triggerShake() {
        let shakeSequence: [CGFloat] = [-10, 10, -8, 8, -5, 5, 0]
        var delay: Double = 0
        for offset in shakeSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    self.shakeOffset = offset
                }
            }
            delay += 0.06
        }
    }

    private func showFeedbackMessage(_ msg: String) {
        feedbackMessage = msg
        withAnimation { showFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { self.showFeedback = false }
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Main View

struct AnagramView: View {

    @StateObject private var viewModel = AnagramViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.18), Color(red: 0.12, green: 0.05, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.gameState {
            case .idle:
                AnagramMenuView(onStart: { viewModel.startGame() })
            case .playing:
                AnagramPlayView(viewModel: viewModel)
            case .finished:
                AnagramResultView(score: viewModel.score, total: viewModel.totalWords, onRestart: { viewModel.startGame() })
            }
        }
    }
}

// MARK: - Menu View

struct AnagramMenuView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("ANAGRAM")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.8), radius: 12)

                Text("Unscramble the letters!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 10) {
                AnagramRuleRow(icon: "shuffle", text: "Tap letters in the correct order")
                AnagramRuleRow(icon: "timer", text: "30 seconds per word")
                AnagramRuleRow(icon: "list.number", text: "20 words total")
                AnagramRuleRow(icon: "arrow.forward.circle", text: "Skip if you're stuck")
            }
            .padding(20)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button(action: onStart) {
                Text("Start Game")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.5), radius: 10)
            }
        }
        .padding(28)
    }
}

struct AnagramRuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Play View

struct AnagramPlayView: View {
    @ObservedObject var viewModel: AnagramViewModel

    var body: some View {
        VStack(spacing: 24) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Word \(viewModel.currentWordIndex + 1)/\(viewModel.totalWords)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Score: \(viewModel.score)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                AnagramTimerView(timeLeft: viewModel.timeLeft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Answer Display
            AnagramAnswerDisplay(
                targetLength: viewModel.currentWord.count,
                selectedIds: viewModel.selectedOrder,
                tiles: viewModel.tiles,
                shakeOffset: viewModel.shakeOffset
            )

            // Feedback
            if viewModel.showFeedback {
                Text(viewModel.feedbackMessage)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.feedbackMessage == "Correct!" ? .green : .red)
                    .transition(.opacity.combined(with: .scale))
            } else {
                Text(" ")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            // Letter Tiles
            AnagramTileGrid(tiles: viewModel.tiles) { id in
                viewModel.selectTile(id: id)
            }
            .offset(x: viewModel.shakeOffset)

            // Controls
            HStack(spacing: 16) {
                Button(action: { viewModel.clearSelection() }) {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { viewModel.deselectLast() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward.circle")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { viewModel.skipWord() }) {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Spacer()
        }
        .animation(.default, value: viewModel.showFeedback)
    }
}

// MARK: - Answer Display

struct AnagramAnswerDisplay: View {
    let targetLength: Int
    let selectedIds: [UUID]
    let tiles: [AnagramLetterTile]
    let shakeOffset: CGFloat

    var selectedChars: [Character?] {
        var chars: [Character?] = Array(repeating: nil, count: targetLength)
        for (i, id) in selectedIds.enumerated() {
            if i < targetLength, let tile = tiles.first(where: { $0.id == id }) {
                chars[i] = tile.character
            }
        }
        return chars
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<targetLength, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    if index < selectedChars.count, let char = selectedChars[index] {
                        Text(String(char))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .offset(x: shakeOffset)
    }
}

// MARK: - Tile Grid

struct AnagramTileGrid: View {
    let tiles: [AnagramLetterTile]
    let onTap: (UUID) -> Void

    let columns = [
        GridItem(.adaptive(minimum: 56), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tiles) { tile in
                AnagramTileButton(tile: tile) {
                    onTap(tile.id)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Tile Button

struct AnagramTileButton: View {
    let tile: AnagramLetterTile
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if !tile.isSelected { onTap() }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tile.isSelected
                          ? AnyShapeStyle(Color.purple.opacity(0.25))
                          : AnyShapeStyle(LinearGradient(
                            colors: [Color(white: 0.25), Color(white: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                    )
                    .frame(width: 56, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                tile.isSelected ? Color.purple.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: tile.isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                if tile.isSelected {
                    Text(String(tile.character))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    Text(String(tile.character))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(tile.isSelected)
        .scaleEffect(tile.isSelected ? 0.93 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: tile.isSelected)
    }
}

// MARK: - Timer View

struct AnagramTimerView: View {
    let timeLeft: Int

    var timerColor: Color {
        if timeLeft > 15 { return .green }
        if timeLeft > 8 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 56, height: 56)

            Circle()
                .trim(from: 0, to: CGFloat(timeLeft) / 30.0)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timeLeft)

            Text("\(timeLeft)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(timerColor)
        }
    }
}

// MARK: - Result View

struct AnagramResultView: View {
    let score: Int
    let total: Int
    let onRestart: () -> Void

    var percentage: Double { Double(score) / Double(total) }

    var resultEmoji: String {
        if percentage >= 0.9 { return "🏆" }
        if percentage >= 0.7 { return "⭐" }
        if percentage >= 0.5 { return "👍" }
        return "💪"
    }

    var resultMessage: String {
        if percentage >= 0.9 { return "Excellent!" }
        if percentage >= 0.7 { return "Great Job!" }
        if percentage >= 0.5 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text(resultEmoji)
                    .font(.system(size: 64))
                Text(resultMessage)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text("Final Score")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                Text("\(score) / \(total)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 16)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * CGFloat(percentage), height: 16)
                            .animation(.easeOut(duration: 0.8), value: percentage)
                    }
                }
                .frame(height: 16)
            }
            .padding(24)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Button(action: onRestart) {
                Text("Play Again")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.5), radius: 10)
            }
        }
        .padding(28)
    }
}
