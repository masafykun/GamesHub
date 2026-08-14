import SwiftUI

// MARK: - Private Models ( scoped)

private enum FarklePhase {
    case rolling, selecting, banked
}

private struct FarkleDie: Identifiable {
    let id: Int
    var value: Int
    var isKept: Bool
    var isScoring: Bool
}

// MARK: - ViewModel ()

private class FarkleViewModel: ObservableObject {
    @Published var dice: [FarkleDie] = []
    @Published var roundScore: Int = 0
    @Published var totalScore: Int = 0
    @Published var phase: FarklePhase = .rolling
    @Published var message: String = "Tap Roll to start!"
    @Published var rollCount: Int = 0
    @Published var isAnimating: Bool = false
    @Published var gameWon: Bool = false
    @Published var farkleFlash: Bool = false

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

        let allKept = dice.filter { $0.isKept }.count == 6
        if allKept {
            for i in dice.indices {
                dice[i].isKept = false
                dice[i].isScoring = false
            }
        }

        // Animate tumbling
        let animSteps = 6
        for step in 0..<animSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.07) {
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.farkleFlash = true
                }
                self.message = "FARKLE! Lost \(self.roundScore) pts!"
                self.roundScore = 0
                self.phase = .banked
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { self.farkleFlash = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    self.endTurn()
                }
            } else {
                self.phase = .selecting
                self.markScoringDice(unKeptDice: unKept, scoringIndices: scoringIdx)
                self.message = "Select scoring dice, then Roll or Bank"
            }
        }
    }

    @discardableResult
    private func markScoringDice(unKeptDice: [FarkleDie], scoringIndices: Set<Int>) -> Bool {
        var unKeptIndex = 0
        for i in dice.indices {
            if !dice[i].isKept {
                dice[i].isScoring = scoringIndices.contains(unKeptIndex)
                unKeptIndex += 1
            }
        }
        return true
    }

    func scoringDiceIndices(for values: [Int]) -> Set<Int> {
        var result = Set<Int>()
        var counts = [Int: [Int]]()
        for (i, v) in values.enumerated() {
            counts[v, default: []].append(i)
        }

        // Straight
        if values.count == 6 && values.sorted() == [1,2,3,4,5,6] {
            return Set(0..<6)
        }

        // Three pairs
        if values.count == 6 {
            let pairCount = counts.values.filter { $0.count == 2 }.count
            if pairCount == 3 { return Set(0..<6) }
        }

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

    func toggleKeep(die: FarkleDie) {
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
            message = "Keep at least one die first!"
            return
        }
        totalScore += roundScore
        phase = .banked
        if totalScore >= 10000 {
            gameWon = true
            message = "VICTORY! \(totalScore) pts!"
        } else {
            message = "Banked \(roundScore)! Total: \(totalScore)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.endTurn() }
        }
    }

    func endTurn() {
        roundScore = 0
        rollCount = 0
        resetDice()
        phase = .rolling
        if !gameWon { message = "New turn — Roll!" }
    }

    func newGame() {
        totalScore = 0; roundScore = 0; rollCount = 0
        gameWon = false; farkleFlash = false
        resetDice(); phase = .rolling
        message = "Tap Roll to start!"
    }
}

// MARK: - Glassmorphic Die View

private struct FarkleDieView: View {
    let die: FarkleDie
    let onTap: () -> Void

    private var glowColor: Color {
        if die.isKept { return .green }
        if die.isScoring { return Color(hue: 0.13, saturation: 0.9, brightness: 1.0) }
        return .white
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [glowColor.opacity(0.8), glowColor.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: die.isKept ? 2 : 1
                            )
                    )
                    .shadow(color: glowColor.opacity(die.isKept ? 0.6 : (die.isScoring ? 0.4 : 0.1)), radius: die.isKept ? 14 : 6)

                Image(systemName: "die.face.\(die.value).fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        die.isKept
                        ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : (die.isScoring
                           ? LinearGradient(colors: [Color(hue: 0.1, saturation: 1, brightness: 1), .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                           : LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: glowColor.opacity(0.5), radius: 4)
            }
            .frame(width: 90, height: 90)
            .scaleEffect(die.isKept ? 1.06 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: die.isKept)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Card

private struct FarkleGlassCard<Content: View>: View {
    var accentColor: Color = .purple
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), accentColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accentColor.opacity(0.35), radius: 18, x: 0, y: 6)
    }
}

// MARK: - Main View 

struct FarkleView: View {
    @StateObject private var vm = FarkleViewModel()

    private let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.18),
            Color(red: 0.08, green: 0.04, blue: 0.22),
            Color(red: 0.12, green: 0.06, blue: 0.28),
            Color(red: 0.05, green: 0.08, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 200)

            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    FarkleGlassCard(accentColor: .purple) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FARKLE")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white, Color(hue: 0.75, saturation: 0.4, brightness: 1)], startPoint: .leading, endPoint: .trailing)
                                    )
                                Text("Race to 10,000 points")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Button("New Game") { vm.newGame() }
                                .font(.subheadline.bold())
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

                    // Score cards
                    HStack(spacing: 12) {
                        scoreCard(label: "Round", value: vm.roundScore, color: Color(hue: 0.1, saturation: 0.9, brightness: 1))
                        scoreCard(label: "Total", value: vm.totalScore, color: Color(hue: 0.6, saturation: 0.8, brightness: 1))
                        scoreCard(label: "Goal", value: 10000, color: Color(hue: 0.35, saturation: 0.8, brightness: 0.9))
                    }
                    .padding(.horizontal)

                    // Progress bar
                    FarkleGlassCard(accentColor: .cyan) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(min(vm.totalScore, 10000)) / 10000")
                                    .font(.caption.bold())
                                    .foregroundColor(.cyan)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.white.opacity(0.1))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(min(vm.totalScore, 10000)) / 10000.0)
                                        .animation(.spring(), value: vm.totalScore)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(.horizontal)

                    // Message
                    FarkleGlassCard(accentColor: vm.farkleFlash ? .red : .indigo) {
                        HStack {
                            Image(systemName: vm.farkleFlash ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundColor(vm.farkleFlash ? .red : .purple)
                            Text(vm.message)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("Roll #\(vm.rollCount)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: vm.farkleFlash)

                    // Dice grid
                    FarkleGlassCard(accentColor: .blue) {
                        VStack(spacing: 12) {
                            Text("TAP SCORING DICE TO KEEP")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(2)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                ForEach(vm.dice) { die in
                                    FarkleDieView(die: die) { vm.toggleKeep(die: die) }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: vm.dice.map { $0.value })

                            // Legend
                            HStack(spacing: 20) {
                                HStack(spacing: 4) {
                                    Circle().fill(.green).frame(width: 8, height: 8)
                                    Text("Kept").font(.caption2).foregroundColor(.white.opacity(0.5))
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hue: 0.1, saturation: 1, brightness: 1)).frame(width: 8, height: 8)
                                    Text("Scoring").font(.caption2).foregroundColor(.white.opacity(0.5))
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(.white.opacity(0.3)).frame(width: 8, height: 8)
                                    Text("Dead").font(.caption2).foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }

            // Win overlay
            if vm.gameWon {
                v2WinOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreCard(label: String, value: Int, color: Color) -> some View {
        FarkleGlassCard(accentColor: color) {
            VStack(spacing: 4) {
                Text(label.uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                Text("\(value)")
                    .font(.title2.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: color.opacity(0.5), radius: 6)
                    .animation(.spring(), value: value)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if vm.phase == .rolling {
            glowButton(label: "Roll Dice", icon: "dice", color: Color(hue: 0.65, saturation: 0.8, brightness: 0.9)) {
                vm.roll()
            }
        } else if vm.phase == .selecting {
            HStack(spacing: 12) {
                glowButton(label: "Roll Again", icon: "arrow.clockwise", color: Color(hue: 0.1, saturation: 0.9, brightness: 1.0)) {
                    vm.rollAgain()
                }
                glowButton(label: "Bank", icon: "banknote", color: Color(hue: 0.35, saturation: 0.8, brightness: 0.8)) {
                    vm.bank()
                }
            }
        } else {
            HStack {
                ProgressView()
                    .tint(.white)
                Text("Processing...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func glowButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.headline.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: color.opacity(0.5), radius: 14, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var v2WinOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .blur(radius: 0)

            VStack(spacing: 24) {
                Text("✨")
                    .font(.system(size: 72))
                Text("VICTORY!")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 20)
                Text("Final Score: \(vm.totalScore)")
                    .font(.title2.bold())
                    .foregroundColor(.white.opacity(0.9))
                Button("Play Again") { vm.newGame() }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.6), radius: 16)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .purple.opacity(0.4), radius: 30)
            .padding(24)
        }
        .transition(.opacity)
        .animation(.easeIn, value: vm.gameWon)
    }
}
