import SwiftUI

struct SlidingPuzzleView: View {
    @StateObject private var game = SlidingPuzzleGame()

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Sliding Puzzle")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)

                // Stats row
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("MOVES")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text("\(game.moves)")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    .neumorphicCard()
                    .padding(12)

                    VStack(spacing: 4) {
                        Text("TIME")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(game.timeString)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    .neumorphicCard()
                    .padding(12)
                }

                // Grid
                SlidingPuzzleBoardView(game: game)

                Button(action: { game.shuffle() }) {
                    Text("New Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding()

            if game.isWon {
                SlidingPuzzleWinOverlay(moves: game.moves, time: game.timeString) {
                    game.shuffle()
                }
            }
        }
        .onAppear { game.shuffle() }
    }
}

// MARK: - Board View

struct SlidingPuzzleBoardView: View {
    @ObservedObject var game: SlidingPuzzleGame

    private let gridSize = 4
    private let spacing: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let totalSize = min(geo.size.width, geo.size.height)
            let cellSize = (totalSize - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)

            ZStack {
                // Board background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .shadow(color: Color(.systemGray4), radius: 6, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.8), radius: 6, x: -4, y: -4)

                VStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                let index = row * gridSize + col
                                let value = game.tiles[index]
                                SlidingPuzzleTileView(
                                    value: value,
                                    cellSize: cellSize,
                                    isCorrect: value != 0 && value == index + 1
                                )
                                .onTapGesture {
                                    game.tap(index: index)
                                }
                            }
                        }
                    }
                }
                .padding(spacing)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 8)
    }
}

// MARK: - Tile View

struct SlidingPuzzleTileView: View {
    let value: Int
    let cellSize: CGFloat
    let isCorrect: Bool

    var body: some View {
        ZStack {
            if value == 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: cellSize, height: cellSize)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tileColor)
                    .frame(width: cellSize, height: cellSize)
                    .shadow(color: Color(.systemGray4), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)

                Text("\(value)")
                    .font(.system(size: cellSize * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: value)
    }

    private var tileColor: Color {
        if isCorrect {
            return Color.green.opacity(0.85)
        }
        let hue = Double(value - 1) / 15.0
        return Color(hue: 0.6 + hue * 0.3, saturation: 0.7, brightness: 0.75)
    }
}

// MARK: - Win Overlay

struct SlidingPuzzleWinOverlay: View {
    let moves: Int
    let time: String
    let onNewGame: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Puzzle Solved!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("Moves: \(moves)")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.9))
                    Text("Time: \(time)")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button(action: onNewGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(32)
            .background(Color.blue.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Game Logic

class SlidingPuzzleGame: ObservableObject {
    @Published var tiles: [Int] = Array(1...15) + [0]
    @Published var moves: Int = 0
    @Published var isWon: Bool = false
    @Published var elapsed: TimeInterval = 0

    private var timer: Timer?
    private var startTime: Date?
    private var timerStarted = false

    let gridSize = 4

    var timeString: String {
        let total = Int(elapsed)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var emptyIndex: Int {
        tiles.firstIndex(of: 0) ?? 15
    }

    func shuffle() {
        stopTimer()
        isWon = false
        moves = 0
        elapsed = 0
        timerStarted = false

        // Start from solved state and apply random valid moves
        tiles = Array(1...15) + [0]
        var rng = SystemRandomNumberGenerator()
        var lastEmpty = -1
        var empty = 15

        for _ in 0..<300 {
            let neighbors = validNeighbors(for: empty)
            let candidates = neighbors.filter { $0 != lastEmpty }
            let chosen = candidates.randomElement(using: &rng) ?? neighbors.randomElement()!
            tiles.swapAt(empty, chosen)
            lastEmpty = empty
            empty = chosen
        }
    }

    func tap(index: Int) {
        guard !isWon else { return }
        let empty = emptyIndex
        guard isAdjacent(index, empty) else { return }

        if !timerStarted {
            startTimer()
            timerStarted = true
        }

        tiles.swapAt(index, empty)
        moves += 1
        checkWin()
    }

    private func isAdjacent(_ a: Int, _ b: Int) -> Bool {
        let ar = a / gridSize, ac = a % gridSize
        let br = b / gridSize, bc = b % gridSize
        return (ar == br && abs(ac - bc) == 1) || (ac == bc && abs(ar - br) == 1)
    }

    private func validNeighbors(for index: Int) -> [Int] {
        let row = index / gridSize
        let col = index % gridSize
        var result: [Int] = []
        if row > 0 { result.append(index - gridSize) }
        if row < gridSize - 1 { result.append(index + gridSize) }
        if col > 0 { result.append(index - 1) }
        if col < gridSize - 1 { result.append(index + 1) }
        return result
    }

    private func checkWin() {
        let solved = Array(1...15) + [0]
        if tiles == solved {
            isWon = true
            stopTimer()
        }
    }

    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
    }
}
