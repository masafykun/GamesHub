import SwiftUI

// MARK: - Models

enum WhackDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }
}

struct WhackMole: Identifiable {
    let id: Int
    var isActive: Bool = false
    var showHit: Bool = false
    var showMiss: Bool = false
}

// MARK: - Main View

struct WhackView: View {
    @State private var moles: [WhackMole] = (0..<9).map { WhackMole(id: $0) }

    @State private var score: Int = 0
    @State private var timeRemaining: Int = 30
    @State private var combo: Int = 0
    @State private var roundScores: [Int] = []

    @State private var moleVisibleDuration: Double = 1.2
    @State private var difficulty: WhackDifficulty = .easy

    @State private var gameTimer: Timer? = nil
    @State private var moleTimer: Timer? = nil
    @State private var activeMoleTimers: [Int: Timer] = [:]

    @State private var isPlaying: Bool = false
    @State private var isGameOver: Bool = false

    @AppStorage("whackBestScore") private var bestScore: Int = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    private let roundLength = 30

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.12, green: 0.06, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            backgroundDecor

            VStack(spacing: 18) {
                headerView
                difficultyBadge

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(moles) { mole in
                        moleHole(mole)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)

            if isGameOver {
                gameOverOverlay
            } else if !isPlaying {
                startOverlay
            }
        }
        .onDisappear { stopEverything() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private func moleHole(_ mole: WhackMole) -> some View {
        Button { handleTap(index: mole.id) } label: {
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.25, green: 0.15, blue: 0.05))
                    .frame(height: 55)
                    .padding(.top, 28)

                if mole.isActive {
                    WhackMoleCharacter()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if mole.showHit {
                    Text("+10")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.6), radius: 3)
                        .transition(.scale.combined(with: .opacity))
                }

                if mole.showMiss {
                    Text("-5")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
            .frame(width: 90, height: 90)
            .clipped()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(mole.showMiss ? Color.red.opacity(0.7) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundDecor: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
                .blur(radius: 60)
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 250, height: 250)
                .offset(x: 120, y: 200)
                .blur(radius: 50)
        }
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            WhackStatCard(label: "Score", value: "\(score)", icon: "star.fill", color: .yellow)
            Spacer()
            VStack(spacing: 2) {
                Text("Whack-a-Mole")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(combo >= 3 ? "COMBO ×\(combo)" : "Best \(bestScore)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(combo >= 3 ? .orange : .white.opacity(0.5))
            }
            Spacer()
            WhackStatCard(
                label: "Time",
                value: "\(timeRemaining)s",
                icon: "clock.fill",
                color: timeRemaining <= 5 ? .red : .cyan
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    private var difficultyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text("(\(String(format: "%.1f", moleVisibleDuration))s)")
                .font(.system(size: 11))
                .opacity(0.8)
        }
        .foregroundColor(difficulty.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(difficulty.color.opacity(0.18))
                .overlay(Capsule().strokeBorder(difficulty.color.opacity(0.5), lineWidth: 1))
        )
    }

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 12)

                Text("Whack-a-Mole")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Tap moles before they hide!\n+10 hit · -5 miss · combos pay extra")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                yellowButton(title: "Start Game", action: startGame)
            }
            .padding(34)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(32)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Time's Up!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 4) {
                    Text("Final Score")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(score)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.4), radius: 10)
                    Text("Best: \(bestScore)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                if !roundScores.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                            Text("\(s)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text("Next difficulty:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 4) {
                        Image(systemName: difficulty.icon)
                        Text(difficulty.rawValue)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(difficulty.color)
                }

                yellowButton(title: "Play Again", action: startGame)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(32)
        }
    }

    private func yellowButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 42)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.yellow).shadow(color: .yellow.opacity(0.5), radius: 10))
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        score = 0
        combo = 0
        timeRemaining = roundLength
        isPlaying = true
        isGameOver = false
        moles = (0..<9).map { WhackMole(id: $0) }
        cancelAllMoleTimers()

        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                endGame()
            }
        }

        scheduleMolePop()
    }

    private func scheduleMolePop() {
        moleTimer?.invalidate()
        let popInterval = max(0.4, moleVisibleDuration * 0.7)
        moleTimer = Timer.scheduledTimer(withTimeInterval: popInterval, repeats: true) { _ in
            guard isPlaying else { return }
            popRandomMoles()
        }
    }

    private func popRandomMoles() {
        let inactiveIndices = moles.indices.filter { !moles[$0].isActive }
        guard !inactiveIndices.isEmpty else { return }

        let count = min(inactiveIndices.count, Int.random(in: 1...2))
        for idx in inactiveIndices.shuffled().prefix(count) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                moles[idx].isActive = true
            }

            activeMoleTimers[idx]?.invalidate()
            activeMoleTimers[idx] = Timer.scheduledTimer(withTimeInterval: moleVisibleDuration, repeats: false) { _ in
                if moles[idx].isActive {
                    withAnimation(.easeIn(duration: 0.2)) {
                        moles[idx].isActive = false
                    }
                    // Letting one escape breaks the combo.
                    combo = 0
                    activeMoleTimers.removeValue(forKey: idx)
                }
            }
        }
    }

    private func handleTap(index: Int) {
        guard isPlaying else { return }

        if moles[index].isActive {
            combo += 1
            // Every third consecutive hit adds a bonus on top of the base 10.
            score += 10 + (combo >= 3 ? min(10, (combo - 2) * 2) : 0)
            activeMoleTimers[index]?.invalidate()
            activeMoleTimers.removeValue(forKey: index)

            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                moles[index].showHit = true
                moles[index].isActive = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { moles[index].showHit = false }
            }
        } else {
            combo = 0
            score = max(0, score - 5)
            withAnimation { moles[index].showMiss = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { moles[index].showMiss = false }
            }
        }
    }

    private func endGame() {
        isPlaying = false
        isGameOver = true
        stopEverything()

        for i in moles.indices { moles[i].isActive = false }

        bestScore = max(bestScore, score)
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores.removeFirst(roundScores.count - 5)
        }
        adjustDifficulty()
    }

    private func stopEverything() {
        gameTimer?.invalidate(); gameTimer = nil
        moleTimer?.invalidate(); moleTimer = nil
        cancelAllMoleTimers()
    }

    /// Moles stay up for less time the better the recent rounds went.
    private func adjustDifficulty() {
        let avg = roundScores.isEmpty ? 0 : roundScores.reduce(0, +) / roundScores.count

        if avg >= 220 {
            moleVisibleDuration = max(0.5, moleVisibleDuration - 0.1)
        } else if avg >= 140 {
            moleVisibleDuration = max(0.7, moleVisibleDuration - 0.05)
        } else if avg < 60 {
            moleVisibleDuration = min(1.4, moleVisibleDuration + 0.1)
        }

        if moleVisibleDuration <= 0.7 {
            difficulty = .hard
        } else if moleVisibleDuration <= 1.0 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }
    }

    private func cancelAllMoleTimers() {
        for t in activeMoleTimers.values { t.invalidate() }
        activeMoleTimers.removeAll()
    }
}

// MARK: - Mole Character

struct WhackMoleCharacter: View {
    @State private var wiggle: Bool = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.35, blue: 0.20), Color(red: 0.40, green: 0.25, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 36)
                .offset(y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.65, green: 0.45, blue: 0.28), Color(red: 0.50, green: 0.32, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .offset(y: -6)

            HStack(spacing: 8) {
                Circle().fill(Color.black).frame(width: 7, height: 7)
                Circle().fill(Color.black).frame(width: 7, height: 7)
            }
            .offset(y: -10)

            HStack(spacing: 8) {
                Circle().fill(Color.white.opacity(0.7)).frame(width: 2.5, height: 2.5)
                Circle().fill(Color.white.opacity(0.7)).frame(width: 2.5, height: 2.5)
            }
            .offset(x: -1, y: -12)

            Ellipse()
                .fill(Color(red: 0.85, green: 0.5, blue: 0.5))
                .frame(width: 10, height: 7)
                .offset(y: -4)

            HStack(spacing: 6) {
                Rectangle().fill(Color.black.opacity(0.3)).frame(width: 10, height: 1).rotationEffect(.degrees(-15))
                Rectangle().fill(Color.black.opacity(0.3)).frame(width: 10, height: 1).rotationEffect(.degrees(15))
            }
            .offset(y: -1)

            Ellipse()
                .fill(Color.yellow)
                .frame(width: 34, height: 12)
                .offset(y: -22)

            Ellipse()
                .fill(Color(red: 0.9, green: 0.75, blue: 0.0))
                .frame(width: 42, height: 8)
                .offset(y: -18)
        }
        .rotationEffect(.degrees(wiggle ? 6 : -6))
        .animation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true), value: wiggle)
        .onAppear { wiggle = true }
        .onDisappear { wiggle = false }
    }
}

// MARK: - Stat Card

struct WhackStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
        }
        .frame(minWidth: 70)
    }
}

#Preview {
    WhackView()
}
