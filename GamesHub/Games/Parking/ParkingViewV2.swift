import SwiftUI

// MARK: - Models (V2 prefixed to avoid conflict)

struct PkV2Car: Identifiable {
    let id: Int
    var col: Int
    var row: Int
    let length: Int
    let isHorizontal: Bool
    let isTarget: Bool
}

struct PkV2Puzzle {
    let cars: [PkV2Car]
}

private let pkV2Puzzles: [PkV2Puzzle] = [
    PkV2Puzzle(cars: [
        PkV2Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV2Car(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 2, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV2Car(id: 3, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 4, col: 0, row: 4, length: 3, isHorizontal: true, isTarget: false),
    ]),
    PkV2Puzzle(cars: [
        PkV2Car(id: 0, col: 1, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV2Car(id: 1, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV2Car(id: 2, col: 0, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 3, col: 4, row: 1, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 4, col: 1, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 5, col: 5, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkV2Puzzle(cars: [
        PkV2Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV2Car(id: 1, col: 2, row: 1, length: 3, isHorizontal: false, isTarget: false),
        PkV2Car(id: 2, col: 3, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 3, col: 4, row: 2, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 4, col: 0, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 5, col: 3, row: 4, length: 2, isHorizontal: true, isTarget: false),
    ]),
    PkV2Puzzle(cars: [
        PkV2Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV2Car(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 2, col: 3, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 3, col: 4, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 4, col: 0, row: 3, length: 3, isHorizontal: true, isTarget: false),
        PkV2Car(id: 5, col: 4, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkV2Puzzle(cars: [
        PkV2Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV2Car(id: 1, col: 2, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV2Car(id: 2, col: 3, row: 1, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 3, col: 5, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV2Car(id: 4, col: 0, row: 4, length: 2, isHorizontal: false, isTarget: false),
        PkV2Car(id: 5, col: 2, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV2Car(id: 6, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
    ]),
]

enum PkV2Phase { case start, playing, won }

// MARK: - Main View V2

struct ParkingViewV2: View {
    @State private var phase: PkV2Phase = .start
    @State private var puzzleIndex = 0
    @State private var cars: [PkV2Car] = []
    @State private var moves = 0
    @State private var dragCarID: Int? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    let gridSize = 6
    var cellSize: CGFloat { CGFloat(52 * (difficultyMultiplier > 1.4 ? 0.9 : 1.0)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.4), Color(red: 0.3, green: 0.1, blue: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: wonScreen
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("PARKING")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("Slide cars to free the red car!")
                .foregroundColor(.white.opacity(0.7))
            glassButton("PLAY") { startGame() }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var wonScreen: some View {
        VStack(spacing: 20) {
            Text("SOLVED!")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.green)
            Text("Moves: \(moves)")
                .foregroundColor(.white)
                .font(.title2)
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0f", (difficultyMultiplier - 1) * 100))% harder")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            HStack(spacing: 16) {
                glassButton("Next") {
                    recordResult(won: true)
                    puzzleIndex = (puzzleIndex + 1) % pkV2Puzzles.count
                    startGame()
                }
                glassButton("Retry") {
                    recordResult(won: false)
                    startGame()
                }
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Puzzle \(puzzleIndex + 1)/\(pkV2Puzzles.count)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                    Text("Moves: \(moves)")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                Spacer()
                if difficultyMultiplier > 1.0 {
                    Text("LVL \(String(format: "%.1f", difficultyMultiplier))x")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.orange.opacity(0.5), lineWidth: 1))
                }
            }
            .padding(.horizontal)

            gridView
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

            glassButton("Reset") { startGame() }
        }
    }

    // MARK: Grid

    var gridView: some View {
        let total = CGFloat(gridSize) * cellSize
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .frame(width: total + 16, height: total + 16)

            Rectangle()
                .fill(Color.green.opacity(0.7))
                .frame(width: 6, height: cellSize)
                .offset(x: total / 2 + 10, y: -cellSize * 0.5)

            ForEach(cars) { car in carView(car: car) }
        }
        .frame(width: total + 16, height: total + 16)
    }

    func carView(car: PkV2Car) -> some View {
        let w = car.isHorizontal ? CGFloat(car.length) * cellSize - 4 : cellSize - 4
        let h = car.isHorizontal ? cellSize - 4 : CGFloat(car.length) * cellSize - 4
        let baseX = CGFloat(car.col) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let baseY = CGFloat(car.row) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let extraCols = car.isHorizontal ? CGFloat(car.length - 1) / 2 * cellSize : 0
        let extraRows = car.isHorizontal ? 0 : CGFloat(car.length - 1) / 2 * cellSize
        let dx = dragCarID == car.id && car.isHorizontal ? dragOffset : 0
        let dy = dragCarID == car.id && !car.isHorizontal ? dragOffset : 0
        let carColor: Color = car.isTarget ? .red : Color(hue: Double(car.id) * 0.13 + 0.5, saturation: 0.8, brightness: 0.9)

        return RoundedRectangle(cornerRadius: 8)
            .fill(carColor.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.35), lineWidth: 1))
            .frame(width: w, height: h)
            .offset(x: baseX + extraCols + dx, y: baseY + extraRows + dy)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { val in
                    if dragCarID == nil { dragCarID = car.id }
                    guard dragCarID == car.id else { return }
                    dragOffset = constrainDrag(car: car, raw: car.isHorizontal ? val.translation.width : val.translation.height)
                }
                .onEnded { _ in
                    guard dragCarID == car.id else { return }
                    commitDrag(carID: car.id, offset: dragOffset)
                    dragCarID = nil
                    dragOffset = 0
                }
            )
    }

    // MARK: Helpers

    @ViewBuilder
    func glassButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .frame(height: 46)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    func constrainDrag(car: PkV2Car, raw: CGFloat) -> CGFloat {
        let steps = raw / cellSize
        if car.isHorizontal {
            return max(-CGFloat(car.col), min(CGFloat(gridSize - car.col - car.length), steps)) * cellSize
        } else {
            return max(-CGFloat(car.row), min(CGFloat(gridSize - car.row - car.length), steps)) * cellSize
        }
    }

    func commitDrag(carID: Int, offset: CGFloat) {
        guard let idx = cars.firstIndex(where: { $0.id == carID }) else { return }
        let steps = Int((offset / cellSize).rounded())
        guard steps != 0 else { return }
        var newCar = cars[idx]
        if newCar.isHorizontal { newCar.col += steps } else { newCar.row += steps }
        if canPlace(car: newCar, excluding: carID) {
            cars[idx] = newCar
            moves += 1
            checkWin()
        }
    }

    func canPlace(car: PkV2Car, excluding id: Int) -> Bool {
        var occ = Set<String>()
        for c in cars where c.id != id {
            for i in 0..<c.length {
                occ.insert("\(c.isHorizontal ? c.col + i : c.col),\(c.isHorizontal ? c.row : c.row + i)")
            }
        }
        for i in 0..<car.length {
            let col = car.isHorizontal ? car.col + i : car.col
            let row = car.isHorizontal ? car.row : car.row + i
            if col < 0 || col >= gridSize || row < 0 || row >= gridSize { return false }
            if occ.contains("\(col),\(row)") { return false }
        }
        return true
    }

    func checkWin() {
        if let target = cars.first(where: { $0.isTarget }), target.col + target.length >= gridSize, target.row == 2 {
            phase = .won
        }
    }

    func recordResult(won: Bool) {
        recentResults.append(won)
        if recentResults.count > 5 { recentResults.removeFirst() }
        let successes = recentResults.filter { $0 }.count
        if recentResults.count == 5 && successes > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.0)
        }
    }

    func startGame() {
        cars = pkV2Puzzles[puzzleIndex].cars
        moves = 0
        phase = .playing
    }
}

#Preview { ParkingViewV2() }
