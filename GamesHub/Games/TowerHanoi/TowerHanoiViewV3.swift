import SwiftUI

// MARK: - TowerHanoiViewV3 (Neumorphism)

struct TowerHanoiViewV3: View {
    @StateObject private var vm = TowerHanoiV3ViewModel()

    private let bgColor = Color(.systemGray6)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if vm.showStartScreen {
                TowerHanoiV3StartScreen(diskCount: $vm.diskCount) {
                    vm.startGame()
                }
            } else {
                TowerHanoiV3GameView(vm: vm)
            }
        }
    }
}

// MARK: - Neumorphic Helpers

private extension View {
    func v3NeuCard(radius: CGFloat = 16) -> some View {
        self
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
            .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    func v3NeuInset(radius: CGFloat = 12) -> some View {
        self
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 3, x: 2, y: 2)
    }
}

// MARK: - V3 Start Screen

private struct TowerHanoiV3StartScreen: View {
    @Binding var diskCount: Int
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Title card
                VStack(spacing: 6) {
                    Text("Tower of Hanoi")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))
                    Text("The classic peg puzzle")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(24)
                .v3NeuCard(radius: 20)
                .padding(.horizontal)
                .padding(.top, 20)

                // Rules card
                VStack(alignment: .leading, spacing: 14) {
                    Text("How to Play")
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    TowerHanoiV3RuleRow(number: "1", text: "Move all disks from peg A to peg C")
                    TowerHanoiV3RuleRow(number: "2", text: "Only the top disk may be moved")
                    TowerHanoiV3RuleRow(number: "3", text: "A disk cannot sit on a smaller one")
                }
                .padding(20)
                .v3NeuCard(radius: 20)
                .padding(.horizontal)

                // Disk count picker
                VStack(spacing: 16) {
                    Text("Difficulty")
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    HStack(spacing: 14) {
                        ForEach([3, 4, 5], id: \.self) { n in
                            TowerHanoiV3DiskPickerButton(
                                count: n,
                                isSelected: diskCount == n,
                                onTap: { diskCount = n }
                            )
                        }
                    }

                    Text("Minimum moves: \(Int(pow(2.0, Double(diskCount))) - 1)")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(20)
                .v3NeuCard(radius: 20)
                .padding(.horizontal)

                // Start button
                TowerHanoiV3StartButton(action: onStart)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
    }
}

private struct TowerHanoiV3RuleRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }
}

private struct TowerHanoiV3DiskPickerButton: View {
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title2.bold())
                Text("disks")
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                    }
                }
            )
            .shadow(
                color: isSelected ? .black.opacity(0.22) : .black.opacity(0.15),
                radius: isSelected ? 4 : 6, x: isSelected ? 2 : 4, y: isSelected ? 2 : 4
            )
            .shadow(
                color: isSelected ? .black.opacity(0.05) : .white.opacity(0.7),
                radius: isSelected ? 4 : 6, x: isSelected ? -2 : -4, y: isSelected ? -2 : -4
            )
        }
    }
}

private struct TowerHanoiV3StartButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text("Start Game")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                )
        }
    }
}

// MARK: - V3 Game View

private struct TowerHanoiV3GameView: View {
    @ObservedObject var vm: TowerHanoiV3ViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button(action: { vm.showStartScreen = true }) {
                    Image(systemName: "house")
                        .font(.headline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(10)
                        .v3NeuCard(radius: 10)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("MOVES")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(.tertiaryLabel))
                        .kerning(1.5)
                    Text("\(vm.moves)")
                        .font(.title.bold())
                        .foregroundStyle(Color(.label))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .v3NeuCard(radius: 14)

                Spacer()

                Button(action: { vm.resetGame() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(10)
                        .v3NeuCard(radius: 10)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Solved banner
            if vm.solved {
                VStack(spacing: 4) {
                    Text("Puzzle Solved!")
                        .font(.title3.bold())
                        .foregroundStyle(Color(.label))
                    let minMoves = Int(pow(2.0, Double(vm.diskCount))) - 1
                    Text(vm.moves == minMoves ? "Perfect – minimum moves!" : "\(vm.moves) moves (min \(minMoves))")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(16)
                .v3NeuCard(radius: 16)
                .padding(.horizontal)
                .transition(.scale.combined(with: .opacity))
            }

            // Pegs board
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<3, id: \.self) { pegIndex in
                        TowerHanoiV3PegView(
                            pegIndex: pegIndex,
                            disks: vm.pegs[pegIndex],
                            diskCount: vm.diskCount,
                            isSelected: vm.selectedPeg == pegIndex,
                            onTap: { vm.tapPeg(pegIndex) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .v3NeuCard(radius: 20)
            .padding(.horizontal)

            Spacer()

            // Controls
            HStack(spacing: 14) {
                TowerHanoiV3ActionButton(
                    label: vm.isSolving ? "Solving..." : "Auto Solve",
                    icon: "wand.and.stars",
                    disabled: vm.isSolving || vm.solved,
                    action: { vm.autoSolve() }
                )

                if vm.isSolving {
                    TowerHanoiV3ActionButton(
                        label: "Stop",
                        icon: "stop.fill",
                        disabled: false,
                        action: { vm.stopSolving() }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
    }
}

private struct TowerHanoiV3ActionButton: View {
    let label: String
    let icon: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline.bold())
            .foregroundStyle(disabled ? Color(.tertiaryLabel) : Color(.secondaryLabel))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(disabled ? 0.08 : 0.15), radius: disabled ? 3 : 6, x: disabled ? 2 : 4, y: disabled ? 2 : 4)
            .shadow(color: .white.opacity(disabled ? 0.4 : 0.7), radius: disabled ? 3 : 6, x: disabled ? -2 : -4, y: disabled ? -2 : -4)
        }
        .disabled(disabled)
    }
}

// MARK: - V3 Peg View

private struct TowerHanoiV3PegView: View {
    let pegIndex: Int
    let disks: [Int]
    let diskCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    private let pegLabels = ["A", "B", "C"]

    var body: some View {
        VStack(spacing: 6) {
            // Label
            Text(pegLabels[pegIndex])
                .font(.caption.bold())
                .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))

            ZStack(alignment: .bottom) {
                // Peg shaft (inset when selected)
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: 7, height: 155)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(width: 7, height: 155)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                            .shadow(color: .white.opacity(0.6), radius: 4, x: -2, y: -2)
                    }
                }

                // Disks stack
                VStack(spacing: 3) {
                    ForEach(Array(disks.reversed().enumerated()), id: \.offset) { _, disk in
                        TowerHanoiV3DiskView(size: disk, maxSize: diskCount)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: 170)

            // Base
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 7)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 1, y: 2)
                .shadow(color: .white.opacity(0.6), radius: 3, x: -1, y: -1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - V3 Disk View

private struct TowerHanoiV3DiskView: View {
    let size: Int
    let maxSize: Int

    private var diskColor: Color {
        let t = Double(size - 1) / Double(maxSize - 1)
        return Color(hue: 0.6 * (1 - t), saturation: 0.6, brightness: 0.65)
    }

    private var width: CGFloat {
        let minW: CGFloat = 26
        let maxW: CGFloat = 88
        let t = Double(size - 1) / Double(maxSize - 1)
        return minW + CGFloat(t) * (maxW - minW)
    }

    var body: some View {
        ZStack {
            // Disk base with neumorphic effect
            RoundedRectangle(cornerRadius: 5)
                .fill(diskColor.opacity(0.25))
                .frame(width: width, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
                .shadow(color: .white.opacity(0.55), radius: 3, x: -2, y: -2)

            // Colored fill
            RoundedRectangle(cornerRadius: 5)
                .fill(diskColor)
                .frame(width: width - 4, height: 18)

            // Highlight
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: width - 4, height: 18)

            Text("\(size)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - V3 ViewModel

private class TowerHanoiV3ViewModel: ObservableObject {
    @Published var pegs: [[Int]] = [[], [], []]
    @Published var selectedPeg: Int? = nil
    @Published var moves: Int = 0
    @Published var diskCount: Int = 4
    @Published var solved: Bool = false
    @Published var showStartScreen: Bool = true
    @Published var isSolving: Bool = false

    private var solveQueue: [(from: Int, to: Int)] = []
    private var solveTimer: Timer?

    func startGame() {
        pegs = [(1...diskCount).reversed().map { $0 }, [], []]
        selectedPeg = nil
        moves = 0
        solved = false
        showStartScreen = false
        isSolving = false
        solveQueue = []
        solveTimer?.invalidate()
    }

    func resetGame() {
        stopSolving()
        pegs = [(1...diskCount).reversed().map { $0 }, [], []]
        selectedPeg = nil
        moves = 0
        solved = false
    }

    func tapPeg(_ index: Int) {
        guard !solved, !isSolving else { return }
        if let sel = selectedPeg {
            if sel == index {
                selectedPeg = nil
                return
            }
            moveDisk(from: sel, to: index)
            selectedPeg = nil
        } else {
            if !pegs[index].isEmpty {
                selectedPeg = index
            }
        }
    }

    private func moveDisk(from: Int, to: Int) {
        guard !pegs[from].isEmpty else { return }
        let disk = pegs[from].last!
        if let top = pegs[to].last, top < disk { return }
        pegs[from].removeLast()
        pegs[to].append(disk)
        moves += 1
        checkSolved()
    }

    private func checkSolved() {
        solved = pegs[2].count == diskCount
    }

    func autoSolve() {
        guard !solved, !isSolving else { return }
        resetGame()
        solveQueue = []
        buildSolve(n: diskCount, from: 0, to: 2, aux: 1)
        isSolving = true
        scheduleNextMove()
    }

    func stopSolving() {
        isSolving = false
        solveTimer?.invalidate()
        solveTimer = nil
        solveQueue = []
    }

    private func buildSolve(n: Int, from: Int, to: Int, aux: Int) {
        guard n > 0 else { return }
        buildSolve(n: n - 1, from: from, to: aux, aux: to)
        solveQueue.append((from: from, to: to))
        buildSolve(n: n - 1, from: aux, to: to, aux: from)
    }

    private func scheduleNextMove() {
        guard isSolving, !solveQueue.isEmpty else {
            isSolving = false
            return
        }
        solveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self, self.isSolving, !self.solveQueue.isEmpty else { return }
            let move = self.solveQueue.removeFirst()
            withAnimation(.easeInOut(duration: 0.2)) {
                self.moveDisk(from: move.from, to: move.to)
            }
            self.scheduleNextMove()
        }
    }
}
