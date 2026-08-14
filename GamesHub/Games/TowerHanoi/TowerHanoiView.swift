import SwiftUI

// MARK: - TowerHanoiView (Glassmorphism)

struct TowerHanoiView: View {
    @StateObject private var vm = TowerHanoiViewModel()

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.25),
                    Color(red: 0.08, green: 0.03, blue: 0.22),
                    Color(red: 0.12, green: 0.06, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -160)

            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 200)

            if vm.showStartScreen {
                TowerHanoiStartScreen(diskCount: $vm.diskCount) {
                    vm.startGame()
                }
            } else {
                TowerHanoiGameView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: -  Start Screen

private struct TowerHanoiStartScreen: View {
    @Binding var diskCount: Int
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Tower of Hanoi")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .purple.opacity(0.8), radius: 20)

                Text("Ancient puzzle, timeless challenge")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Rules card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .purple.opacity(0.3), radius: 20)

                VStack(alignment: .leading, spacing: 10) {
                    TowerHanoiRuleRow(icon: "1.circle.fill", text: "Move all disks to peg C")
                    TowerHanoiRuleRow(icon: "2.circle.fill", text: "Move only the top disk")
                    TowerHanoiRuleRow(icon: "3.circle.fill", text: "No disk on a smaller one")
                }
                .padding(20)
            }
            .padding(.horizontal)

            // Disk picker card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .blue.opacity(0.3), radius: 20)

                VStack(spacing: 14) {
                    Text("Choose Difficulty")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        ForEach([3, 4, 5], id: \.self) { n in
                            Button(action: { diskCount = n }) {
                                VStack(spacing: 4) {
                                    Text("\(n)")
                                        .font(.title2.bold())
                                    Text("disks")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    diskCount == n
                                    ? Color.purple.opacity(0.5)
                                    : Color.white.opacity(0.05)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(diskCount == n ? Color.purple : Color.white.opacity(0.1), lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                                .shadow(color: diskCount == n ? .purple.opacity(0.5) : .clear, radius: 10)
                            }
                        }
                    }

                    Text("Min moves: \(Int(pow(2.0, Double(diskCount))) - 1)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(20)
            }
            .padding(.horizontal)

            Button(action: onStart) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .purple.opacity(0.5), radius: 20)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

private struct TowerHanoiRuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .font(.subheadline)
            Text(text)
                .foregroundStyle(.white.opacity(0.85))
                .font(.subheadline)
        }
    }
}

// MARK: -  Game View

private struct TowerHanoiGameView: View {
    @ObservedObject var vm: TowerHanoiViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header glass card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .purple.opacity(0.25), radius: 15)

                HStack {
                    Button(action: { vm.showStartScreen = true }) {
                        Image(systemName: "house.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("MOVES")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(2)
                        Text("\(vm.moves)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .shadow(color: .blue.opacity(0.8), radius: 8)
                    }

                    Spacer()

                    Button(action: { vm.resetGame() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            // Solved banner
            if vm.solved {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .green.opacity(0.5), radius: 20)

                    VStack(spacing: 4) {
                        Text("Puzzle Solved!")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .shadow(color: .green.opacity(0.9), radius: 12)
                        let minMoves = Int(pow(2.0, Double(vm.diskCount))) - 1
                        Text(vm.moves == minMoves ? "Perfect score!" : "\(vm.moves) moves (min \(minMoves))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }

            // Pegs area
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .blue.opacity(0.2), radius: 20)

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
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .padding(.horizontal)

            Spacer()

            // Controls
            HStack(spacing: 12) {
                Button(action: { vm.autoSolve() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                        Text(vm.isSolving ? "Solving..." : "Auto Solve")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.4), radius: 12)
                }
                .disabled(vm.isSolving || vm.solved)

                if vm.isSolving {
                    Button(action: { vm.stopSolving() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .red.opacity(0.4), radius: 12)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
}

// MARK: -  Peg View

private struct TowerHanoiPegView: View {
    let pegIndex: Int
    let disks: [Int]
    let diskCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    private let pegLabels = ["A", "B", "C"]
    private let glowColor = Color.purple

    var body: some View {
        VStack(spacing: 6) {
            Text(pegLabels[pegIndex])
                .font(.caption.bold())
                .foregroundStyle(isSelected ? glowColor : .white.opacity(0.5))
                .shadow(color: isSelected ? glowColor.opacity(0.9) : .clear, radius: 8)

            ZStack(alignment: .bottom) {
                // Glow behind peg when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(glowColor.opacity(0.25))
                        .frame(width: 50, height: 170)
                        .blur(radius: 10)
                }

                // Peg shaft
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        isSelected
                        ? LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 5, height: 155)
                    .shadow(color: isSelected ? glowColor.opacity(0.8) : .clear, radius: 8)

                // Disks
                VStack(spacing: 3) {
                    ForEach(Array(disks.reversed().enumerated()), id: \.offset) { _, disk in
                        TowerHanoiDiskView(size: disk, maxSize: diskCount)
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: 172)

            // Base
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.3))
                .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: -  Disk View

private struct TowerHanoiDiskView: View {
    let size: Int
    let maxSize: Int

    private var gradient: LinearGradient {
        let t = Double(size - 1) / Double(maxSize - 1)
        let start = Color(hue: 0.75 - 0.55 * t, saturation: 0.9, brightness: 1.0)
        let end = Color(hue: 0.75 - 0.55 * t, saturation: 0.7, brightness: 0.7)
        return LinearGradient(colors: [start, end], startPoint: .top, endPoint: .bottom)
    }

    private var glowColor: Color {
        let t = Double(size - 1) / Double(maxSize - 1)
        return Color(hue: 0.75 - 0.55 * t, saturation: 0.9, brightness: 1.0)
    }

    private var width: CGFloat {
        let minW: CGFloat = 26
        let maxW: CGFloat = 88
        let t = Double(size - 1) / Double(maxSize - 1)
        return minW + CGFloat(t) * (maxW - minW)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(gradient)
                .shadow(color: glowColor.opacity(0.5), radius: 6)

            // Glass overlay
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: width, height: 22)
        .overlay(
            Text("\(size)")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.9))
        )
    }
}

// MARK: -  ViewModel

private class TowerHanoiViewModel: ObservableObject {
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
