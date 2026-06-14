import SwiftUI

// MARK: - Private Models

private enum FarklePhase {
    case rolling, selecting, banked
}

private struct FarkleDie: Identifiable {
    let id: Int
    var value: Int
    var isKept: Bool
    var isScoring: Bool
}

// MARK: - ViewModel

private class FarkleViewModel: ObservableObject {
    @Published var dice: [FarkleDie] = []
    @Published var roundScore: Int = 0
    @Published var totalScore: Int = 0
    @Published var phase: FarklePhase = .rolling
    @Published var message: String = "Tap Roll to start!"
    @Published var rollCount: Int = 0
    @Published var isAnimating: Bool = false
    @Published var gameWon: Bool = false

    init() {
        resetDice()
    }

    func resetDice() {
        dice = (0..<6).map { FarkleDie(id: $0, value: Int.random(in: 1...6), isKept: false, isScoring: false) }
    }

    func roll() {
        guard !gameWon else { return }
        isAnimating = true
        phase = .rolling

        // Re-roll non-kept dice
        let keptCount = dice.filter { $0.isKept }.count
        let allKept = keptCount == 6

        if allKept {
            // Hot dice: re-roll all
            for i in dice.indices {
                dice[i].isKept = false
                dice[i].isScoring = false
            }
        }

        // Animate roll
        for _ in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.05...0.3)) {
                for i in self.dice.indices where !self.dice[i].isKept {
                    self.dice[i].value = Int.random(in: 1...6)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Final roll values
            for i in self.dice.indices where !self.dice[i].isKept {
                self.dice[i].value = Int.random(in: 1...6)
                self.dice[i].isScoring = false
            }

            self.rollCount += 1
            self.isAnimating = false

            let unKeptDice = self.dice.filter { !$0.isKept }
            let scoringIndices = self.scoringDiceIndices(for: unKeptDice.map { $0.value })

            if scoringIndices.isEmpty {
                // FARKLE
                self.message = "FARKLE! No scoring dice!"
                self.roundScore = 0
                self.phase = .banked
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.endTurn()
                }
            } else {
                self.phase = .selecting
                // Mark scoring dice
                let scoringValues = self.markScoringDice(unKeptDice: unKeptDice, scoringIndices: scoringIndices)
                _ = scoringValues
                self.message = "Select dice to keep, then Roll or Bank"
            }
        }
    }

    private func markScoringDice(unKeptDice: [FarkleDie], scoringIndices: Set<Int>) -> [Int] {
        var unKeptIndex = 0
        for i in dice.indices {
            if !dice[i].isKept {
                if scoringIndices.contains(unKeptIndex) {
                    dice[i].isScoring = true
                } else {
                    dice[i].isScoring = false
                }
                unKeptIndex += 1
            }
        }
        return []
    }

    func scoringDiceIndices(for values: [Int]) -> Set<Int> {
        var result = Set<Int>()
        var counts = [Int: [Int]]()
        for (i, v) in values.enumerated() {
            counts[v, default: []].append(i)
        }

        // Check straight 1-6
        if values.count == 6 {
            let sorted = values.sorted()
            if sorted == [1,2,3,4,5,6] {
                return Set(0..<6)
            }
        }

        // Check three pairs
        if values.count == 6 {
            let countValues = counts.mapValues { $0.count }
            let pairs = countValues.values.filter { $0 >= 2 }
            if pairs.count == 3 || (countValues.values.filter { $0 == 2 }.count == 3) {
                return Set(0..<6)
            }
            // Also handle two sets of three as three pairs (not scoring as straight)
            let threeOfKinds = countValues.values.filter { $0 == 3 }
            if threeOfKinds.count == 2 {
                // Not three pairs exactly but score as triples
            }
        }

        // N of a kind
        for (value, indices) in counts {
            let count = indices.count
            if count >= 3 {
                for idx in indices { result.insert(idx) }
            } else if value == 1 || value == 5 {
                for idx in indices { result.insert(idx) }
            }
        }
        return result
    }

    func scoreForSelection() -> Int {
        let keptDice = dice.filter { $0.isKept }
        return calculateScore(values: keptDice.map { $0.value })
    }

    func calculateScore(values: [Int]) -> Int {
        if values.isEmpty { return 0 }

        var counts = [Int: Int]()
        for v in values { counts[v, default: 0] += 1 }

        // Straight 1-6
        if values.count == 6 {
            let sorted = values.sorted()
            if sorted == [1,2,3,4,5,6] { return 1500 }
        }

        // Three pairs
        if values.count == 6 {
            let pairCount = counts.values.filter { $0 == 2 }.count
            let tripleCount = counts.values.filter { $0 == 3 }.count
            if pairCount == 3 { return 750 }
            if tripleCount == 2 { return 750 } // Two triples treated as three pairs? Actually score individually
        }

        var score = 0
        for (value, count) in counts {
            let threeOfKindBase = value == 1 ? 1000 : value * 100
            switch count {
            case 1:
                if value == 1 { score += 100 }
                else if value == 5 { score += 50 }
            case 2:
                if value == 1 { score += 200 }
                else if value == 5 { score += 100 }
            case 3:
                score += threeOfKindBase
            case 4:
                score += threeOfKindBase * 2
            case 5:
                score += threeOfKindBase * 3
            case 6:
                score += threeOfKindBase * 4
            default:
                break
            }
        }
        return score
    }

    func toggleKeep(die: FarkleDie) {
        guard phase == .selecting, !isAnimating else { return }
        guard let idx = dice.firstIndex(where: { $0.id == die.id }) else { return }
        if dice[idx].isKept { return } // already kept from previous roll, can't unkeep

        // Can only keep scoring dice
        if dice[idx].isScoring {
            dice[idx].isKept.toggle()
            updateRoundScore()
        }
    }

    func updateRoundScore() {
        let keptValues = dice.filter { $0.isKept }.map { $0.value }
        roundScore = calculateScore(values: keptValues)
    }

    func canRollAgain() -> Bool {
        // Must have kept at least one scoring die from current roll
        let currentRollKept = dice.filter { $0.isKept && $0.isScoring }
        return !currentRollKept.isEmpty || dice.filter { $0.isKept }.count > 0 && dice.filter { !$0.isKept }.count > 0
    }

    func hasNewSelection() -> Bool {
        // At least one die is kept and scoring from this roll
        return dice.filter { $0.isKept && $0.isScoring }.count > 0 || dice.filter { $0.isKept }.count > 0
    }

    func bank() {
        guard phase == .selecting else { return }
        let keptCount = dice.filter { $0.isKept }.count
        guard keptCount > 0 else {
            message = "Keep at least one scoring die first!"
            return
        }
        totalScore += roundScore
        phase = .banked
        if totalScore >= 10000 {
            gameWon = true
            message = "YOU WIN! Final score: \(totalScore)"
        } else {
            message = "Banked \(roundScore) pts! Total: \(totalScore)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.gameWon {
                self.endTurn()
            }
        }
    }

    func endTurn() {
        roundScore = 0
        rollCount = 0
        resetDice()
        phase = .rolling
        if !gameWon {
            message = "New turn! Tap Roll."
        }
    }

    func newGame() {
        totalScore = 0
        roundScore = 0
        rollCount = 0
        gameWon = false
        resetDice()
        phase = .rolling
        message = "Tap Roll to start!"
    }

    func rollAgain() {
        guard phase == .selecting else { return }
        let keptCount = dice.filter { $0.isKept }.count
        guard keptCount > 0 else {
            message = "Keep at least one scoring die!"
            return
        }
        // Mark kept dice as permanently kept (not isScoring anymore for UI purposes)
        for i in dice.indices where dice[i].isKept {
            dice[i].isScoring = false
        }
        roll()
    }
}

// MARK: - Die View

private struct FarkleDieView: View {
    let die: FarkleDie
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "die.face.\(die.value).fill")
                .font(.system(size: 52))
                .foregroundColor(dieColor)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: die.isKept ? 2.5 : 1)
                )
                .scaleEffect(die.isKept ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: die.isKept)
        }
        .buttonStyle(.plain)
    }

    var dieColor: Color {
        if die.isKept { return .green }
        if die.isScoring { return .orange }
        return .primary
    }

    var backgroundColor: Color {
        if die.isKept { return Color.green.opacity(0.15) }
        if die.isScoring { return Color.orange.opacity(0.1) }
        return Color(.secondarySystemBackground)
    }

    var borderColor: Color {
        if die.isKept { return .green }
        if die.isScoring { return .orange }
        return Color(.separator)
    }
}

// MARK: - Main View

struct FarkleView: View {
    @StateObject private var vm = FarkleViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.vertical, 8)

                // Score info
                scoreInfoView
                    .padding(.horizontal)

                Divider().padding(.vertical, 8)

                // Message
                Text(vm.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(minHeight: 36)
                    .animation(.easeInOut, value: vm.message)

                Spacer(minLength: 12)

                // Dice grid
                diceGridView
                    .padding(.horizontal)

                Spacer(minLength: 12)

                // Legend
                legendView
                    .padding(.horizontal)

                Divider().padding(.vertical, 8)

                // Action buttons
                actionButtonsView
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }

            // Win overlay
            if vm.gameWon {
                winOverlay
            }
        }
        .navigationTitle("Farkle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FARKLE")
                    .font(.title2.bold())
                Text("First to 10,000 wins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("New Game") {
                vm.newGame()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
    }

    private var scoreInfoView: some View {
        HStack(spacing: 0) {
            scoreBox(label: "Round", value: vm.roundScore, color: .orange)
            Divider().frame(height: 40)
            scoreBox(label: "Total", value: vm.totalScore, color: .blue)
            Divider().frame(height: 40)
            scoreBox(label: "Target", value: 10000, color: .green)
        }
    }

    private func scoreBox(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var diceGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(vm.dice) { die in
                FarkleDieView(die: die) {
                    vm.toggleKeep(die: die)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.dice.map { $0.value })
    }

    private var legendView: some View {
        HStack(spacing: 16) {
            Label("Kept", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Label("Scoring", systemImage: "star.fill")
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
            Text("Roll #\(vm.rollCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            if vm.phase == .rolling {
                Button(action: { vm.roll() }) {
                    Label("Roll Dice", systemImage: "dice")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else if vm.phase == .selecting {
                Button(action: { vm.rollAgain() }) {
                    Label("Roll Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Button(action: { vm.bank() }) {
                    Label("Bank", systemImage: "banknote")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                // Banked phase - waiting
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 80))
                Text("YOU WIN!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.yellow)
                Text("Final Score: \(vm.totalScore)")
                    .font(.title2)
                    .foregroundColor(.white)
                Button("Play Again") {
                    vm.newGame()
                }
                .font(.headline)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(40)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
            .padding(24)
        }
    }
}
