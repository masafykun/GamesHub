import SwiftUI

// MARK: - Models
enum StStDiscColor: CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return Color(red: 0.1, green: 0.75, blue: 0.2)
        }
    }
}

enum StStGamePhase {
    case start, playing, won
}

struct StStStack {
    var discs: [StStDiscColor] = []
    let capacity: Int = 5
    var isFull: Bool { discs.count >= capacity }
    var isEmpty: Bool { discs.isEmpty }
    var topDisc: StStDiscColor? { discs.last }
    var isSorted: Bool {
        guard !discs.isEmpty else { return true }
        return Set(discs).count == 1
    }
}

// MARK: - Main View
struct StackSortView: View {
    @State private var stacks: [StStStack] = []
    @State private var selectedStack: Int? = nil
    @State private var phase: StStGamePhase = .start
    @State private var moves: Int = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start:
                StStStartScreen { startGame() }
            case .playing:
                StStPlayingScreen(
                    stacks: $stacks,
                    selectedStack: $selectedStack,
                    moves: moves,
                    onTap: handleTap,
                    onReset: startGame
                )
            case .won:
                StStWonScreen(moves: moves, onRestart: startGame)
            }
        }
    }

    private func startGame() {
        var allDiscs: [StStDiscColor] = StStDiscColor.allCases.flatMap { Array(repeating: $0, count: 5) }
        allDiscs.shuffle()
        // 3 filled stacks of 5, 2 empty buffer stacks
        stacks = (0..<5).map { i in
            var s = StStStack()
            if i < 3 {
                s.discs = Array(allDiscs[(i * 5)..<(i * 5 + 5)])
            }
            return s
        }
        selectedStack = nil
        moves = 0
        phase = .playing
    }

    private func handleTap(index: Int) {
        guard phase == .playing else { return }
        if let sel = selectedStack {
            if sel == index {
                selectedStack = nil
                return
            }
            guard let disc = stacks[sel].topDisc else { selectedStack = nil; return }
            let dst = stacks[index]
            let canPlace = !dst.isFull && (dst.isEmpty || dst.topDisc == disc)
            if canPlace {
                stacks[index].discs.append(disc)
                stacks[sel].discs.removeLast()
                moves += 1
                selectedStack = nil
                let filledSorted = stacks.filter { !$0.isEmpty }.allSatisfy { $0.isSorted }
                if filledSorted && stacks.filter({ !$0.isEmpty }).count == 3 {
                    phase = .won
                }
            } else {
                selectedStack = index
            }
        } else {
            if !stacks[index].isEmpty {
                selectedStack = index
            }
        }
    }
}

// MARK: - Sub-Views
private struct StStStartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Stack Sort").font(.largeTitle).bold()
            Text("Sort the colored discs\nso each stack has one color!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start Game") { onStart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
        .padding()
    }
}

private struct StStWonScreen: View {
    let moves: Int
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle).bold()
            Text("Completed in \(moves) moves")
                .font(.title3).foregroundStyle(.secondary)
            Button("Play Again") { onRestart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
        .padding()
    }
}

private struct StStPlayingScreen: View {
    @Binding var stacks: [StStStack]
    @Binding var selectedStack: Int?
    let moves: Int
    let onTap: (Int) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Moves: \(moves)").font(.headline)
                Spacer()
                Button("Reset") { onReset() }.foregroundColor(.red)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                ForEach(0..<stacks.count, id: \.self) { i in
                    StStStackView(stack: stacks[i], isSelected: selectedStack == i)
                        .onTapGesture { onTap(i) }
                }
            }
            .padding()
        }
    }
}

private struct StStStackView: View {
    let stack: StStStack
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            ForEach(0..<5, id: \.self) { row in
                let idx = 4 - row
                Group {
                    if idx < stack.discs.count {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(stack.discs[idx].color)
                            .frame(width: 44, height: 24)
                            .shadow(radius: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 44, height: 24)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 60, height: 210)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview { StackSortView() }
