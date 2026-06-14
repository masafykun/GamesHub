import SwiftUI

// MARK: - Models
enum CStColor: CaseIterable {
    case red, blue, green, yellow
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        }
    }
}

enum CStGamePhase {
    case start, playing, won
}

// MARK: - Game State
struct CStTube {
    var balls: [CStColor] = []
    var capacity: Int = 4
    var isFull: Bool { balls.count == capacity }
    var isEmpty: Bool { balls.isEmpty }
    var topBall: CStColor? { balls.last }
    var isSorted: Bool {
        guard balls.count == capacity else { return false }
        return Set(balls).count == 1
    }
}

// MARK: - Main View
struct ColorSortView: View {
    @State private var tubes: [CStTube] = []
    @State private var selectedTube: Int? = nil
    @State private var phase: CStGamePhase = .start
    @State private var moves: Int = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start:
                CStStartScreen { startGame() }
            case .playing:
                CStPlayingScreen(
                    tubes: $tubes,
                    selectedTube: $selectedTube,
                    moves: moves,
                    onTap: handleTap,
                    onReset: startGame
                )
            case .won:
                CStWonScreen(moves: moves, onRestart: startGame)
            }
        }
    }

    private func startGame() {
        var allBalls: [CStColor] = CStColor.allCases.flatMap { Array(repeating: $0, count: 4) }
        allBalls.shuffle()
        tubes = (0..<5).map { i in
            var t = CStTube()
            if i < 4 {
                t.balls = Array(allBalls[(i*4)..<(i*4+4)])
            }
            return t
        }
        selectedTube = nil
        moves = 0
        phase = .playing
    }

    private func handleTap(index: Int) {
        guard phase == .playing else { return }
        if let sel = selectedTube {
            if sel == index {
                selectedTube = nil
                return
            }
            let src = tubes[sel]
            let dst = tubes[index]
            guard let ball = src.topBall else { selectedTube = nil; return }
            let canPlace = !dst.isFull && (dst.isEmpty || dst.topBall == ball)
            if canPlace {
                tubes[index].balls.append(ball)
                tubes[sel].balls.removeLast()
                moves += 1
                selectedTube = nil
                if tubes.filter({ !$0.isEmpty }).allSatisfy({ $0.isSorted }) {
                    phase = .won
                }
            } else {
                selectedTube = index
            }
        } else {
            if !tubes[index].isEmpty {
                selectedTube = index
            }
        }
    }
}

// MARK: - Sub-Views
private struct CStStartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Color Sort").font(.largeTitle).bold()
            Text("Sort the colored balls\ninto matching tubes!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start Game") { onStart() }
                .font(.headline)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}

private struct CStWonScreen: View {
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
    }
}

private struct CStPlayingScreen: View {
    @Binding var tubes: [CStTube]
    @Binding var selectedTube: Int?
    let moves: Int
    let onTap: (Int) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Moves: \(moves)").font(.headline)
                Spacer()
                Button("Reset") { onReset() }.foregroundColor(.red)
            }.padding(.horizontal)

            HStack(spacing: 12) {
                ForEach(0..<tubes.count, id: \.self) { i in
                    CStTubeView(tube: tubes[i], isSelected: selectedTube == i)
                        .onTapGesture { onTap(i) }
                }
            }
            .padding()
        }
    }
}

private struct CStTubeView: View {
    let tube: CStTube
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            ForEach(0..<4, id: \.self) { row in
                let idx = 3 - row
                Group {
                    if idx < tube.balls.count {
                        Circle()
                            .fill(tube.balls[idx].color)
                            .frame(width: 36, height: 36)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 52, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
}

#Preview { ColorSortView() }
