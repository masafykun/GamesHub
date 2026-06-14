import SwiftUI

// MARK: - LCG Seeded Random

struct ShMtLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Shapes (V3)

enum ShMtV3Shape: CaseIterable {
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

struct ShMtV3ShapeView: View {
    let shape: ShMtV3Shape
    let size: CGFloat
    let color: Color

    var body: some View {
        switch shape {
        case .circle:
            Circle().fill(color).frame(width: size, height: size)
        case .square:
            Rectangle().fill(color).frame(width: size, height: size)
        case .triangle:
            ShMtV3TrianglePath().fill(color).frame(width: size, height: size)
        case .pentagon:
            ShMtV3PolygonPath(sides: 5).fill(color).frame(width: size, height: size)
        case .star:
            ShMtV3StarPath().fill(color).frame(width: size, height: size)
        case .hexagon:
            ShMtV3PolygonPath(sides: 6).fill(color).frame(width: size, height: size)
        case .cross:
            ShMtV3CrossPath().fill(color).frame(width: size, height: size)
        }
    }
}

struct ShMtV3TrianglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ShMtV3PolygonPath: Shape {
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

struct ShMtV3StarPath: Shape {
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

struct ShMtV3CrossPath: Shape {
    func path(in rect: CGRect) -> Path {
        let t = rect.width * 0.3
        var p = Path()
        p.addRect(CGRect(x: rect.midX - t/2, y: rect.minY, width: t, height: rect.height))
        p.addRect(CGRect(x: rect.minX, y: rect.midY - t/2, width: rect.width, height: t))
        return p
    }
}

// MARK: - Game State V3

enum ShMtV3Phase { case start, playing, result }

struct ShMtV3Round {
    let target: ShMtV3Shape
    let options: [ShMtV3Shape]
    let correctIndex: Int
}

// MARK: - Main View V3 (Neumorphism + LCG)

struct ShadowMatchViewV3: View {
    @State private var phase: ShMtV3Phase = .start
    @State private var round = 0
    @State private var score = 0
    @State private var rounds: [ShMtV3Round] = []
    @State private var selectedIndex: Int? = nil
    @State private var timeLeft: Double = 5.0
    @State private var timer: Timer? = nil
    @State private var seedInt: Int = 1

    let totalRounds = 10
    let roundTime: Double = 5.0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Shadow Match")
                    .font(.largeTitle).bold()
                    .foregroundColor(Color(.label))
                Text("Match the shape shadow.\nFaster answers score more!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            Button("Start Game") { startGame() }
                .font(.headline)
                .foregroundColor(Color(.label))
                .padding(.horizontal, 40).padding(.vertical, 14)
                .neumorphicCard(radius: 24)
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Round \(round)/\(totalRounds)")
                        .font(.headline)
                        .foregroundColor(Color(.label))
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Color(.systemGray))
                }
                Spacer()
                Text("Score: \(score)")
                    .font(.headline)
                    .foregroundColor(Color(.label))
            }
            .padding(.horizontal)

            ProgressView(value: max(0, timeLeft), total: roundTime)
                .tint(timeLeft < 2 ? .red : Color(.systemIndigo))
                .padding(.horizontal)

            if round > 0 && round <= rounds.count {
                let r = rounds[round - 1]
                HStack(alignment: .center, spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Shape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ShMtV3ShapeView(shape: r.target, size: 68, color: Color(.label))
                            .padding(16)
                            .neumorphicCard(radius: 16)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("Find match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                let isCorrect = i == r.correctIndex
                                let wasSelected = selectedIndex == i
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(wasSelected
                                              ? (isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                              : Color(.systemGray6))
                                        .shadow(color: wasSelected
                                                ? (isCorrect ? Color.green.opacity(0.4) : Color.red.opacity(0.4))
                                                : Color.black.opacity(0.15),
                                                radius: wasSelected ? 4 : 6, x: 3, y: 3)
                                        .shadow(color: Color.white.opacity(wasSelected ? 0 : 0.7),
                                                radius: wasSelected ? 0 : 6, x: -3, y: -3)
                                    ShMtV3ShapeView(shape: r.options[i], size: 40, color: Color(.label))
                                        .padding(8)
                                }
                                .frame(height: 68)
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
            Spacer()
        }
        .padding(.top)
    }

    var resultScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("Game Over!")
                    .font(.largeTitle).bold()
                    .foregroundColor(Color(.label))
                Text("Score: \(score) / \(totalRounds * 100)")
                    .font(.title2)
                    .foregroundColor(Color(.label))
                Text(score >= 700 ? "Excellent!" : score >= 400 ? "Good job!" : "Keep practicing!")
                    .foregroundColor(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(.systemGray))
            }
            .padding(28)
            .neumorphicCard(radius: 20)

            Button("Play Again") { startGame() }
                .font(.headline)
                .foregroundColor(Color(.label))
                .padding(.horizontal, 40).padding(.vertical, 14)
                .neumorphicCard(radius: 24)
        }
        .padding()
    }

    func buildRounds(seed: Int) -> [ShMtV3Round] {
        var lcg = ShMtLCG(seed: seed)
        let allShapes = ShMtV3Shape.allCases
        return (0..<totalRounds).map { _ in
            let targetIdx = lcg.nextInt(allShapes.count)
            let target = allShapes[targetIdx]
            var pool = allShapes.filter { $0 != target }
            // Shuffle pool using LCG
            for i in stride(from: pool.count - 1, through: 1, by: -1) {
                let j = lcg.nextInt(i + 1)
                pool.swapAt(i, j)
            }
            let wrong = Array(pool.prefix(3))
            let correctIndex = lcg.nextInt(4)
            var options = wrong
            options.insert(target, at: correctIndex)
            return ShMtV3Round(target: target, options: options, correctIndex: correctIndex)
        }
    }

    func startGame() {
        seedInt += 1
        rounds = buildRounds(seed: seedInt)
        round = 0
        score = 0
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
        timeLeft = roundTime
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
            let bonus = Int(max(0, timeLeft) / roundTime * 50)
            score += 50 + bonus
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            nextRound()
        }
    }
}

#Preview { ShadowMatchViewV3() }
