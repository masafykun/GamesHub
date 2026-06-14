import SwiftUI

// MARK: - LCG Seeded RNG
struct StStLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models
enum StStV3DiscColor: CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .blue: return Color(red: 0.2, green: 0.45, blue: 0.9)
        case .green: return Color(red: 0.15, green: 0.7, blue: 0.3)
        }
    }
    var label: String {
        switch self {
        case .red: return "R"
        case .blue: return "B"
        case .green: return "G"
        }
    }
}

enum StStV3GamePhase {
    case start, playing, won
}

struct StStV3Stack {
    var discs: [StStV3DiscColor] = []
    let capacity: Int = 5
    var isFull: Bool { discs.count >= capacity }
    var isEmpty: Bool { discs.isEmpty }
    var topDisc: StStV3DiscColor? { discs.last }
    var isSorted: Bool {
        guard !discs.isEmpty else { return true }
        return Set(discs).count == 1
    }
}

// MARK: - Main View
struct StackSortViewV3: View {
    @State private var stacks: [StStV3Stack] = []
    @State private var selectedStack: Int? = nil
    @State private var phase: StStV3GamePhase = .start
    @State private var moves: Int = 0
    @State private var seedInt: Int = 1

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start:
                StStV3StartScreen(seedInt: seedInt) { startGame() }
            case .playing:
                StStV3PlayingScreen(
                    stacks: $stacks,
                    selectedStack: $selectedStack,
                    moves: moves,
                    seedInt: seedInt,
                    onTap: handleTap,
                    onReset: { seedInt += 1; startGame() }
                )
            case .won:
                StStV3WonScreen(moves: moves, seedInt: seedInt) {
                    seedInt += 1
                    startGame()
                }
            }
        }
    }

    private func startGame() {
        var rng = StStLCG(seed: seedInt)
        // Generate shuffled disc array using LCG Fisher-Yates
        var allDiscs: [StStV3DiscColor] = StStV3DiscColor.allCases.flatMap { Array(repeating: $0, count: 5) }
        for i in stride(from: allDiscs.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            allDiscs.swapAt(i, j)
        }
        stacks = (0..<5).map { i in
            var s = StStV3Stack()
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
private struct StStV3StartScreen: View {
    let seedInt: Int
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Text("Stack Sort")
                .font(.largeTitle).bold()
                .foregroundColor(Color(.label))
            Text("Sort the colored discs\nso each stack has one color.")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
            Button("Start Game") { onStart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .foregroundColor(Color(.label))
                .neumorphicCard(radius: 24)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }
}

private struct StStV3WonScreen: View {
    let moves: Int
    let seedInt: Int
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle).bold()
            Text("Completed in \(moves) moves")
                .font(.title3).foregroundColor(Color(.secondaryLabel))
            Button("Next Puzzle") { onRestart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .foregroundColor(Color(.label))
                .neumorphicCard(radius: 24)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }
}

private struct StStV3PlayingScreen: View {
    @Binding var stacks: [StStV3Stack]
    @Binding var selectedStack: Int?
    let moves: Int
    let seedInt: Int
    let onTap: (Int) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moves: \(moves)").font(.headline)
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                Spacer()
                Button("Reset") { onReset() }
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .foregroundColor(.red)
                    .neumorphicCard(radius: 12)
            }
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            HStack(spacing: 10) {
                ForEach(0..<stacks.count, id: \.self) { i in
                    StStV3StackView(stack: stacks[i], isSelected: selectedStack == i)
                        .onTapGesture { onTap(i) }
                }
            }
            .padding()
            .neumorphicCard(radius: 20)
            .padding(.horizontal)
        }
    }
}

private struct StStV3StackView: View {
    let stack: StStV3Stack
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Spacer()
            ForEach(0..<5, id: \.self) { row in
                let idx = 4 - row
                Group {
                    if idx < stack.discs.count {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(stack.discs[idx].color)
                                .frame(width: 44, height: 26)
                                .shadow(color: .black.opacity(0.18), radius: 3, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.7), radius: 3, x: -1, y: -1)
                            Text(stack.discs[idx].label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(.systemGray6))
                            .frame(width: 44, height: 26)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                            .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 60, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(isSelected ? 0.25 : 0.15), radius: isSelected ? 8 : 5, x: isSelected ? 4 : 3, y: isSelected ? 4 : 3)
                .shadow(color: .white.opacity(0.8), radius: isSelected ? 8 : 5, x: isSelected ? -4 : -3, y: isSelected ? -4 : -3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview { StackSortViewV3() }
