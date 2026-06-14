import SwiftUI

// MARK: - Cell Types V2
enum SdFlV2CellType: UInt8 {
    case empty = 0
    case sand = 1
    case rock = 2
}

// MARK: - Grid V2
struct SdFlV2Grid {
    static let cols = 60
    static let rows = 100
    var cells: [SdFlV2CellType]

    init() {
        cells = Array(repeating: .empty, count: SdFlV2Grid.cols * SdFlV2Grid.rows)
    }

    subscript(col: Int, row: Int) -> SdFlV2CellType {
        get {
            guard col >= 0, col < SdFlV2Grid.cols, row >= 0, row < SdFlV2Grid.rows else { return .rock }
            return cells[row * SdFlV2Grid.cols + col]
        }
        set {
            guard col >= 0, col < SdFlV2Grid.cols, row >= 0, row < SdFlV2Grid.rows else { return }
            cells[row * SdFlV2Grid.cols + col] = newValue
        }
    }

    mutating func step() {
        for row in stride(from: SdFlV2Grid.rows - 2, through: 0, by: -1) {
            for col in 0..<SdFlV2Grid.cols {
                guard cells[row * SdFlV2Grid.cols + col] == .sand else { continue }
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

// MARK: - Brush V2
enum SdFlV2Brush {
    case sand, rock, eraser
}

// MARK: - Phase V2
enum SdFlV2Phase {
    case start, playing, results
}

// MARK: - SandFallViewV2
struct SandFallViewV2: View {
    @State private var grid = SdFlV2Grid()
    @State private var phase: SdFlV2Phase = .start
    @State private var brush: SdFlV2Brush = .sand
    @State private var score: Int = 0
    @State private var timer: Timer? = nil
    @State private var simSpeed: Double = 1.0 / 15.0
    @State private var recentResults: [Bool] = []

    private let bgGradient = LinearGradient(
        colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.05, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                playingScreen
            case .results:
                resultsScreen
            }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("SandFall")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                Text("Adaptive Edition")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: 10) {
                Text("Paint sand, build structures.")
                    .foregroundColor(.white.opacity(0.8))
                Text("Difficulty adapts as you play.")
                    .foregroundColor(.white.opacity(0.6))
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button(action: startGame) {
                Text("Begin")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.8), lineWidth: 1.5))
            }
        }
        .padding(24)
    }

    // MARK: - Playing Screen
    var playingScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAND")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(sandCount)")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(.orange)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(score)")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SPEED")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.0fx", 1.0 / (simSpeed * 15.0)))
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(simSpeed < 1.0 / 15.0 ? .red : .green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(.white.opacity(0.15)), alignment: .bottom)

            // Canvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    let cellW = size.width / CGFloat(SdFlV2Grid.cols)
                    let cellH = size.height / CGFloat(SdFlV2Grid.rows)
                    for row in 0..<SdFlV2Grid.rows {
                        for col in 0..<SdFlV2Grid.cols {
                            let cell = grid[col, row]
                            guard cell != .empty else { continue }
                            let color: Color = cell == .sand
                                ? Color(red: 1.0, green: 0.6, blue: 0.1)
                                : Color(red: 0.45, green: 0.3, blue: 0.18)
                            ctx.fill(
                                Path(CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH, width: cellW + 0.5, height: cellH + 0.5)),
                                with: .color(color)
                            )
                        }
                    }
                }
                .background(Color.black.opacity(0.4))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            paintAt(val.location, in: geo.size)
                        }
                )
            }

            // Toolbar
            HStack(spacing: 10) {
                glassToolButton("Sand", accent: .orange, selected: brush == .sand) { brush = .sand }
                glassToolButton("Rock", accent: Color(red: 0.55, green: 0.38, blue: 0.2), selected: brush == .rock) { brush = .rock }
                glassToolButton("Erase", accent: .gray, selected: brush == .eraser) { brush = .eraser }
                Spacer()
                Button {
                    grid = SdFlV2Grid()
                    score = 0
                } label: {
                    Text("Clear")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 1))
                }
                Button {
                    recordResult()
                    stopGame()
                    phase = .results
                } label: {
                    Text("End")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    func glassToolButton(_ label: String, accent: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(selected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? accent : Color.clear)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? accent : .white.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Results Screen
    var resultsScreen: some View {
        VStack(spacing: 24) {
            Text("Session Complete")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            VStack(spacing: 16) {
                statRow("Sand Placed", value: "\(score)")
                statRow("Sim Speed", value: String(format: "%.1fx", 1.0 / (simSpeed * 15.0)))
                statRow("Sessions", value: "\(recentResults.count)")
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.8), lineWidth: 1.5))
            }
        }
        .padding(24)
    }

    func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.body.bold())
                .foregroundColor(.white)
        }
    }

    // MARK: - Helpers
    var sandCount: Int {
        grid.cells.filter { $0 == .sand }.count
    }

    func paintAt(_ location: CGPoint, in size: CGSize) {
        let col = Int(location.x / size.width * CGFloat(SdFlV2Grid.cols))
        let row = Int(location.y / size.height * CGFloat(SdFlV2Grid.rows))
        guard col >= 0, col < SdFlV2Grid.cols, row >= 0, row < SdFlV2Grid.rows else { return }
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

    func recordResult() {
        let isGood = score > 50
        recentResults.append(isGood)
        if recentResults.count > 10 { recentResults.removeFirst() }
        let last5 = recentResults.suffix(5)
        if last5.count == 5 && last5.filter({ $0 }).count > 4 {
            // Increase difficulty by ~20% (faster simulation)
            simSpeed = max(simSpeed * 0.8, 1.0 / 30.0)
        }
    }

    func startGame() {
        grid = SdFlV2Grid()
        score = 0
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: simSpeed, repeats: true) { _ in
            grid.step()
        }
    }

    func stopGame() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview { SandFallViewV2() }
