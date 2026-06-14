import SwiftUI

// MARK: - Difficulty

enum LightsOutDifficulty {
    case easy    // 4x4
    case medium  // 5x5
    case hard    // 6x6

    var gridSize: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 5
        case .hard:   return 6
        }
    }

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

// MARK: - Game Logic

// MARK: - Main View

struct LightsOutViewV2: View {
    @State private var difficulty: LightsOutDifficulty = .medium
    @State private var game: LightsOutGameState = LightsOutGameState()
    @State private var roundScores: [Int] = []
    @State private var elapsedTime: Int = 0
    @State private var showWin: Bool = false
    @State private var timer: Timer? = nil
    @State private var tappedCell: (Int, Int)? = nil

    // Score = moves * elapsed seconds (lower = better, for moving average)
    private var currentScore: Int { game.moves * max(1, elapsedTime) }

    // Moving average of last 5 scores
    private var movingAverage: Double {
        guard !roundScores.isEmpty else { return 0 }
        return Double(roundScores.reduce(0, +)) / Double(roundScores.count)
    }

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 20) {
                headerBar
                difficultyBadge
                statsRow
                gridView
                Spacer()
                restartButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if showWin {
                winOverlay
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.18),
                Color(red: 0.05, green: 0.05, blue: 0.12)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerBar: some View {
        Text("Lights Out")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.cyan, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: .cyan.opacity(0.4), radius: 8)
    }

    // MARK: - Difficulty Badge

    private var difficultyBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(difficulty.badgeColor)
                .frame(width: 10, height: 10)
                .shadow(color: difficulty.badgeColor.opacity(0.8), radius: 4)
            Text(difficulty.label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(difficulty.badgeColor)
            Text("• \(LightsOutGrid.size)×\(LightsOutGrid.size)")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(difficulty.badgeColor.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(icon: "hand.tap", label: "Moves", value: "\(game.moves)")
            statCard(icon: "clock", label: "Time", value: timeString(elapsedTime))
            if !roundScores.isEmpty {
                statCard(icon: "chart.line.uptrend.xyaxis", label: "Avg Score", value: String(format: "%.0f", movingAverage))
            }
        }
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan.opacity(0.8))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Grid

    private var gridView: some View {
        GeometryReader { geo in
            let totalPadding: CGFloat = 24
            let spacing: CGFloat = 8
            let gridWidth = geo.size.width - totalPadding
            let cellSize = (gridWidth - spacing * CGFloat(LightsOutGrid.size - 1)) / CGFloat(LightsOutGrid.size)

            VStack(spacing: spacing) {
                ForEach(0..<LightsOutGrid.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<LightsOutGrid.size, id: \.self) { col in
                            cellView(row: row, col: col, size: cellSize)
                        }
                    }
                }
            }
            .padding(totalPadding / 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .frame(width: geo.size.width, height: CGFloat(LightsOutGrid.size) * (cellSize + spacing) + spacing + totalPadding)
        }
        .frame(height: CGFloat(LightsOutGrid.size) * 60 + 48)
    }

    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isLit = game.grid.cells[row][col]
        let isTapped = tappedCell.map { $0 == (row, col) } ?? false

        return RoundedRectangle(cornerRadius: 10)
            .fill(
                isLit
                ? LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color(white: 0.15), Color(white: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isLit ? Color.yellow.opacity(0.6) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isLit ? Color.yellow.opacity(0.6) : .clear,
                radius: isTapped ? 12 : 6
            )
            .scaleEffect(isTapped ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isTapped)
            .animation(.easeInOut(duration: 0.15), value: isLit)
            .onTapGesture {
                handleCellTap(row: row, col: col)
            }
    }

    // MARK: - Tap Handler

    private func handleCellTap(row: Int, col: Int) {
        guard !showWin else { return }
        tappedCell = (row, col)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            tappedCell = nil
        }
        game.tap(row: row, col: col)
        if game.isWon {
            stopTimer()
            recordScore()
            showWin = true
        }
    }

    // MARK: - Score & Difficulty Adaptation

    private func recordScore() {
        let score = game.moves * max(1, elapsedTime)
        roundScores.append(score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adaptDifficulty()
    }

    private func adaptDifficulty() {
        guard roundScores.count >= 2 else { return }
        let avg = movingAverage

        // Thresholds tuned per grid size
        // Easy (4x4): avg < 200 => bump up, avg > 600 => bump down
        // Medium (5x5): avg < 400 => bump up, avg > 1200 => bump down
        // Hard (6x6): top tier
        switch difficulty {
        case .easy:
            if avg < 200 { difficulty = .medium }
        case .medium:
            if avg < 400 { difficulty = .hard }
            else if avg > 1200 { difficulty = .easy }
        case .hard:
            if avg > 1800 { difficulty = .medium }
        }
    }

    // MARK: - Restart

    private var restartButton: some View {
        Button(action: startNewGame) {
            Label("New Puzzle", systemImage: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.7), Color.cyan.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private func startNewGame() {
        showWin = false
        game = LightsOutGameState()
        elapsedTime = 0
        startTimer()
    }

    // MARK: - Win Overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { } // absorb taps

            VStack(spacing: 24) {
                Text("You Win!")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 12)

                VStack(spacing: 8) {
                    winStat(label: "Moves", value: "\(game.moves)")
                    winStat(label: "Time", value: timeString(elapsedTime))
                    winStat(label: "Score", value: "\(currentScore)")
                    if roundScores.count >= 2 {
                        winStat(label: "Avg Score (last \(roundScores.count))", value: String(format: "%.0f", movingAverage))
                    }
                }

                // Next difficulty hint
                nextDifficultyHint

                Button(action: startNewGame) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showWin)
    }

    private func winStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 15, design: .rounded))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
    }

    @ViewBuilder
    private var nextDifficultyHint: some View {
        if roundScores.count >= 2 {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(difficulty.badgeColor)
                Text("Next: \(difficulty.label) (\(difficulty.gridSize)×\(difficulty.gridSize))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(difficulty.badgeColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(difficulty.badgeColor.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helpers

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Preview

struct LightsOutViewV2_Previews: PreviewProvider {
    static var previews: some View {
        LightsOutViewV2()
            .preferredColorScheme(.dark)
    }
}
