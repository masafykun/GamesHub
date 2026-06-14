import SwiftUI

// MARK: - Neumorphic Helpers (V3 local, not using Extensions.swift to stay self-contained)

private struct FarkleV3NeuShadow: ViewModifier {
    var isInset: Bool = false
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if isInset {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 2)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                        .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
        } else {
            content
                .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
        }
    }
}

private extension View {
    func farkleV3NeuCard(isInset: Bool = false, cornerRadius: CGFloat = 16) -> some View {
        self.modifier(FarkleV3NeuShadow(isInset: isInset, cornerRadius: cornerRadius))
    }
}

// MARK: - Private Models (V3 scoped)

private enum FarkleV3Phase {
    case rolling, selecting, banked
}

private struct FarkleV3Die: Identifiable {
    let id: Int
    var value: Int
    var isKept: Bool
    var isScoring: Bool
}

// MARK: - ViewModel (V3)

private class FarkleV3ViewModel: ObservableObject {
    @Published var dice: [FarkleV3Die] = []
    @Published var roundScore: Int = 0
    @Published var totalScore: Int = 0
    @Published var phase: FarkleV3Phase = .rolling
    @Published var message: String = "Tap Roll to start!"
    @Published var rollCount: Int = 0
    @Published var isAnimating: Bool = false
    @Published var gameWon: Bool = false
    @Published var showFarkle: Bool = false

    init() {
        resetDice()
    }

    func resetDice() {
        dice = (0..<6).map { FarkleV3Die(id: $0, value: Int.random(in: 1...6), isKept: false, isScoring: false) }
    }

    func roll() {
        guard !gameWon else { return }
        isAnimating = true
        phase = .rolling
        showFarkle = false

        let allKept = dice.filter { $0.isKept }.count == 6
        if allKept {
            for i in dice.indices {
                dice[i].isKept = false
                dice[i].isScoring = false
            }
        }

        for step in 0..<7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.065) {
                for i in self.dice.indices where !self.dice[i].isKept {
                    self.dice[i].value = Int.random(in: 1...6)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            for i in self.dice.indices where !self.dice[i].isKept {
                self.dice[i].value = Int.random(in: 1...6)
                self.dice[i].isScoring = false
            }
            self.rollCount += 1
            self.isAnimating = false

            let unKept = self.dice.filter { !$0.isKept }
            let scoringIdx = self.scoringDiceIndices(for: unKept.map { $0.value })

            if scoringIdx.isEmpty {
                self.showFarkle = true
                self.message = "FARKLE! \(self.roundScore > 0 ? "Lost \(self.roundScore) pts." : "")"
                self.roundScore = 0
                self.phase = .banked
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    self.showFarkle = false
                    self.endTurn()
                }
            } else {
                self.phase = .selecting
                self.markScoringDice(unKeptDice: unKept, scoringIndices: scoringIdx)
                self.message = "Select scoring dice, then Roll or Bank"
            }
        }
    }

    private func markScoringDice(unKeptDice: [FarkleV3Die], scoringIndices: Set<Int>) {
        var unKeptIndex = 0
        for i in dice.indices {
            if !dice[i].isKept {
                dice[i].isScoring = scoringIndices.contains(unKeptIndex)
                unKeptIndex += 1
            }
        }
    }

    func scoringDiceIndices(for values: [Int]) -> Set<Int> {
        var result = Set<Int>()
        var counts = [Int: [Int]]()
        for (i, v) in values.enumerated() {
            counts[v, default: []].append(i)
        }

        if values.count == 6 && values.sorted() == [1,2,3,4,5,6] { return Set(0..<6) }
        if values.count == 6 && counts.values.filter({ $0.count == 2 }).count == 3 { return Set(0..<6) }

        for (value, indices) in counts {
            if indices.count >= 3 {
                for idx in indices { result.insert(idx) }
            } else if value == 1 || value == 5 {
                for idx in indices { result.insert(idx) }
            }
        }
        return result
    }

    func calculateScore(values: [Int]) -> Int {
        if values.isEmpty { return 0 }
        var counts = [Int: Int]()
        for v in values { counts[v, default: 0] += 1 }

        if values.count == 6 && values.sorted() == [1,2,3,4,5,6] { return 1500 }
        if values.count == 6 && counts.values.filter({ $0 == 2 }).count == 3 { return 750 }

        var score = 0
        for (value, count) in counts {
            let base = value == 1 ? 1000 : value * 100
            switch count {
            case 1: score += value == 1 ? 100 : (value == 5 ? 50 : 0)
            case 2: score += value == 1 ? 200 : (value == 5 ? 100 : 0)
            case 3: score += base
            case 4: score += base * 2
            case 5: score += base * 3
            case 6: score += base * 4
            default: break
            }
        }
        return score
    }

    func toggleKeep(die: FarkleV3Die) {
        guard phase == .selecting, !isAnimating else { return }
        guard let idx = dice.firstIndex(where: { $0.id == die.id }) else { return }
        guard !dice[idx].isKept else { return }
        if dice[idx].isScoring {
            dice[idx].isKept.toggle()
            updateRoundScore()
        }
    }

    func updateRoundScore() {
        roundScore = calculateScore(values: dice.filter { $0.isKept }.map { $0.value })
    }

    func rollAgain() {
        guard phase == .selecting else { return }
        guard dice.filter({ $0.isKept }).count > 0 else {
            message = "Keep at least one scoring die!"
            return
        }
        for i in dice.indices where dice[i].isKept {
            dice[i].isScoring = false
        }
        roll()
    }

    func bank() {
        guard phase == .selecting else { return }
        guard dice.filter({ $0.isKept }).count > 0 else {
            message = "Select at least one die to keep!"
            return
        }
        totalScore += roundScore
        phase = .banked
        if totalScore >= 10000 {
            gameWon = true
            message = "YOU WIN! \(totalScore) pts!"
        } else {
            message = "Banked \(roundScore) pts. Total: \(totalScore)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.endTurn() }
        }
    }

    func endTurn() {
        roundScore = 0; rollCount = 0
        resetDice(); phase = .rolling
        if !gameWon { message = "New turn — tap Roll!" }
    }

    func newGame() {
        totalScore = 0; roundScore = 0; rollCount = 0
        gameWon = false; showFarkle = false
        resetDice(); phase = .rolling
        message = "Tap Roll to start!"
    }
}

// MARK: - Neumorphic Die View

private struct FarkleV3DieView: View {
    let die: FarkleV3Die
    let onTap: () -> Void

    private let bg = Color(.systemGray6)

    var dieAccent: Color {
        if die.isKept { return Color(hue: 0.35, saturation: 0.6, brightness: 0.55) }
        if die.isScoring { return Color(hue: 0.08, saturation: 0.7, brightness: 0.7) }
        return Color(.systemGray2)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(bg)
                    .farkleV3NeuCard(isInset: die.isKept, cornerRadius: 18)

                Image(systemName: "die.face.\(die.value).fill")
                    .font(.system(size: 44))
                    .foregroundColor(dieAccent)
            }
            .frame(width: 90, height: 90)
            .scaleEffect(die.isKept ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: die.isKept)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Neumorphic Button

private struct FarkleV3NeuButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    private let bg = Color(.systemGray6)

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.headline.bold())
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .farkleV3NeuCard(isInset: isPressed, cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - Score Tile

private struct FarkleV3ScoreTile: View {
    let label: String
    let value: Int
    let color: Color
    private let bg = Color(.systemGray6)

    var body: some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.bold())
                .foregroundColor(Color(.systemGray))
                .tracking(1.5)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
                .animation(.spring(), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .farkleV3NeuCard(isInset: false, cornerRadius: 16)
    }
}

// MARK: - Main View V3

struct FarkleViewV3: View {
    @StateObject private var vm = FarkleV3ViewModel()

    private let bg = Color(.systemGray6)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Title area
                    VStack(spacing: 4) {
                        Text("FARKLE")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Color(.label))
                        Text("First to 10,000 wins")
                            .font(.subheadline)
                            .foregroundColor(Color(.systemGray))
                    }
                    .padding(.top, 8)

                    // Score tiles
                    HStack(spacing: 12) {
                        FarkleV3ScoreTile(label: "Round", value: vm.roundScore,
                                          color: Color(hue: 0.08, saturation: 0.7, brightness: 0.65))
                        FarkleV3ScoreTile(label: "Total", value: vm.totalScore,
                                          color: Color(hue: 0.62, saturation: 0.55, brightness: 0.6))
                        FarkleV3ScoreTile(label: "Goal", value: 10000,
                                          color: Color(hue: 0.35, saturation: 0.55, brightness: 0.5))
                    }
                    .padding(.horizontal)

                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress to 10,000")
                                .font(.caption.bold())
                                .foregroundColor(Color(.systemGray))
                            Spacer()
                            Text("\(Int(min(Double(vm.totalScore) / 100.0, 100)))%")
                                .font(.caption.bold())
                                .foregroundColor(Color(hue: 0.62, saturation: 0.55, brightness: 0.6))
                        }
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                                .farkleV3NeuCard(isInset: true, cornerRadius: 6)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hue: 0.62, saturation: 0.45, brightness: 0.65))
                                    .frame(width: geo.size.width * CGFloat(min(vm.totalScore, 10000)) / 10000.0)
                                    .animation(.spring(), value: vm.totalScore)
                            }
                            .frame(height: 12)
                        }
                    }
                    .padding()
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .farkleV3NeuCard(cornerRadius: 18)
                    .padding(.horizontal)

                    // Message banner
                    HStack(spacing: 10) {
                        Image(systemName: vm.showFarkle ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundColor(vm.showFarkle ? .red : Color(.systemGray))
                            .font(.subheadline)
                        Text(vm.message)
                            .font(.subheadline)
                            .foregroundColor(vm.showFarkle ? .red : Color(.label).opacity(0.75))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Text("#\(vm.rollCount)")
                            .font(.caption)
                            .foregroundColor(Color(.systemGray2))
                    }
                    .padding()
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .farkleV3NeuCard(isInset: vm.showFarkle, cornerRadius: 14)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.25), value: vm.showFarkle)

                    // Dice area
                    VStack(spacing: 14) {
                        Text("TAP SCORING DICE TO KEEP")
                            .font(.caption2.bold())
                            .foregroundColor(Color(.systemGray2))
                            .tracking(2)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                            spacing: 14
                        ) {
                            ForEach(vm.dice) { die in
                                FarkleV3DieView(die: die) { vm.toggleKeep(die: die) }
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: vm.dice.map { $0.value })

                        // Legend
                        HStack(spacing: 20) {
                            legendDot(color: Color(hue: 0.35, saturation: 0.6, brightness: 0.55), label: "Kept (inset)")
                            legendDot(color: Color(hue: 0.08, saturation: 0.7, brightness: 0.7), label: "Scoring")
                            legendDot(color: Color(.systemGray2), label: "Dead")
                        }
                    }
                    .padding()
                    .background(bg)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .farkleV3NeuCard(cornerRadius: 22)
                    .padding(.horizontal)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal)

                    // New game button
                    FarkleV3NeuButton(
                        label: "New Game",
                        icon: "arrow.counterclockwise",
                        color: Color(.systemRed).opacity(0.8),
                        action: { vm.newGame() }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }

            // Win overlay
            if vm.gameWon {
                v3WinOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(Color(.systemGray))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if vm.phase == .rolling {
            FarkleV3NeuButton(
                label: "Roll Dice",
                icon: "dice",
                color: Color(hue: 0.62, saturation: 0.55, brightness: 0.55),
                action: { vm.roll() }
            )
        } else if vm.phase == .selecting {
            HStack(spacing: 14) {
                FarkleV3NeuButton(
                    label: "Roll Again",
                    icon: "arrow.clockwise",
                    color: Color(hue: 0.08, saturation: 0.7, brightness: 0.65),
                    action: { vm.rollAgain() }
                )
                FarkleV3NeuButton(
                    label: "Bank",
                    icon: "banknote",
                    color: Color(hue: 0.35, saturation: 0.6, brightness: 0.5),
                    action: { vm.bank() }
                )
            }
        } else {
            HStack {
                ProgressView()
                    .tint(Color(.systemGray))
                Text("Next turn incoming...")
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .farkleV3NeuCard(isInset: true, cornerRadius: 14)
        }
    }

    private var v3WinOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.92).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 80))
                Text("YOU WIN!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color(hue: 0.35, saturation: 0.6, brightness: 0.45))
                Text("Final Score: \(vm.totalScore)")
                    .font(.title2.bold())
                    .foregroundColor(Color(.label))
                FarkleV3NeuButton(
                    label: "Play Again",
                    icon: "play.fill",
                    color: Color(hue: 0.35, saturation: 0.6, brightness: 0.5),
                    action: { vm.newGame() }
                )
            }
            .padding(40)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .farkleV3NeuCard(cornerRadius: 28)
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeIn, value: vm.gameWon)
    }
}
