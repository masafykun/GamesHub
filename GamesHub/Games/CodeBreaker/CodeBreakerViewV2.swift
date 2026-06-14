import SwiftUI

// MARK: - Models

enum CodeBreakerColorV2: CaseIterable {
    case red, blue, green, yellow, purple, orange

    var color: Color {
        switch self {
        case .red:    return .red
        case .blue:   return .blue
        case .green:  return .green
        case .yellow: return Color.yellow
        case .purple: return .purple
        case .orange: return .orange
        }
    }

    var name: String {
        switch self {
        case .red:    return "Red"
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .yellow: return "Yellow"
        case .purple: return "Purple"
        case .orange: return "Orange"
        }
    }
}

enum CodeBreakerDifficultyV2 {
    case easy    // 3-color code, 5 colors palette
    case medium  // 4-color code, 5 colors palette
    case hard    // 5-color code, 6 colors palette (all colors)

    var codeLength: Int {
        switch self {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var paletteCount: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 5
        case .hard:   return 6
        }
    }

    var maxAttempts: Int { return 8 }

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
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

struct CodeBreakerGuessV2 {
    let colors: [CodeBreakerColorV2]
    let blacks: Int
    let whites: Int
}

enum CodeBreakerGameStateV2 {
    case playing
    case won
    case lost
}

// MARK: - Main View

struct CodeBreakerViewV2: View {
    // Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var difficulty: CodeBreakerDifficultyV2 = .medium

    // Game state
    @State private var secretCode: [CodeBreakerColorV2] = []
    @State private var currentGuess: [CodeBreakerColorV2?] = []
    @State private var guessHistory: [CodeBreakerGuessV2] = []
    @State private var gameState: CodeBreakerGameStateV2 = .playing
    @State private var selectedSlot: Int = 0
    @State private var showSecret: Bool = false
    @State private var animateWin: Bool = false

    private var palette: [CodeBreakerColorV2] {
        Array(CodeBreakerColorV2.allCases.prefix(difficulty.paletteCount))
    }

    private var codeLength: Int { difficulty.codeLength }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.2),
                         Color(red: 0.1, green: 0.05, blue: 0.25),
                         Color(red: 0.05, green: 0.1, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative blobs
            decorativeBlobs

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        secretCodeRow
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        historySection
                            .padding(.horizontal, 16)

                        currentGuessSection
                            .padding(.horizontal, 16)

                        colorPalette
                            .padding(.horizontal, 16)

                        actionButtons
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }

            // Game over overlay
            if gameState != .playing {
                gameOverOverlay
            }
        }
        .onAppear { startNewGame() }
    }

    // MARK: - Subviews

    private var decorativeBlobs: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 120, y: 100)

            Circle()
                .fill(Color.pink.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: 60, y: 300)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Code Breaker")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Attempts: \(guessHistory.count)/\(difficulty.maxAttempts)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Difficulty badge
            difficultyBadge

            // New game button
            Button(action: startNewGame) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var difficultyBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(difficulty.badgeColor)
                .frame(width: 8, height: 8)
            Text(difficulty.label)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(difficulty.badgeColor.opacity(0.5), lineWidth: 1)
        )
    }

    private var secretCodeRow: some View {
        HStack(spacing: 8) {
            Text("Secret:")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 6) {
                ForEach(0..<codeLength, id: \.self) { i in
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )

                        if showSecret, i < secretCode.count {
                            Circle()
                                .fill(secretCode[i].color)
                                .frame(width: 24, height: 24)
                                .shadow(color: secretCode[i].color.opacity(0.6), radius: 4)
                        } else {
                            Image(systemName: "questionmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }

            Spacer()

            Button(action: { showSecret.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: showSecret ? "eye.slash" : "eye")
                    Text(showSecret ? "Hide" : "Reveal")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var historySection: some View {
        VStack(spacing: 6) {
            if guessHistory.isEmpty {
                Text("Make your first guess!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 12)
            } else {
                ForEach(guessHistory.indices, id: \.self) { i in
                    guessRow(guess: guessHistory[i], index: i)
                }
            }
        }
    }

    private func guessRow(guess: CodeBreakerGuessV2, index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 18)

            HStack(spacing: 6) {
                ForEach(0..<guess.colors.count, id: \.self) { i in
                    Circle()
                        .fill(guess.colors[i].color)
                        .frame(width: 30, height: 30)
                        .shadow(color: guess.colors[i].color.opacity(0.5), radius: 3)
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                }
            }

            Spacer()

            // Feedback pegs
            feedbackPegs(blacks: guess.blacks, whites: guess.whites, codeLength: guess.colors.count)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    index == guessHistory.count - 1 ? Color.white.opacity(0.25) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private func feedbackPegs(blacks: Int, whites: Int, codeLength: Int) -> some View {
        let total = codeLength
        let cols = codeLength <= 4 ? 2 : 3
        let rows = Int(ceil(Double(total) / Double(cols)))

        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = row * cols + col
                        if idx < total {
                            Circle()
                                .fill(pegColor(index: idx, blacks: blacks, whites: whites))
                                .frame(width: 10, height: 10)
                                .shadow(
                                    color: idx < blacks ? Color.black.opacity(0.4) :
                                           idx < blacks + whites ? Color.white.opacity(0.3) : Color.clear,
                                    radius: 2
                                )
                        }
                    }
                }
            }
        }
        .frame(width: 36)
    }

    private func pegColor(index: Int, blacks: Int, whites: Int) -> Color {
        if index < blacks { return Color.black.opacity(0.85) }
        if index < blacks + whites { return Color.white.opacity(0.85) }
        return Color.white.opacity(0.12)
    }

    private var currentGuessSection: some View {
        VStack(spacing: 8) {
            Text("Your Guess")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { i in
                    guessSlot(index: i)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func guessSlot(index: Int) -> some View {
        let isSelected = selectedSlot == index
        let color = index < currentGuess.count ? currentGuess[index] : nil

        return ZStack {
            Circle()
                .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isSelected ? Color.white.opacity(0.2) : .clear, radius: 4)

            if let c = color {
                Circle()
                    .fill(c.color)
                    .frame(width: 34, height: 34)
                    .shadow(color: c.color.opacity(0.6), radius: 5)
            } else {
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .onTapGesture {
            if gameState == .playing {
                selectedSlot = index
            }
        }
    }

    private var colorPalette: some View {
        VStack(spacing: 8) {
            Text("Choose Color")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(palette, id: \.name) { c in
                    colorButton(c)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func colorButton(_ c: CodeBreakerColorV2) -> some View {
        let isChosen = selectedSlot < currentGuess.count && currentGuess[selectedSlot] == c

        return Button(action: { placeColor(c) }) {
            ZStack {
                Circle()
                    .fill(c.color)
                    .frame(width: 40, height: 40)
                    .shadow(color: c.color.opacity(0.6), radius: isChosen ? 8 : 3)

                if isChosen {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 40, height: 40)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isChosen ? 1.15 : 1.0)
        .animation(.spring(response: 0.2), value: isChosen)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Clear slot button
            Button(action: clearSlot) {
                HStack(spacing: 6) {
                    Image(systemName: "delete.left")
                    Text("Clear")
                }
                .font(.callout.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Submit button
            Button(action: submitGuess) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Submit")
                }
                .font(.callout.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isGuessComplete ?
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!isGuessComplete || gameState != .playing)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { } // block taps through

            VStack(spacing: 20) {
                // Win/Lose icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)

                    Image(systemName: gameState == .won ? "star.fill" : "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(gameState == .won ? .yellow : .red)
                        .shadow(color: gameState == .won ? .yellow.opacity(0.6) : .red.opacity(0.4), radius: 8)
                }

                Text(gameState == .won ? "Code Cracked!" : "Code Lost!")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text(gameState == .won
                     ? "Solved in \(guessHistory.count) attempt\(guessHistory.count == 1 ? "" : "s")"
                     : "Better luck next time!")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))

                // Secret reveal
                HStack(spacing: 8) {
                    Text("Secret:")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 6) {
                        ForEach(secretCode.indices, id: \.self) { i in
                            Circle()
                                .fill(secretCode[i].color)
                                .frame(width: 28, height: 28)
                                .shadow(color: secretCode[i].color.opacity(0.6), radius: 4)
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                // Stats row
                HStack(spacing: 16) {
                    statItem(label: "Difficulty", value: difficulty.label, color: difficulty.badgeColor)
                    statItem(label: "Avg Score", value: averageScoreText, color: .blue)
                    statItem(label: "Rounds", value: "\(roundScores.count)", color: .purple)
                }

                // Difficulty hint
                if roundScores.count >= 2 {
                    Text(difficultyHintText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                Button(action: startNewGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 180)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .shadow(color: .purple.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 30)
            .padding(.horizontal, 32)
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 80)
    }

    // MARK: - Computed helpers

    private var isGuessComplete: Bool {
        currentGuess.count == codeLength && !currentGuess.contains(nil)
    }

    private var averageScoreText: String {
        guard !roundScores.isEmpty else { return "—" }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        return String(format: "%.1f", avg)
    }

    private var difficultyHintText: String {
        guard roundScores.count >= 2 else { return "" }
        let avg = Double(roundScores.suffix(5).reduce(0, +)) / Double(roundScores.suffix(5).count)
        if avg >= 7 {
            return "Great performance! Difficulty increased."
        } else if avg <= 3 {
            return "Keep practicing! Difficulty decreased."
        } else {
            return "Steady performance. Difficulty maintained."
        }
    }

    // MARK: - Game Logic

    private func startNewGame() {
        let colors = Array(CodeBreakerColorV2.allCases.prefix(difficulty.paletteCount))
        secretCode = (0..<codeLength).map { _ in colors.randomElement()! }
        currentGuess = Array(repeating: nil, count: codeLength)
        guessHistory = []
        gameState = .playing
        selectedSlot = 0
        showSecret = false
        animateWin = false
    }

    private func placeColor(_ color: CodeBreakerColorV2) {
        guard gameState == .playing else { return }
        while currentGuess.count <= selectedSlot {
            currentGuess.append(nil)
        }
        currentGuess[selectedSlot] = color
        // Advance to next empty slot
        advanceSlot()
    }

    private func advanceSlot() {
        // find next nil slot after current
        for i in (selectedSlot + 1)..<codeLength {
            if i >= currentGuess.count || currentGuess[i] == nil {
                selectedSlot = i
                return
            }
        }
        // wrap to first empty
        for i in 0..<codeLength {
            if i >= currentGuess.count || currentGuess[i] == nil {
                selectedSlot = i
                return
            }
        }
        // all filled, stay at last
        selectedSlot = min(selectedSlot, codeLength - 1)
    }

    private func clearSlot() {
        guard gameState == .playing else { return }
        if selectedSlot < currentGuess.count {
            currentGuess[selectedSlot] = nil
        }
    }

    private func submitGuess() {
        guard isGuessComplete, gameState == .playing else { return }

        let guessColors = (0..<codeLength).compactMap { i -> CodeBreakerColorV2? in
            i < currentGuess.count ? currentGuess[i] : nil
        }

        guard guessColors.count == codeLength else { return }

        let (blacks, whites) = computeFeedback(guess: guessColors, secret: secretCode)
        let entry = CodeBreakerGuessV2(colors: guessColors, blacks: blacks, whites: whites)
        guessHistory.append(entry)

        if blacks == codeLength {
            // Won - score based on attempts remaining
            let score = difficulty.maxAttempts - guessHistory.count + 1
            appendScore(score)
            gameState = .won
            animateWin = true
        } else if guessHistory.count >= difficulty.maxAttempts {
            appendScore(0)
            gameState = .lost
        } else {
            // Reset guess
            currentGuess = Array(repeating: nil, count: codeLength)
            selectedSlot = 0
        }
    }

    private func computeFeedback(guess: [CodeBreakerColorV2], secret: [CodeBreakerColorV2]) -> (Int, Int) {
        var blacks = 0
        var secretUsed = Array(repeating: false, count: secret.count)
        var guessUsed = Array(repeating: false, count: guess.count)

        // Count blacks
        for i in 0..<guess.count {
            if guess[i] == secret[i] {
                blacks += 1
                secretUsed[i] = true
                guessUsed[i] = true
            }
        }

        // Count whites
        var whites = 0
        for i in 0..<guess.count where !guessUsed[i] {
            for j in 0..<secret.count where !secretUsed[j] {
                if guess[i] == secret[j] {
                    whites += 1
                    secretUsed[j] = true
                    break
                }
            }
        }

        return (blacks, whites)
    }

    // MARK: - Adaptive Difficulty

    private func appendScore(_ score: Int) {
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        adjustDifficulty()
    }

    private func adjustDifficulty() {
        guard roundScores.count >= 2 else { return }
        let recent = roundScores.suffix(5)
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)

        // avg score near maxAttempts = doing well, increase difficulty
        // avg score near 0 = struggling, decrease difficulty
        if avg >= 6 {
            // Performing very well -> increase difficulty
            switch difficulty {
            case .easy:   difficulty = .medium
            case .medium: difficulty = .hard
            case .hard:   break
            }
        } else if avg <= 2 {
            // Struggling -> decrease difficulty
            switch difficulty {
            case .hard:   difficulty = .medium
            case .medium: difficulty = .easy
            case .easy:   break
            }
        }
        // else keep current difficulty
    }
}

// MARK: - Preview

struct CodeBreakerViewV2_Previews: PreviewProvider {
    static var previews: some View {
        CodeBreakerViewV2()
            .preferredColorScheme(.dark)
    }
}
