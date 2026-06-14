import SwiftUI

// MARK: - Cell Types
enum SdFlCellType: UInt8 {
    case empty = 0
    case sand = 1
    case rock = 2
}

// MARK: - Grid Model
struct SdFlGrid {
    static let cols = 60
    static let rows = 100
    var cells: [SdFlCellType]

    init() {
        cells = Array(repeating: .empty, count: SdFlGrid.cols * SdFlGrid.rows)
    }

    subscript(col: Int, row: Int) -> SdFlCellType {
        get {
            guard col >= 0, col < SdFlGrid.cols, row >= 0, row < SdFlGrid.rows else { return .rock }
            return cells[row * SdFlGrid.cols + col]
        }
        set {
            guard col >= 0, col < SdFlGrid.cols, row >= 0, row < SdFlGrid.rows else { return }
            cells[row * SdFlGrid.cols + col] = newValue
        }
    }

    mutating func step() {
        for row in stride(from: SdFlGrid.rows - 2, through: 0, by: -1) {
            for col in 0..<SdFlGrid.cols {
                guard cells[row * SdFlGrid.cols + col] == .sand else { continue }
                if self[col, row + 1] == .empty {
                    self[col, row + 1] = .sand
                    self[col, row] = .empty
                } else {
                    let leftFree = self[col - 1, row + 1] == .empty
                    let rightFree = self[col + 1, row + 1] == .empty
                    if leftFree && rightFree {
                        let dir = Bool.random() ? -1 : 1
                        self[col + dir, row + 1] = .sand
                        self[col, row] = .empty
                    } else if leftFree {
                        self[col - 1, row + 1] = .sand
                        self[col, row] = .empty
                    } else if rightFree {
                        self[col + 1, row + 1] = .sand
                        self[col, row] = .empty
                    }
                }
            }
        }
    }
}

// MARK: - Brush Tool
enum SdFlBrush {
    case sand, rock, eraser
}

// MARK: - Game Phase
enum SdFlPhase {
    case start, playing, cleared
}

// MARK: - Main View
struct SandFallView: View {
    @State private var grid = SdFlGrid()
    @State private var phase: SdFlPhase = .start
    @State private var brush: SdFlBrush = .sand
    @State private var score: Int = 0
    @State private var timer: Timer? = nil
    @State private var tickCount: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                playingScreen
            case .cleared:
                clearedScreen
            }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("SandFall")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.orange)
            Text("Drag to paint sand and watch it fall!\nUse rock to build walls.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: startGame) {
                Text("Start")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Playing Screen
    var playingScreen: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Sand: \(sandCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.orange)
                Spacer()
                Text("Score: \(score)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
                Spacer()
                Button("Clear") {
                    grid = SdFlGrid()
                    score = 0
                }
                .font(.caption.bold())
                .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.1))

            // Canvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    let cellW = size.width / CGFloat(SdFlGrid.cols)
                    let cellH = size.height / CGFloat(SdFlGrid.rows)
                    for row in 0..<SdFlGrid.rows {
                        for col in 0..<SdFlGrid.cols {
                            let cell = grid[col, row]
                            guard cell != .empty else { continue }
                            let color: Color = cell == .sand ? .orange : Color(red: 0.5, green: 0.35, blue: 0.2)
                            ctx.fill(
                                Path(CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH, width: cellW + 0.5, height: cellH + 0.5)),
                                with: .color(color)
                            )
                        }
                    }
                }
                .background(Color(white: 0.05))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            paintAt(val.location, in: geo.size)
                        }
                )
            }

            // Brush toolbar
            HStack(spacing: 16) {
                brushButton("Sand", color: .orange, selected: brush == .sand) { brush = .sand }
                brushButton("Rock", color: Color(red: 0.5, green: 0.35, blue: 0.2), selected: brush == .rock) { brush = .rock }
                brushButton("Erase", color: .gray, selected: brush == .eraser) { brush = .eraser }
                Spacer()
                Button("End") {
                    stopGame()
                    phase = .cleared
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.indigo)
                .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.1))
        }
    }

    func brushButton(_ label: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(selected ? .black : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? color : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1.5))
                .cornerRadius(8)
        }
    }

    // MARK: - Cleared Screen
    var clearedScreen: some View {
        VStack(spacing: 20) {
            Text("Session Over")
                .font(.largeTitle.bold())
                .foregroundColor(.orange)
            Text("Sand placed: \(score)")
                .font(.title2)
                .foregroundColor(.white)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers
    var sandCount: Int {
        grid.cells.filter { $0 == .sand }.count
    }

    func paintAt(_ location: CGPoint, in size: CGSize) {
        let col = Int(location.x / size.width * CGFloat(SdFlGrid.cols))
        let row = Int(location.y / size.height * CGFloat(SdFlGrid.rows))
        guard col >= 0, col < SdFlGrid.cols, row >= 0, row < SdFlGrid.rows else { return }
        switch brush {
        case .sand:
            if grid[col, row] == .empty {
                grid[col, row] = .sand
                score += 1
            }
        case .rock:
            grid[col, row] = .rock
        case .eraser:
            grid[col, row] = .empty
        }
    }

    func startGame() {
        grid = SdFlGrid()
        score = 0
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            grid.step()
            tickCount += 1
        }
    }

    func stopGame() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview { SandFallView() }
