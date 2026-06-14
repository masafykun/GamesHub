import SwiftUI

// MARK: - LCG Seeded RNG
struct CStLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models (V3)
enum CStV3Color: CaseIterable {
    case red, blue, green, yellow
    var color: Color {
        switch self {
        case .red:    return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .blue:   return Color(red: 0.25, green: 0.45, blue: 0.85)
        case .green:  return Color(red: 0.2,  green: 0.7,  blue: 0.4)
        case .yellow: return Color(red: 0.9,  green: 0.75, blue: 0.1)
        }
    }
    var label: String {
        switch self {
        case .red: return "R"
        case .blue: return "B"
        case .green: return "G"
        case .yellow: return "Y"
        }
    }
}

struct CStV3Tube {
    var balls: [CStV3Color] = []
    let capacity = 4
    var isFull: Bool  { balls.count == capacity }
    var isEmpty: Bool { balls.isEmpty }
    var topBall: CStV3Color? { balls.last }
    var isSorted: Bool {
        balls.count == capacity && Set(balls.map { $0.label }).count == 1
    }
}

enum CStV3Phase { case start, playing, won }

// MARK: - V3 View (Neumorphism + Seeded RNG)
struct ColorSortViewV3: View {
    @State private var tubes: [CStV3Tube] = []
    @State private var selectedTube: Int? = nil
    @State private var phase: CStV3Phase = .start
    @State private var moves: Int = 0
    @State private var seedInt: Int = 1

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: v3StartScreen
            case .playing: v3PlayingScreen
            case .won: v3WonScreen
            }
        }
    }

    // MARK: Start Screen
    private var v3StartScreen: some View {
        VStack(spacing: 28) {
            Text("Color Sort")
                .font(.largeTitle).bold()
                .foregroundColor(Color(.label))
            Text("Sort colored balls into\nmatching tubes!")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
            Button("Start Game") { startGame() }
                .font(.headline)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .foregroundColor(.primary)
                .neumorphicCard(radius: 12)
        }
        .padding(36)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    // MARK: Won Screen
    private var v3WonScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!")
                .font(.largeTitle).bold()
                .foregroundColor(Color(.label))
            Text("Completed in \(moves) moves")
                .foregroundColor(Color(.secondaryLabel))
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
            Button("Play Again") { seedInt += 1; startGame() }
                .font(.headline)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .foregroundColor(.primary)
                .neumorphicCard(radius: 12)
        }
        .padding(36)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    // MARK: Playing Screen
    private var v3PlayingScreen: some View {
        VStack(spacing: 20) {
            // Header bar
            HStack {
                Text("Moves: \(moves)")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
                Button("Reset") { seedInt += 1; startGame() }
                    .font(.caption).foregroundColor(.red.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            // Tubes area
            HStack(spacing: 12) {
                ForEach(0..<tubes.count, id: \.self) { i in
                    CStV3TubeView(tube: tubes[i], isSelected: selectedTube == i)
                        .onTapGesture { handleTap(i) }
                }
            }
            .padding(20)
            .neumorphicCard(radius: 20)
            .padding(.horizontal)
        }
    }

    // MARK: Logic
    private func startGame() {
        var rng = CStLCG(seed: seedInt)
        var allBalls: [CStV3Color] = CStV3Color.allCases.flatMap { Array(repeating: $0, count: 4) }
        // Fisher-Yates shuffle using LCG
        for i in stride(from: allBalls.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            allBalls.swapAt(i, j)
        }
        tubes = (0..<5).map { i in
            var t = CStV3Tube()
            if i < 4 { t.balls = Array(allBalls[(i*4)..<(i*4+4)]) }
            return t
        }
        selectedTube = nil
        moves = 0
        phase = .playing
    }

    private func handleTap(_ index: Int) {
        if let sel = selectedTube {
            if sel == index { selectedTube = nil; return }
            guard let ball = tubes[sel].topBall else { selectedTube = nil; return }
            let dst = tubes[index]
            let canPlace = !dst.isFull && (dst.isEmpty || dst.topBall == ball)
            if canPlace {
                tubes[index].balls.append(ball)
                tubes[sel].balls.removeLast()
                moves += 1
                selectedTube = nil
                if tubes.filter({ !$0.isEmpty }).allSatisfy({ $0.isSorted }) { phase = .won }
            } else {
                selectedTube = index
            }
        } else {
            if !tubes[index].isEmpty { selectedTube = index }
        }
    }
}

// MARK: - Tube View V3
private struct CStV3TubeView: View {
    let tube: CStV3Tube
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<4, id: \.self) { row in
                let idx = 3 - row
                Group {
                    if idx < tube.balls.count {
                        Circle()
                            .fill(tube.balls[idx].color)
                            .frame(width: 34, height: 34)
                            .shadow(color: tube.balls[idx].color.opacity(0.35), radius: 3, x: 2, y: 2)
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 34, height: 34)
                            .shadow(color: .black.opacity(0.08), radius: 2, x: 1, y: 1)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(width: 52, height: 195)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.1), radius: isSelected ? 6 : 4, x: isSelected ? 3 : 2, y: isSelected ? 3 : 2)
        .shadow(color: .white.opacity(isSelected ? 0.9 : 0.8), radius: isSelected ? 6 : 4, x: isSelected ? -3 : -2, y: isSelected ? -3 : -2)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

#Preview { ColorSortViewV3() }
