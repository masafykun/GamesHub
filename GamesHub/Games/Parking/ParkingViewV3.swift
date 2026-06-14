import SwiftUI

// MARK: - LCG Random

struct PkLCG {
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

struct PkV3Car: Identifiable {
    let id: Int
    var col: Int
    var row: Int
    let length: Int
    let isHorizontal: Bool
    let isTarget: Bool
}

struct PkV3Puzzle {
    let cars: [PkV3Car]
}

// MARK: - Preset Puzzles

private let pkV3Puzzles: [PkV3Puzzle] = [
    PkV3Puzzle(cars: [
        PkV3Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV3Car(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 2, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV3Car(id: 3, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 4, col: 0, row: 4, length: 3, isHorizontal: true, isTarget: false),
    ]),
    PkV3Puzzle(cars: [
        PkV3Car(id: 0, col: 1, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV3Car(id: 1, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV3Car(id: 2, col: 0, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 3, col: 4, row: 1, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 4, col: 1, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 5, col: 5, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkV3Puzzle(cars: [
        PkV3Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV3Car(id: 1, col: 2, row: 1, length: 3, isHorizontal: false, isTarget: false),
        PkV3Car(id: 2, col: 3, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 3, col: 4, row: 2, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 4, col: 0, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 5, col: 3, row: 4, length: 2, isHorizontal: true, isTarget: false),
    ]),
    PkV3Puzzle(cars: [
        PkV3Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV3Car(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 2, col: 3, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 3, col: 4, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 4, col: 0, row: 3, length: 3, isHorizontal: true, isTarget: false),
        PkV3Car(id: 5, col: 4, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkV3Puzzle(cars: [
        PkV3Car(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkV3Car(id: 1, col: 2, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV3Car(id: 2, col: 3, row: 1, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 3, col: 5, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkV3Car(id: 4, col: 0, row: 4, length: 2, isHorizontal: false, isTarget: false),
        PkV3Car(id: 5, col: 2, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkV3Car(id: 6, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
    ]),
]

enum PkV3Phase { case start, playing, won }

// MARK: - Puzzle Generator

private func pkGeneratePuzzle(seed: Int) -> PkV3Puzzle {
    var rng = PkLCG(seed: seed)
    let baseIdx = rng.nextInt(pkV3Puzzles.count)
    var base = pkV3Puzzles[baseIdx].cars

    // Shuffle non-target cars slightly using LCG
    for i in 1..<base.count {
        let j = rng.nextInt(base.count - 1) + 1
        if i != j {
            base.swapAt(i, j)
        }
    }

    // Apply a random valid shift to some cars
    var result = base
    for i in 1..<result.count {
        let shift = rng.nextInt(3) - 1 // -1, 0, or 1
        var car = result[i]
        if car.isHorizontal {
            let newCol = car.col + shift
            if newCol >= 0 && newCol + car.length <= 6 { car.col = newCol }
        } else {
            let newRow = car.row + shift
            if newRow >= 0 && newRow + car.length <= 6 { car.row = newRow }
        }
        // Validate no overlap before applying
        var occ = Set<String>()
        for j in 0..<result.count where j != i {
            let c = result[j]
            for k in 0..<c.length {
                occ.insert("\(c.isHorizontal ? c.col + k : c.col),\(c.isHorizontal ? c.row : c.row + k)")
            }
        }
        var ok = true
        for k in 0..<car.length {
            let col = car.isHorizontal ? car.col + k : car.col
            let row = car.isHorizontal ? car.row : car.row + k
            if occ.contains("\(col),\(row)") { ok = false; break }
        }
        if ok { result[i] = car }
    }
    return PkV3Puzzle(cars: result)
}

// MARK: - Main View V3

struct ParkingViewV3: View {
    @State private var phase: PkV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var cars: [PkV3Car] = []
    @State private var moves = 0
    @State private var dragCarID: Int? = nil
    @State private var dragOffset: CGFloat = 0

    let gridSize = 6
    let cellSize: CGFloat = 52

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("PARKING")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundColor(.primary)
            Text("Slide cars to free the red car!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 48)
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
    }

    var wonScreen: some View {
        VStack(spacing: 20) {
            Text("SOLVED!")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(.green)
            Text("Moves: \(moves)")
                .font(.title2)
                .foregroundColor(.primary)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            HStack(spacing: 16) {
                Button("Next") {
                    seedInt += 1
                    startGame()
                }
                .buttonStyle(PkV3ButtonStyle())
                Button("Retry") { startGame() }
                    .buttonStyle(PkV3ButtonStyle())
            }
        }
        .padding(28)
        .neumorphicCard(radius: 20)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moves: \(moves)")
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Reset") { startGame() }
                    .foregroundColor(.orange)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal)

            gridView
                .padding(12)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)
        }
    }

    // MARK: Grid

    var gridView: some View {
        let total = CGFloat(gridSize) * cellSize
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: total + 12, height: total + 12)

            // Exit marker
            Rectangle()
                .fill(Color.green.opacity(0.7))
                .frame(width: 6, height: cellSize)
                .offset(x: total / 2 + 8, y: -cellSize * 0.5)

            ForEach(cars) { car in carView(car: car) }
        }
        .frame(width: total + 12, height: total + 12)
    }

    func carView(car: PkV3Car) -> some View {
        let w = car.isHorizontal ? CGFloat(car.length) * cellSize - 4 : cellSize - 4
        let h = car.isHorizontal ? cellSize - 4 : CGFloat(car.length) * cellSize - 4
        let baseX = CGFloat(car.col) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let baseY = CGFloat(car.row) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let extraCols = car.isHorizontal ? CGFloat(car.length - 1) / 2 * cellSize : 0
        let extraRows = car.isHorizontal ? 0 : CGFloat(car.length - 1) / 2 * cellSize
        let dx = dragCarID == car.id && car.isHorizontal ? dragOffset : 0
        let dy = dragCarID == car.id && !car.isHorizontal ? dragOffset : 0

        var rng = PkLCG(seed: car.id + 1)
        let hue = rng.nextDouble()
        let carColor: Color = car.isTarget ? .red : Color(hue: hue, saturation: 0.55, brightness: 0.75)

        return RoundedRectangle(cornerRadius: 8)
            .fill(carColor)
            .shadow(color: .black.opacity(0.18), radius: 3, x: 2, y: 2)
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

    func constrainDrag(car: PkV3Car, raw: CGFloat) -> CGFloat {
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

    func canPlace(car: PkV3Car, excluding id: Int) -> Bool {
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

    func startGame() {
        let puzzle = pkGeneratePuzzle(seed: seedInt)
        cars = puzzle.cars
        moves = 0
        phase = .playing
    }
}

struct PkV3ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 22)
            .frame(height: 44)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview { ParkingViewV3() }
