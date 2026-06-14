import SwiftUI

// MARK: - Models (V2)
enum CStV2Color: CaseIterable {
    case red, blue, green, yellow
    var color: Color {
        switch self {
        case .red:    return Color(red: 0.95, green: 0.3,  blue: 0.3)
        case .blue:   return Color(red: 0.3,  green: 0.55, blue: 0.95)
        case .green:  return Color(red: 0.3,  green: 0.85, blue: 0.45)
        case .yellow: return Color(red: 1.0,  green: 0.85, blue: 0.2)
        }
    }
}

struct CStV2Tube {
    var balls: [CStV2Color] = []
    let capacity = 4
    var isFull: Bool  { balls.count == capacity }
    var isEmpty: Bool { balls.isEmpty }
    var topBall: CStV2Color? { balls.last }
    var isSorted: Bool {
        balls.count == capacity && Set(balls.map { "\($0)" }).count == 1
    }
}

enum CStV2Phase { case start, playing, won }

// MARK: - V2 View
struct ColorSortViewV2: View {
    @State private var tubes: [CStV2Tube] = []
    @State private var selectedTube: Int? = nil
    @State private var phase: CStV2Phase = .start
    @State private var moves: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0

    private let gradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.2, blue: 0.8), Color(red: 0.1, green: 0.5, blue: 0.9)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            switch phase {
            case .start: v2StartScreen
            case .playing: v2PlayingScreen
            case .won: v2WonScreen
            }
        }
    }

    // MARK: Start Screen
    private var v2StartScreen: some View {
        VStack(spacing: 28) {
            Text("Color Sort").font(.largeTitle).bold().foregroundColor(.white)
            Text("Sort the colored balls\ninto matching tubes!")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
            Button("Start Game") { startGame() }
                .font(.headline)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    // MARK: Won Screen
    private var v2WonScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle).bold().foregroundColor(.white)
            Text("Completed in \(moves) moves")
                .foregroundColor(.white.opacity(0.8))
            if difficulty > 1.0 {
                Text("Difficulty: \(String(format: "%.0f%%", difficulty * 100))")
                    .font(.caption).foregroundColor(.yellow.opacity(0.9))
            }
            Button("Play Again") { finishAndRestart() }
                .font(.headline)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    // MARK: Playing Screen
    private var v2PlayingScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Moves: \(moves)")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                if difficulty > 1.0 {
                    Text("Hard \(String(format: "%.0f%%", difficulty * 100))")
                        .font(.caption).foregroundColor(.yellow)
                }
                Spacer()
                Button("Reset") { startGame() }
                    .font(.caption).foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            HStack(spacing: 10) {
                ForEach(0..<tubes.count, id: \.self) { i in
                    CStV2TubeView(tube: tubes[i], isSelected: selectedTube == i)
                        .onTapGesture { handleTap(i) }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)
        }
    }

    // MARK: Logic
    private func startGame() {
        var allBalls: [CStV2Color] = CStV2Color.allCases.flatMap { Array(repeating: $0, count: 4) }
        allBalls.shuffle()
        let numEmpty = difficulty >= 1.4 ? 1 : 1
        let filledCount = 5 - numEmpty
        tubes = (0..<5).map { i in
            var t = CStV2Tube()
            if i < filledCount { t.balls = Array(allBalls[(i*4)..<(i*4+4)]) }
            return t
        }
        selectedTube = nil
        moves = 0
        phase = .playing
    }

    private func finishAndRestart() {
        let par = 12
        let won = moves <= Int(Double(par) * difficulty * 2)
        recentResults.append(won)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 3.0)
        }
        startGame()
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

// MARK: - Tube View V2
private struct CStV2TubeView: View {
    let tube: CStV2Tube
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                let idx = 3 - row
                Group {
                    if idx < tube.balls.count {
                        Circle()
                            .fill(tube.balls[idx].color)
                            .shadow(color: tube.balls[idx].color.opacity(0.5), radius: 4)
                            .frame(width: 34, height: 34)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 34, height: 34)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 50, height: 190)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(isSelected ? Color.yellow : .white.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

#Preview { ColorSortViewV2() }
