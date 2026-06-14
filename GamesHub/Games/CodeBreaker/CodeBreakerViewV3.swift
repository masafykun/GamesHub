import SwiftUI

// MARK: - Models

struct CodeBreakerGuess: Identifiable {
    let id = UUID()
    let colors: [CodeBreakerColor]
    let blackPegs: Int
    let whitePegs: Int
}

// MARK: - LCG Seed Generator

struct CodeBreakerLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Int) -> Int {
        return Int(next() % UInt64(range))
    }
}

// MARK: - Main View

struct CodeBreakerViewV3: View {
    @State var seedInt: Int = 1
    @State private var secretCode: [CodeBreakerColor] = []
    @State private var currentGuess: [CodeBreakerColor?] = [nil, nil, nil, nil]
    @State private var selectedSlot: Int = 0
    @State private var guessHistory: [CodeBreakerGuess] = []
    @State private var gameState: CodeBreakerGamePhase = .playing
    @State private var showSecret: Bool = false

    let maxAttempts = 8
    let codeLength = 4

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(spacing: 16) {
                        // Seed display
                        seedView

                        // History
                        historyView

                        // Current guess area
                        if gameState == .playing {
                            currentGuessView
                        }

                        // Color picker
                        if gameState == .playing {
                            colorPickerView
                        }

                        // Action buttons
                        actionButtonsView

                        // Game over banner
                        if gameState != .playing {
                            gameOverView
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .onAppear {
            startNewGame()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .shadow(color: Color(.systemGray4), radius: 4, x: 0, y: 2)
            Text("CODE BREAKER")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .padding(.vertical, 14)
        }
        .frame(height: 56)
    }

    private var seedView: some View {
        HStack {
            Image(systemName: "number.circle.fill")
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
            Text("\(guessHistory.count)/\(maxAttempts)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neumorphicCard()
    }

    private var historyView: some View {
        VStack(spacing: 8) {
            ForEach(guessHistory) { guess in
                CodeBreakerHistoryRow(guess: guess, codeLength: codeLength)
            }

            // Empty slots for remaining guesses
            let remaining = maxAttempts - guessHistory.count
            ForEach(0..<(gameState == .playing ? remaining - 1 : remaining), id: \.self) { _ in
                CodeBreakerEmptyRow(codeLength: codeLength)
            }
        }
    }

    private var currentGuessView: some View {
        VStack(spacing: 10) {
            Text("YOUR GUESS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(2)

            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    CodeBreakerSlotButton(
                        color: currentGuess[index]?.color,
                        isSelected: selectedSlot == index,
                        onTap: { selectedSlot = index }
                    )
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .neumorphicCard()
    }

    private var colorPickerView: some View {
        VStack(spacing: 10) {
            Text("PICK COLOR")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(2)

            HStack(spacing: 10) {
                ForEach(CodeBreakerColor.allCases, id: \.self) { cbColor in
                    Button {
                        currentGuess[selectedSlot] = cbColor
                        if selectedSlot < codeLength - 1 {
                            selectedSlot += 1
                        }
                    } label: {
                        Circle()
                            .fill(cbColor.color)
                            .frame(width: 44, height: 44)
                            .shadow(color: cbColor.color.opacity(0.5), radius: 4, x: 2, y: 2)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .neumorphicCard()
    }

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            if gameState == .playing {
                // Clear current slot
                Button {
                    currentGuess[selectedSlot] = nil
                } label: {
                    Label("Clear", systemImage: "delete.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .neumorphicCard()
                }

                // Submit guess
                Button {
                    submitGuess()
                } label: {
                    Label("Submit", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isGuessComplete ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isGuessComplete ? Color.blue : Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: isGuessComplete ? Color.blue.opacity(0.4) : .clear, radius: 6, x: 0, y: 4)
                }
                .disabled(!isGuessComplete)
            }

            // New Game button
            Button {
                seedInt += 1
                startNewGame()
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .neumorphicCard()
            }
        }
    }

    private var gameOverView: some View {
        VStack(spacing: 12) {
            if gameState == .won {
                Text("YOU WIN!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.green)
                Text("Cracked in \(guessHistory.count) attempt\(guessHistory.count == 1 ? "" : "s")!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                Text("The secret code was:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(0..<secretCode.count, id: \.self) { i in
                        Circle()
                            .fill(secretCode[i].color)
                            .frame(width: 36, height: 36)
                            .shadow(color: secretCode[i].color.opacity(0.5), radius: 4, x: 2, y: 2)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .neumorphicCard()
    }

    // MARK: - Logic

    private var isGuessComplete: Bool {
        currentGuess.allSatisfy { $0 != nil }
    }

    private func startNewGame() {
        var lcg = CodeBreakerLCG(seed: seedInt)
        secretCode = (0..<codeLength).map { _ in
            CodeBreakerColor.allCases[lcg.nextInt(in: CodeBreakerColor.allCases.count)]
        }
        currentGuess = Array(repeating: nil, count: codeLength)
        guessHistory = []
        selectedSlot = 0
        gameState = .playing
        showSecret = false
    }

    private func submitGuess() {
        guard isGuessComplete else { return }
        let guess = currentGuess.compactMap { $0 }
        let (black, white) = evaluateGuess(guess)
        let guessEntry = CodeBreakerGuess(colors: guess, blackPegs: black, whitePegs: white)
        guessHistory.append(guessEntry)

        if black == codeLength {
            gameState = .won
        } else if guessHistory.count >= maxAttempts {
            gameState = .lost
        } else {
            currentGuess = Array(repeating: nil, count: codeLength)
            selectedSlot = 0
        }
    }

    private func evaluateGuess(_ guess: [CodeBreakerColor]) -> (Int, Int) {
        var blackPegs = 0
        var whitePegs = 0

        var secretRemaining: [CodeBreakerColor] = []
        var guessRemaining: [CodeBreakerColor] = []

        for i in 0..<codeLength {
            if guess[i] == secretCode[i] {
                blackPegs += 1
            } else {
                secretRemaining.append(secretCode[i])
                guessRemaining.append(guess[i])
            }
        }

        for color in guessRemaining {
            if let idx = secretRemaining.firstIndex(of: color) {
                whitePegs += 1
                secretRemaining.remove(at: idx)
            }
        }

        return (blackPegs, whitePegs)
    }
}

// MARK: - Supporting Views

struct CodeBreakerHistoryRow: View {
    let guess: CodeBreakerGuess
    let codeLength: Int

    var body: some View {
        HStack(spacing: 10) {
            // Color circles
            HStack(spacing: 8) {
                ForEach(0..<guess.colors.count, id: \.self) { i in
                    Circle()
                        .fill(guess.colors[i].color)
                        .frame(width: 36, height: 36)
                        .shadow(color: guess.colors[i].color.opacity(0.4), radius: 3, x: 1, y: 1)
                }
            }

            Spacer()

            // Peg feedback
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<codeLength, id: \.self) { i in
                        let pegType = pegType(for: i, blacks: guess.blackPegs, whites: guess.whitePegs)
                        Circle()
                            .fill(pegColor(pegType))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .neumorphicCard()
    }

    private func pegType(for index: Int, blacks: Int, whites: Int) -> Int {
        // 2 = black, 1 = white, 0 = empty
        if index < blacks { return 2 }
        if index < blacks + whites { return 1 }
        return 0
    }

    private func pegColor(_ type: Int) -> Color {
        switch type {
        case 2: return .black
        case 1: return .white
        default: return Color(.systemGray4)
        }
    }
}

struct CodeBreakerEmptyRow: View {
    let codeLength: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { _ in
                    Circle()
                        .fill(Color(.systemGray4).opacity(0.4))
                        .frame(width: 36, height: 36)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<codeLength, id: \.self) { _ in
                    Circle()
                        .fill(Color(.systemGray4).opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray5).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .neumorphicCard()
        .opacity(0.5)
    }
}

struct CodeBreakerSlotButton: View {
    let color: Color?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color ?? Color(.systemGray4).opacity(0.3))
                    .frame(width: 52, height: 52)

                if color == nil {
                    Image(systemName: "questionmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .shadow(color: (color ?? .clear).opacity(0.5), radius: 5, x: 2, y: 2)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - Preview

#Preview {
    CodeBreakerViewV3()
}
