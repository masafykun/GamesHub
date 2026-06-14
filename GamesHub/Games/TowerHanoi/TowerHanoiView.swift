import SwiftUI

// MARK: - TowerHanoiView (V1 - Clean Minimal)

struct TowerHanoiView: View {
    @StateObject private var vm = TowerHanoiViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if vm.showStartScreen {
                TowerHanoiStartScreen(diskCount: $vm.diskCount) {
                    vm.startGame()
                }
            } else {
                TowerHanoiGameView(vm: vm)
            }
        }
    }
}

// MARK: - Start Screen

private struct TowerHanoiStartScreen: View {
    @Binding var diskCount: Int
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("Tower of Hanoi")
                .font(.largeTitle.bold())

            Text("Move all disks from peg A to peg C.\nYou can only place a smaller disk on a larger one.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Number of Disks")
                    .font(.headline)
                Picker("Disks", selection: $diskCount) {
                    ForEach([3, 4, 5], id: \.self) { n in
                        Text("\(n) disks").tag(n)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text("Minimum moves: \(Int(pow(2.0, Double(diskCount))) - 1)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Button(action: onStart) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

// MARK: - Game View

private struct TowerHanoiGameView: View {
    @ObservedObject var vm: TowerHanoiViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Menu") { vm.showStartScreen = true }
                Spacer()
                Text("Moves: \(vm.moves)")
                    .font(.headline)
                Spacer()
                Button("Reset") { vm.resetGame() }
            }
            .padding()

            Spacer()

            // Solved banner
            if vm.solved {
                VStack(spacing: 8) {
                    Text("Solved!")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    let minMoves = Int(pow(2.0, Double(vm.diskCount))) - 1
                    if vm.moves == minMoves {
                        Text("Perfect! Minimum moves.")
                            .foregroundStyle(.orange)
                    } else {
                        Text("In \(vm.moves) moves (min \(minMoves))")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 16)
            }

            // Pegs
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<3, id: \.self) { pegIndex in
                    TowerHanoiPegView(
                        pegIndex: pegIndex,
                        disks: vm.pegs[pegIndex],
                        diskCount: vm.diskCount,
                        isSelected: vm.selectedPeg == pegIndex,
                        onTap: { vm.tapPeg(pegIndex) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)

            Spacer()

            // Bottom controls
            HStack(spacing: 16) {
                Button(action: { vm.autoSolve() }) {
                    Label("Auto Solve", systemImage: "wand.and.stars")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(vm.isSolving ? Color.orange : Color.indigo)
                        .clipShape(Capsule())
                }
                .disabled(vm.isSolving || vm.solved)

                if vm.isSolving {
                    Button(action: { vm.stopSolving() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Peg View

private struct TowerHanoiPegView: View {
    let pegIndex: Int
    let disks: [Int]
    let diskCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    private let pegLabels = ["A", "B", "C"]

    var body: some View {
        VStack(spacing: 4) {
            // Peg label
            Text(pegLabels[pegIndex])
                .font(.caption.bold())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            ZStack(alignment: .bottom) {
                // Peg shaft
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? Color.accentColor.opacity(0.8) : Color(.systemGray3))
                    .frame(width: 6, height: 160)
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.6) : .clear, radius: 8)

                // Disks
                VStack(spacing: 3) {
                    ForEach(Array(disks.reversed().enumerated()), id: \.offset) { _, disk in
                        TowerHanoiDiskView(size: disk, maxSize: diskCount)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: 175)

            // Base
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray2))
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                .padding(.horizontal, 4)
        )
    }
}

// MARK: - Disk View

private struct TowerHanoiDiskView: View {
    let size: Int
    let maxSize: Int

    private var color: Color {
        let t = Double(size - 1) / Double(maxSize - 1)
        return Color(hue: 0.65 * (1 - t), saturation: 0.85, brightness: 0.85)
    }

    private var width: CGFloat {
        let minW: CGFloat = 28
        let maxW: CGFloat = 90
        let t = Double(size - 1) / Double(maxSize - 1)
        return minW + CGFloat(t) * (maxW - minW)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color)
            .frame(width: width, height: 22)
            .overlay(
                Text("\(size)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.9))
            )
    }
}

// MARK: - ViewModel

class TowerHanoiViewModel: ObservableObject {
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
