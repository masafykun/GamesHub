import SwiftUI

// MARK: - Models

enum CodeBreakerColor: CaseIterable, Equatable {
    case red, blue, green, yellow, purple

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.92, green: 0.25, blue: 0.25)
        case .blue:   return Color(red: 0.22, green: 0.51, blue: 0.94)
        case .green:  return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .yellow: return Color(red: 0.98, green: 0.82, blue: 0.12)
        case .purple: return Color(red: 0.67, green: 0.28, blue: 0.92)
        }
    }

    var name: String {
        switch self {
        case .red:    return "Red"
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .yellow: return "Yellow"
        case .purple: return "Purple"
        }
    }
}

struct CodeBreakerGuessRow: Identifiable {
    let id = UUID()
    let guess: [CodeBreakerColor]
    let blackPegs: Int
    let whitePegs: Int
}

enum CodeBreakerGamePhase {
    case playing, won, lost
}

// MARK: - Game State

class CodeBreakerGameState: ObservableObject {
    static let codeLength = 4
    static let maxAttempts = 8

    @Published var secretCode: [CodeBreakerColor] = []
    @Published var currentGuess: [CodeBreakerColor?] = Array(repeating: nil, count: 4)
    @Published var selectedSlot: Int = 0
    @Published var history: [CodeBreakerGuessRow] = []
    @Published var phase: CodeBreakerGamePhase = .playing
    @Published var showSecret: Bool = false

    init() {
        startGame()
    }

    func startGame() {
        secretCode = (0..<CodeBreakerGameState.codeLength).map { _ in
            CodeBreakerColor.allCases.randomElement()!
        }
        currentGuess = Array(repeating: nil, count: CodeBreakerGameState.codeLength)
        selectedSlot = 0
        history = []
        phase = .playing
        showSecret = false
    }

    func selectSlot(_ index: Int) {
        guard phase == .playing else { return }
        selectedSlot = index
    }

    func placeColor(_ color: CodeBreakerColor) {
        guard phase == .playing else { return }
        currentGuess[selectedSlot] = color
        // Advance to next empty slot or next slot
        if selectedSlot < CodeBreakerGameState.codeLength - 1 {
            selectedSlot += 1
        }
    }

    func clearSlot() {
        guard phase == .playing else { return }
        currentGuess[selectedSlot] = nil
    }

    var canSubmit: Bool {
        currentGuess.allSatisfy { $0 != nil }
    }

    func submitGuess() {
        guard canSubmit, phase == .playing else { return }
        let guess = currentGuess.compactMap { $0 }
        let (black, white) = evaluate(guess: guess, secret: secretCode)
        let row = CodeBreakerGuessRow(guess: guess, blackPegs: black, whitePegs: white)
        history.append(row)

        if black == CodeBreakerGameState.codeLength {
            phase = .won
            showSecret = true
        } else if history.count >= CodeBreakerGameState.maxAttempts {
            phase = .lost
            showSecret = true
        } else {
            currentGuess = Array(repeating: nil, count: CodeBreakerGameState.codeLength)
            selectedSlot = 0
        }
    }

    private func evaluate(guess: [CodeBreakerColor], secret: [CodeBreakerColor]) -> (Int, Int) {
        var black = 0
        var white = 0
        var secretRemaining: [CodeBreakerColor] = []
        var guessRemaining: [CodeBreakerColor] = []

        for i in 0..<CodeBreakerGameState.codeLength {
            if guess[i] == secret[i] {
                black += 1
            } else {
                secretRemaining.append(secret[i])
                guessRemaining.append(guess[i])
            }
        }

        for color in guessRemaining {
            if let idx = secretRemaining.firstIndex(of: color) {
                white += 1
                secretRemaining.remove(at: idx)
            }
        }

        return (black, white)
    }
}

// MARK: - Main View

struct CodeBreakerView: View {
    @StateObject private var gameState = CodeBreakerGameState()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.18).ignoresSafeArea()

                VStack(spacing: 0) {
                    CodeBreakerHeaderView(
                        attemptsLeft: CodeBreakerGameState.maxAttempts - gameState.history.count,
                        phase: gameState.phase
                    )

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 8) {
                                // History rows (oldest first)
                                ForEach(Array(gameState.history.enumerated()), id: \.element.id) { index, row in
                                    CodeBreakerHistoryRowView(
                                        attemptNumber: index + 1,
                                        row: row
                                    )
                                    .id(row.id)
                                }

                                // Current input row (only if playing)
                                if gameState.phase == .playing {
                                    CodeBreakerInputRowView(
                                        guess: gameState.currentGuess,
                                        selectedSlot: gameState.selectedSlot,
                                        attemptNumber: gameState.history.count + 1,
                                        onSelectSlot: { gameState.selectSlot($0) }
                                    )
                                    .id("inputRow")
                                }

                                // Empty placeholder rows
                                let emptyRows = CodeBreakerGameState.maxAttempts
                                    - gameState.history.count
                                    - (gameState.phase == .playing ? 1 : 0)
                                ForEach(0..<max(0, emptyRows), id: \.self) { i in
                                    CodeBreakerEmptyRowView(
                                        attemptNumber: gameState.history.count
                                            + (gameState.phase == .playing ? 2 : 1) + i
                                    )
                                }

                                Spacer(minLength: 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .onChange(of: gameState.history.count) {
                            withAnimation {
                                proxy.scrollTo("inputRow", anchor: .bottom)
                            }
                        }
                    }

                    // Secret code row (shown at end)
                    if gameState.showSecret {
                        CodeBreakerSecretRevealView(secret: gameState.secretCode)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }

                    // Color picker palette
                    if gameState.phase == .playing {
                        CodeBreakerPaletteView(
                            onSelectColor: { gameState.placeColor($0) },
                            onClear: { gameState.clearSlot() },
                            onSubmit: { gameState.submitGuess() },
                            canSubmit: gameState.canSubmit
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 8 : 16)
                    }

                    // Game over controls
                    if gameState.phase != .playing {
                        CodeBreakerEndView(
                            phase: gameState.phase,
                            onRestart: { gameState.startGame() }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 8 : 16)
                    }
                }
            }
        }
    }
}

// MARK: - Header

struct CodeBreakerHeaderView: View {
    let attemptsLeft: Int
    let phase: CodeBreakerGamePhase

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CODE BREAKER")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("Crack the 4-color secret code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(attemptsLeft)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(attemptsLeft <= 2 ? Color(red: 0.92, green: 0.25, blue: 0.25) : .white)
                Text("left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.16, green: 0.16, blue: 0.22))
    }
}

// MARK: - Peg Row (black/white feedback)

struct CodeBreakerPegFeedbackView: View {
    let blackPegs: Int
    let whitePegs: Int

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { col in
                        let pegIndex = row * 2 + col
                        let isBlack = pegIndex < blackPegs
                        let isWhite = pegIndex < (blackPegs + whitePegs)
                        Circle()
                            .fill(
                                isBlack ? Color.black :
                                isWhite ? Color.white :
                                Color.white.opacity(0.15)
                            )
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Color Circle

struct CodeBreakerColorCircle: View {
    let color: CodeBreakerColor?
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color?.color ?? Color.white.opacity(0.08))
                .frame(width: size, height: size)
                .shadow(color: color?.color.opacity(0.5) ?? .clear, radius: isSelected ? 8 : 4)

            if color == nil {
                Circle()
                    .stroke(
                        isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.25),
                        style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: isSelected ? [] : [4, 3])
                    )
                    .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle()
                .stroke(
                    isSelected ? Color.white : Color.clear,
                    lineWidth: 3
                )
                .frame(width: size + 6, height: size + 6)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - History Row

struct CodeBreakerHistoryRowView: View {
    let attemptNumber: Int
    let row: CodeBreakerGuessRow

    var body: some View {
        HStack(spacing: 12) {
            Text("\(attemptNumber)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(width: 20)

            HStack(spacing: 10) {
                ForEach(0..<row.guess.count, id: \.self) { i in
                    CodeBreakerColorCircle(
                        color: row.guess[i],
                        size: 36,
                        isSelected: false
                    )
                }
            }

            Spacer()

            CodeBreakerPegFeedbackView(
                blackPegs: row.blackPegs,
                whitePegs: row.whitePegs
            )

            // Feedback label
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 3) {
                    Circle().fill(Color.black).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                    Text("\(row.blackPegs)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                HStack(spacing: 3) {
                    Circle().fill(Color.white).frame(width: 7, height: 7)
                    Text("\(row.whitePegs)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            .frame(width: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.18, green: 0.18, blue: 0.24))
        )
    }
}

// MARK: - Input Row

struct CodeBreakerInputRowView: View {
    let guess: [CodeBreakerColor?]
    let selectedSlot: Int
    let attemptNumber: Int
    let onSelectSlot: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(attemptNumber)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.8))
                .frame(width: 20)

            HStack(spacing: 10) {
                ForEach(0..<guess.count, id: \.self) { i in
                    CodeBreakerColorCircle(
                        color: guess[i],
                        size: 36,
                        isSelected: selectedSlot == i
                    )
                    .onTapGesture {
                        onSelectSlot(i)
                    }
                }
            }

            Spacer()

            // Empty peg area placeholder
            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .frame(width: 30, height: 30)

            Text("?")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.20, green: 0.22, blue: 0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.40, green: 0.50, blue: 0.90).opacity(0.6), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Empty Row

struct CodeBreakerEmptyRowView: View {
    let attemptNumber: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(attemptNumber)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
                .frame(width: 20)

            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
            }

            Spacer()

            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            .frame(width: 30, height: 30)

            Spacer().frame(width: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.20))
        )
        .opacity(0.5)
    }
}

// MARK: - Secret Reveal

struct CodeBreakerSecretRevealView: View {
    let secret: [CodeBreakerColor]

    var body: some View {
        HStack(spacing: 12) {
            Text("SECRET")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
                .frame(width: 55)

            HStack(spacing: 10) {
                ForEach(0..<secret.count, id: \.self) { i in
                    Circle()
                        .fill(secret[i].color)
                        .frame(width: 36, height: 36)
                        .shadow(color: secret[i].color.opacity(0.6), radius: 6)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.22, green: 0.18, blue: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.90, green: 0.70, blue: 0.20).opacity(0.6), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Palette (color picker + submit)

struct CodeBreakerPaletteView: View {
    let onSelectColor: (CodeBreakerColor) -> Void
    let onClear: () -> Void
    let onSubmit: () -> Void
    let canSubmit: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Color buttons
            HStack(spacing: 10) {
                ForEach(CodeBreakerColor.allCases, id: \.self) { color in
                    Button {
                        onSelectColor(color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 44, height: 44)
                            .shadow(color: color.color.opacity(0.6), radius: 6)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Action row
            HStack(spacing: 12) {
                // Clear button
                Button(action: onClear) {
                    HStack(spacing: 6) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Clear")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.35, green: 0.18, blue: 0.18))
                    )
                }
                .buttonStyle(.plain)

                // Submit button
                Button(action: onSubmit) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Submit")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(canSubmit ? .white : Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                canSubmit
                                    ? Color(red: 0.18, green: 0.45, blue: 0.25)
                                    : Color(red: 0.20, green: 0.20, blue: 0.25)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.22))
        )
        .padding(.bottom, 4)
    }
}

// MARK: - End Screen

struct CodeBreakerEndView: View {
    let phase: CodeBreakerGamePhase
    let onRestart: () -> Void

    var isWon: Bool { phase == .won }

    var body: some View {
        VStack(spacing: 12) {
            Text(isWon ? "YOU CRACKED IT!" : "CODE REMAINS HIDDEN")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundColor(isWon ? Color(red: 0.20, green: 0.88, blue: 0.45) : Color(red: 0.92, green: 0.30, blue: 0.30))
                .multilineTextAlignment(.center)

            Button(action: onRestart) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                    Text("New Game")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isWon
                                ? Color(red: 0.18, green: 0.50, blue: 0.28)
                                : Color(red: 0.38, green: 0.18, blue: 0.18)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.22))
        )
        .padding(.bottom, 4)
    }
}
