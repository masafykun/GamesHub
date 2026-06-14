import SwiftUI

// MARK: - Models

enum ShMtShape: CaseIterable {
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

struct ShMtShapeView: View {
    let shape: ShMtShape
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            switch shape {
            case .circle:
                Circle().fill(color).frame(width: size, height: size)
            case .square:
                Rectangle().fill(color).frame(width: size, height: size)
            case .triangle:
                ShMtTrianglePath()
                    .fill(color)
                    .frame(width: size, height: size)
            case .pentagon:
                ShMtPolygonPath(sides: 5)
                    .fill(color)
                    .frame(width: size, height: size)
            case .star:
                ShMtStarPath()
                    .fill(color)
                    .frame(width: size, height: size)
            case .hexagon:
                ShMtPolygonPath(sides: 6)
                    .fill(color)
                    .frame(width: size, height: size)
            case .cross:
                ShMtCrossPath()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
    }
}

struct ShMtTrianglePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ShMtPolygonPath: Shape {
    let sides: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r,
                             y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct ShMtStarPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.4
        let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<10 {
            let angle = (Double(i) / 10.0) * 2 * .pi - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r,
                             y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct ShMtCrossPath: Shape {
    func path(in rect: CGRect) -> Path {
        let t = rect.width * 0.3
        var p = Path()
        p.addRect(CGRect(x: rect.midX - t/2, y: rect.minY, width: t, height: rect.height))
        p.addRect(CGRect(x: rect.minX, y: rect.midY - t/2, width: rect.width, height: t))
        return p
    }
}

// MARK: - Game State

enum ShMtGamePhase { case start, playing, result }

struct ShMtRound {
    let target: ShMtShape
    let options: [ShMtShape]
    let correctIndex: Int
}

// MARK: - Main View

struct ShadowMatchView: View {
    @State private var phase: ShMtGamePhase = .start
    @State private var round = 0
    @State private var score = 0
    @State private var rounds: [ShMtRound] = []
    @State private var selectedIndex: Int? = nil
    @State private var timeLeft: Double = 5.0
    @State private var timer: Timer? = nil
    @State private var feedback: Bool? = nil

    let totalRounds = 10
    let roundTime: Double = 5.0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Shadow Match")
                .font(.largeTitle).bold()
            Text("Tap the matching shadow\nfor the shape on the left.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Round \(round)/\(totalRounds)")
                    .font(.headline)
                Spacer()
                Text("Score: \(score)")
                    .font(.headline)
            }
            .padding(.horizontal)

            ProgressView(value: timeLeft, total: roundTime)
                .tint(timeLeft < 2 ? .red : .blue)
                .padding(.horizontal)

            if round > 0 && round <= rounds.count {
                let r = rounds[round - 1]
                HStack(spacing: 20) {
                    VStack {
                        Text("Shape").font(.caption).foregroundColor(.secondary)
                        ShMtShapeView(shape: r.target, size: 80, color: .blue)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    VStack(spacing: 12) {
                        Text("Match it!").font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                let isCorrect = i == r.correctIndex
                                let wasSelected = selectedIndex == i
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(wasSelected ? (isCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3)) : Color(.secondarySystemBackground))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(wasSelected ? (isCorrect ? Color.green : Color.red) : Color.clear, lineWidth: 2))
                                    ShMtShapeView(shape: r.options[i], size: 44, color: .black)
                                        .padding(8)
                                }
                                .frame(height: 70)
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
        VStack(spacing: 24) {
            Text("Game Over!").font(.largeTitle).bold()
            Text("Score: \(score) / \(totalRounds * 100)")
                .font(.title2)
            Text(score >= 700 ? "Excellent!" : score >= 400 ? "Good job!" : "Keep practicing!")
                .foregroundColor(.secondary)
            Button("Play Again") { startGame() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    func buildRounds() -> [ShMtRound] {
        var result: [ShMtRound] = []
        let shapes = ShMtShape.allCases
        for _ in 0..<totalRounds {
            let target = shapes.randomElement()!
            var pool = shapes.filter { $0 != target }.shuffled()
            let wrong = Array(pool.prefix(3))
            let correctIndex = Int.random(in: 0..<4)
            var options = wrong
            options.insert(target, at: correctIndex)
            result.append(ShMtRound(target: target, options: options, correctIndex: correctIndex))
        }
        return result
    }

    func startGame() {
        rounds = buildRounds()
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
        feedback = nil
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
            let bonus = Int(timeLeft / roundTime * 50)
            score += 50 + bonus
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            nextRound()
        }
    }
}

#Preview { ShadowMatchView() }
