import SwiftUI

// MARK: - Models

struct PkCar: Identifiable {
    let id: Int
    var col: Int
    var row: Int
    let length: Int
    let isHorizontal: Bool
    let isTarget: Bool
}

struct PkPuzzle {
    let cars: [PkCar]
}

// MARK: - Game Logic

private let pkPuzzles: [PkPuzzle] = [
    PkPuzzle(cars: [
        PkCar(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkCar(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 2, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkCar(id: 3, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 4, col: 0, row: 4, length: 3, isHorizontal: true, isTarget: false),
    ]),
    PkPuzzle(cars: [
        PkCar(id: 0, col: 1, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkCar(id: 1, col: 3, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkCar(id: 2, col: 0, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 3, col: 4, row: 1, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 4, col: 1, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 5, col: 5, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkPuzzle(cars: [
        PkCar(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkCar(id: 1, col: 2, row: 1, length: 3, isHorizontal: false, isTarget: false),
        PkCar(id: 2, col: 3, row: 0, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 3, col: 4, row: 2, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 4, col: 0, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 5, col: 3, row: 4, length: 2, isHorizontal: true, isTarget: false),
    ]),
    PkPuzzle(cars: [
        PkCar(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkCar(id: 1, col: 2, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 2, col: 3, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 3, col: 4, row: 0, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 4, col: 0, row: 3, length: 3, isHorizontal: true, isTarget: false),
        PkCar(id: 5, col: 4, row: 3, length: 3, isHorizontal: false, isTarget: false),
    ]),
    PkPuzzle(cars: [
        PkCar(id: 0, col: 0, row: 2, length: 2, isHorizontal: true, isTarget: true),
        PkCar(id: 1, col: 2, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkCar(id: 2, col: 3, row: 1, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 3, col: 5, row: 0, length: 3, isHorizontal: false, isTarget: false),
        PkCar(id: 4, col: 0, row: 4, length: 2, isHorizontal: false, isTarget: false),
        PkCar(id: 5, col: 2, row: 4, length: 2, isHorizontal: true, isTarget: false),
        PkCar(id: 6, col: 4, row: 3, length: 2, isHorizontal: true, isTarget: false),
    ]),
]

enum PkPhase { case start, playing, won }

// MARK: - Main View

struct ParkingView: View {
    @State private var phase: PkPhase = .start
    @State private var puzzleIndex = 0
    @State private var cars: [PkCar] = []
    @State private var moves = 0
    @State private var dragCarID: Int? = nil
    @State private var dragOffset: CGFloat = 0

    let gridSize = 6
    let cellSize: CGFloat = 52

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.14, blue: 0.18).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .won:
                wonScreen
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("PARKING")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text("Slide cars to free\nthe red car's path!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 160, height: 52)
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
        }
    }

    var wonScreen: some View {
        VStack(spacing: 20) {
            Text("SOLVED!")
                .font(.system(size: 40, weight: .black))
                .foregroundColor(.green)
            Text("Moves: \(moves)")
                .foregroundColor(.white)
                .font(.title2)
            HStack(spacing: 16) {
                Button("Next Puzzle") {
                    puzzleIndex = (puzzleIndex + 1) % pkPuzzles.count
                    startGame()
                }
                .buttonStyle(PkButtonStyle(color: .blue))

                Button("Restart") { startGame() }
                    .buttonStyle(PkButtonStyle(color: .yellow))
            }
        }
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Puzzle \(puzzleIndex + 1)/\(pkPuzzles.count)")
                    .foregroundColor(.gray)
                Spacer()
                Text("Moves: \(moves)")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)

            gridView

            Button("Reset") { startGame() }
                .foregroundColor(.orange)
        }
    }

    // MARK: Grid

    var gridView: some View {
        let total = CGFloat(gridSize) * cellSize
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.2))
                .frame(width: total + 24, height: total + 24)

            // Exit marker
            Rectangle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 8, height: cellSize)
                .offset(x: total / 2 + 12, y: -cellSize * 0.5)

            ForEach(cars) { car in
                carView(car: car)
            }
        }
        .frame(width: total + 24, height: total + 24)
    }

    func carView(car: PkCar) -> some View {
        let w = car.isHorizontal ? CGFloat(car.length) * cellSize - 4 : cellSize - 4
        let h = car.isHorizontal ? cellSize - 4 : CGFloat(car.length) * cellSize - 4
        let baseX = CGFloat(car.col) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let baseY = CGFloat(car.row) * cellSize - CGFloat(gridSize) * cellSize / 2 + cellSize / 2
        let extraCols = car.isHorizontal ? CGFloat(car.length - 1) / 2 * cellSize : 0
        let extraRows = car.isHorizontal ? 0 : CGFloat(car.length - 1) / 2 * cellSize
        let dx = dragCarID == car.id && car.isHorizontal ? dragOffset : 0
        let dy = dragCarID == car.id && !car.isHorizontal ? dragOffset : 0

        return RoundedRectangle(cornerRadius: 8)
            .fill(car.isTarget ? Color.red : Color(hue: Double(car.id) * 0.15 + 0.55, saturation: 0.7, brightness: 0.85))
            .frame(width: w, height: h)
            .offset(x: baseX + extraCols + dx, y: baseY + extraRows + dy)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { val in
                    if dragCarID == nil { dragCarID = car.id }
                    guard dragCarID == car.id else { return }
                    if car.isHorizontal {
                        dragOffset = constrainDrag(car: car, raw: val.translation.width)
                    } else {
                        dragOffset = constrainDrag(car: car, raw: val.translation.height)
                    }
                }
                .onEnded { val in
                    guard dragCarID == car.id else { return }
                    commitDrag(carID: car.id, offset: dragOffset)
                    dragCarID = nil
                    dragOffset = 0
                }
            )
    }

    // MARK: Helpers

    func constrainDrag(car: PkCar, raw: CGFloat) -> CGFloat {
        let steps = raw / cellSize
        if car.isHorizontal {
            let minStep = -CGFloat(car.col)
            let maxStep = CGFloat(gridSize - car.col - car.length)
            return max(minStep, min(maxStep, steps)) * cellSize
        } else {
            let minStep = -CGFloat(car.row)
            let maxStep = CGFloat(gridSize - car.row - car.length)
            return max(minStep, min(maxStep, steps)) * cellSize
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

    func canPlace(car: PkCar, excluding id: Int) -> Bool {
        var occ = Set<String>()
        for c in cars where c.id != id {
            for i in 0..<c.length {
                let col = c.isHorizontal ? c.col + i : c.col
                let row = c.isHorizontal ? c.row : c.row + i
                occ.insert("\(col),\(row)")
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
        if let target = cars.first(where: { $0.isTarget }) {
            if target.col + target.length >= gridSize && target.row == 2 {
                phase = .won
            }
        }
    }

    func startGame() {
        cars = pkPuzzles[puzzleIndex].cars
        moves = 0
        phase = .playing
    }
}

struct PkButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(10)
    }
}

#Preview { ParkingView() }
