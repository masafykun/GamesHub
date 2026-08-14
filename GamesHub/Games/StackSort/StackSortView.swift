import SwiftUI

// MARK: - Models
enum StackSortDiscColor: CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return Color(red: 1.0, green: 0.25, blue: 0.25)
        case .blue: return Color(red: 0.2, green: 0.5, blue: 1.0)
        case .green: return Color(red: 0.15, green: 0.85, blue: 0.4)
        }
    }
}

enum StackSortGamePhase {
    case start, playing, won
}

struct StackSortStack {
    var discs: [StackSortDiscColor] = []
    let capacity: Int = 5
    var isFull: Bool { discs.count >= capacity }
    var isEmpty: Bool { discs.isEmpty }
    var topDisc: StackSortDiscColor? { discs.last }
    var isSorted: Bool {
        guard !discs.isEmpty else { return true }
        return Set(discs).count == 1
    }
}

// MARK: - Main View
struct StackSortView: View {
    @State private var stacks: [StackSortStack] = []
    @State private var selectedStack: Int? = nil
    @State private var phase: StackSortGamePhase = .start
    @State private var moves: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.4, green: 0.1, blue: 0.8), Color(red: 0.1, green: 0.3, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch phase {
            case .start:
                StackSortStartScreen(difficulty: difficulty) { startGame() }
            case .playing:
                StackSortPlayingScreen(
                    stacks: $stacks,
                    selectedStack: $selectedStack,
                    moves: moves,
                    difficulty: difficulty,
                    onTap: handleTap,
                    onReset: startGame
                )
            case .won:
                StackSortWonScreen(moves: moves, difficulty: difficulty, onRestart: {
                    recordResult(true)
                    startGame()
                })
            }
        }
    }

    private func startGame() {
        var allDiscs: [StackSortDiscColor] = StackSortDiscColor.allCases.flatMap { Array(repeating: $0, count: 5) }
        allDiscs.shuffle()
        stacks = (0..<5).map { i in
            var s = StackSortStack()
            if i < 3 {
                s.discs = Array(allDiscs[(i * 5)..<(i * 5 + 5)])
            }
            return s
        }
        selectedStack = nil
        moves = 0
        phase = .playing
    }

    private func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 3.0)
        }
    }

    private func handleTap(index: Int) {
        guard phase == .playing else { return }
        if let sel = selectedStack {
            if sel == index { selectedStack = nil; return }
            guard let disc = stacks[sel].topDisc else { selectedStack = nil; return }
            let dst = stacks[index]
            let canPlace = !dst.isFull && (dst.isEmpty || dst.topDisc == disc)
            if canPlace {
                stacks[index].discs.append(disc)
                stacks[sel].discs.removeLast()
                moves += 1
                selectedStack = nil
                if stacks.filter({ !$0.isEmpty }).allSatisfy({ $0.isSorted }) &&
                    stacks.filter({ !$0.isEmpty }).count == 3 {
                    phase = .won
                }
            } else {
                selectedStack = index
            }
        } else {
            if !stacks[index].isEmpty { selectedStack = index }
        }
    }
}

// MARK: - Sub-Views
private struct StackSortStartScreen: View {
    let difficulty: Double
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Text("Stack Sort").font(.largeTitle).bold().foregroundColor(.white)
            if difficulty > 1.0 {
                Text("Difficulty: \(String(format: "%.1fx", difficulty))")
                    .font(.caption).foregroundColor(.white.opacity(0.7))
            }
            Text("Sort the colored discs\nso each stack has one color!")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
            Button("Start Game") { onStart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }
}

private struct StackSortWonScreen: View {
    let moves: Int
    let difficulty: Double
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle).bold().foregroundColor(.white)
            Text("Completed in \(moves) moves")
                .font(.title3).foregroundColor(.white.opacity(0.8))
            if difficulty > 1.1 {
                Text("Difficulty boosted to \(String(format: "%.1fx", difficulty))!")
                    .font(.caption).foregroundColor(.yellow.opacity(0.9))
            }
            Button("Play Again") { onRestart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }
}

private struct StackSortPlayingScreen: View {
    @Binding var stacks: [StackSortStack]
    @Binding var selectedStack: Int?
    let moves: Int
    let difficulty: Double
    let onTap: (Int) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moves: \(moves)").font(.headline).foregroundColor(.white)
                    if difficulty > 1.1 {
                        Text("\(String(format: "%.1fx", difficulty)) difficulty")
                            .font(.caption2).foregroundColor(.yellow.opacity(0.8))
                    }
                }
                Spacer()
                Button("Reset") { onReset() }
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            HStack(spacing: 10) {
                ForEach(0..<stacks.count, id: \.self) { i in
                    StackSortStackView(stack: stacks[i], isSelected: selectedStack == i)
                        .onTapGesture { onTap(i) }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)
        }
    }
}

private struct StackSortStackView: View {
    let stack: StackSortStack
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Spacer()
            ForEach(0..<5, id: \.self) { row in
                let idx = 4 - row
                Group {
                    if idx < stack.discs.count {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(stack.discs[idx].color)
                            .frame(width: 44, height: 26)
                            .shadow(color: stack.discs[idx].color.opacity(0.5), radius: 4, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.07))
                            .frame(width: 44, height: 26)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 60, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? .white.opacity(0.2) : .white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? .white.opacity(0.8) : .white.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview { StackSortView() }
