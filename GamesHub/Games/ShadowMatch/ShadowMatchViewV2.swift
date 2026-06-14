import SwiftUI

// MARK: - Models (V2)

enum ShMtV2Shape: CaseIterable {
    case triangle, circle, square, pentagon, star, hexagon, cross

    var name: String {
        switch self {
        case .triangle: return "Triangle"
        case .circle: return "Circle"
        case .square: return "Square"
        case .pentagon: return "Pentagon"
        case .star: return "Star"
        case .hexagon: return "Hexagon"
        case .cross: return "Cross"
        }
    }
}

struct ShMtV2ShapeView: View {
    let shape: ShMtV2Shape
    let size: CGFloat
    let color: Color

    var body: some View {
        switch shape {
        case .circle:
            Circle().fill(color).frame(width: size, height: size)
        case .square:
            Rectangle().fill(color).frame(width: size, height: size)
        case .triangle:
            ShMtV2TrianglePath().fill(color).frame(width: size, height: size)
        case .pentagon:
            ShMtV2PolygonPath(sides: 5).fill(color).frame(width: size, height: size)
        case .star:
            ShMtV2StarPath().fill(color).frame(width: size, height: size)
        case .hexagon:
            ShMtV2PolygonPath(sides: 6).fill(color).frame(width: size, height: size)
        case .cross:
            ShMtV2CrossPath().fill(color).frame(width: size, height: size)
        }
    }
}

struct ShMtV2TrianglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ShMtV2PolygonPath: Shape {
    let sides: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct ShMtV2StarPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.4
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<10 {
            let angle = (Double(i) / 10.0) * 2 * .pi - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct ShMtV2CrossPath: Shape {
    func path(in rect: CGRect) -> Path {
        let t = rect.width * 0.3
        var p = Path()
        p.addRect(CGRect(x: rect.midX - t/2, y: rect.minY, width: t, height: rect.height))
        p.addRect(CGRect(x: rect.minX, y: rect.midY - t/2, width: rect.width, height: t))
        return p
    }
}

// MARK: - Game State V2

enum ShMtV2Phase { case start, playing, result }

struct ShMtV2Round {
    let target: ShMtV2Shape
    let options: [ShMtV2Shape]
    let correctIndex: Int
}

// MARK: - Main View V2

struct ShadowMatchViewV2: View {
    @State private var phase: ShMtV2Phase = .start
    @State private var round = 0
    @State private var score = 0
    @State private var rounds: [ShMtV2Round] = []
    @State private var selectedIndex: Int? = nil
    @State private var timeLeft: Double = 5.0
    @State private var baseRoundTime: Double = 5.0
    @State private var timer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyLevel: Int = 1

    let totalRounds = 10

    var roundTime: Double { baseRoundTime }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.3, green: 0.1, blue: 0.6), Color(red: 0.05, green: 0.3, blue: 0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
    }

    var glassPanel: some ShapeStyle { .ultraThinMaterial }

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Shadow Match")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                Text("Match the shadow shape.\nSpeed earns bonus points!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Start Game") { startGame() }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Round \(round)/\(totalRounds)").font(.headline).foregroundColor(.white)
                    Text("Level \(difficultyLevel)").font(.caption).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text("Score: \(score)").font(.headline).foregroundColor(.white)
            }
            .padding(.horizontal)

            ProgressView(value: max(0, timeLeft), total: roundTime)
                .tint(timeLeft < 2 ? .red : .cyan)
                .padding(.horizontal)
                .background(.ultraThinMaterial.opacity(0.3))

            if round > 0 && round <= rounds.count {
                let r = rounds[round - 1]
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Shape").font(.caption).foregroundColor(.white.opacity(0.7))
                            ShMtV2ShapeView(shape: r.target, size: 70, color: .white)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                        }
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white.opacity(0.6))
                        VStack(spacing: 8) {
                            Text("Match it!").font(.caption).foregroundColor(.white.opacity(0.7))
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(0..<4, id: \.self) { i in
                                    let isCorrect = i == r.correctIndex
                                    let wasSelected = selectedIndex == i
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(wasSelected
                                                  ? (isCorrect ? Color.green.opacity(0.4) : Color.red.opacity(0.4))
                                                  : Color.clear)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(wasSelected
                                                            ? (isCorrect ? Color.green : Color.red)
                                                            : Color.white.opacity(0.3),
                                                            lineWidth: wasSelected ? 2 : 1)
                                            )
                                        ShMtV2ShapeView(shape: r.options[i], size: 40, color: .white)
                                            .padding(8)
                                    }
                                    .frame(height: 65)
                                    .onTapGesture {
                                        guard selectedIndex == nil else { return }
                                        handleTap(index: i, correct: isCorrect)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Spacer()
        }
        .padding(.top)
    }

    var resultScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Game Over!").font(.largeTitle).bold().foregroundColor(.white)
                Text("Score: \(score) / \(totalRounds * 100)").font(.title2).foregroundColor(.white.opacity(0.9))
                Text(score >= 700 ? "Excellent!" : score >= 400 ? "Good job!" : "Keep practicing!")
                    .foregroundColor(.white.opacity(0.7))
                if difficultyLevel > 1 {
                    Text("You reached difficulty level \(difficultyLevel)!")
                        .font(.caption).foregroundColor(.cyan)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Play Again") { startGame() }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .padding()
    }

    func buildRounds() -> [ShMtV2Round] {
        let shapes = ShMtV2Shape.allCases
        return (0..<totalRounds).map { _ in
            let target = shapes.randomElement()!
            let wrong = Array(shapes.filter { $0 != target }.shuffled().prefix(3))
            let correctIndex = Int.random(in: 0..<4)
            var options = wrong
            options.insert(target, at: correctIndex)
            return ShMtV2Round(target: target, options: options, correctIndex: correctIndex)
        }
    }

    func startGame() {
        rounds = buildRounds()
        round = 0
        score = 0
        recentResults = []
        difficultyLevel = 1
        baseRoundTime = 5.0
        phase = .playing
        nextRound()
    }

    func nextRound() {
        guard round < totalRounds else {
            phase = .result
            timer?.invalidate()
            return
        }
        round += 1
        selectedIndex = nil
        timeLeft = baseRoundTime
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            timeLeft -= 0.05
            if timeLeft <= 0 {
                t.invalidate()
                handleTap(index: -1, correct: false)
            }
        }
    }

    func handleTap(index: Int, correct: Bool) {
        timer?.invalidate()
        selectedIndex = index
        if correct {
            let bonus = Int(max(0, timeLeft) / baseRoundTime * 50)
            score += 50 + bonus
        }
        recentResults.append(correct)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            baseRoundTime = max(2.0, baseRoundTime * 0.8)
            difficultyLevel += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            nextRound()
        }
    }
}

#Preview { ShadowMatchViewV2() }
