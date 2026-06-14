import SwiftUI

// MARK: - Main View

struct SlidingPuzzleViewV3: View {
    @StateObject private var game = SlidingPuzzleGameV3()
    @State var seedInt: Int = 1

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("Sliding Puzzle")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)

                // Seed display — always visible
                Text("SEED: #\(seedInt)")
                    .font(.headline.bold())
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .neumorphicCard()

                // Stats row
                HStack(spacing: 32) {
                    SlidingPuzzleV3StatCard(label: "MOVES", value: "\(game.moves)")
                    SlidingPuzzleV3StatCard(label: "TIME", value: game.timeString)
                }

                // Board
                SlidingPuzzleBoardV3(game: game)

                // New Game button
                Button(action: {
                    seedInt += 1
                    game.shuffleWithSeed(seedInt)
                }) {
                    Text("New Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding()

            // Win overlay
            if game.isWon {
                SlidingPuzzleWinOverlayV3(
                    moves: game.moves,
                    time: game.timeString,
                    seed: seedInt
                ) {
                    seedInt += 1
                    game.shuffleWithSeed(seedInt)
                }
            }
        }
        .onAppear {
            game.shuffleWithSeed(seedInt)
        }
    }
}

// MARK: - Stat Card

struct SlidingPuzzleV3StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .neumorphicCard()
    }
}

// MARK: - Board View

struct SlidingPuzzleBoardV3: View {
    @ObservedObject var game: SlidingPuzzleGameV3

    private let gridSize = 4
    private let spacing: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let totalSize = min(geo.size.width, geo.size.height)
            let cellSize = (totalSize - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)

            ZStack {
                // Inset board background
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray5))
                    .shadow(color: Color(.systemGray4).opacity(0.8), radius: 8, x: 5, y: 5)
                    .shadow(color: .white.opacity(0.85), radius: 8, x: -5, y: -5)

                VStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                let index = row * gridSize + col
                                let value = game.tiles[index]
                                SlidingPuzzleTileV3(
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

struct SlidingPuzzleTileV3: View {
    let value: Int
    let cellSize: CGFloat
    let isCorrect: Bool

    var body: some View {
        ZStack {
            if value == 0 {
                // Empty slot — inset shadow to show recess
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
                    )
            } else {
                // Neumorphic tile
                RoundedRectangle(cornerRadius: 10)
                    .fill(tileBackground)
                    .frame(width: cellSize, height: cellSize)
                    .shadow(color: Color(.systemGray4).opacity(0.7), radius: 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isCorrect ? Color.green.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )

                Text("\(value)")
                    .font(.system(size: cellSize * 0.38, weight: .bold, design: .rounded))
                    .foregroundColor(isCorrect ? .green : .primary)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: value)
        .animation(.easeInOut(duration: 0.12), value: isCorrect)
    }

    private var tileBackground: Color {
        Color(.systemGray6)
    }
}

// MARK: - Win Overlay

struct SlidingPuzzleWinOverlayV3: View {
    let moves: Int
    let time: String
    let seed: Int
    let onNewGame: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Puzzle Solved!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)

                Text("SEED: #\(seed)")
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)

                VStack(spacing: 10) {
                    HStack {
                        Text("Moves:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(moves)")
                            .bold()
                            .foregroundColor(.primary)
                    }
                    Divider()
                    HStack {
                        Text("Time:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(time)
                            .bold()
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                }
                .padding()
                .neumorphicCard()
                .padding(.horizontal, 4)

                Button(action: onNewGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color(.systemGray4), radius: 12, x: 6, y: 6)
            .shadow(color: .white.opacity(0.8), radius: 12, x: -6, y: -6)
            .padding(32)
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

class SlidingPuzzleGameV3: ObservableObject {
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

    // LCG-based deterministic shuffle using provided seed
    func shuffleWithSeed(_ seedInt: Int) {
        stopTimer()
        isWon = false
        moves = 0
        elapsed = 0
        timerStarted = false

        // Reset to solved state
        tiles = Array(1...15) + [0]
        var empty = 15

        // LCG seeded RNG
        var s = UInt64(bitPattern: Int64(seedInt))
        s = s &* 6364136223846793005 &+ 1442695040888963407

        var lastEmpty = -1

        // Perform 300 seeded random valid moves from solved state
        for _ in 0..<300 {
            let neighbors = validNeighbors(for: empty)
            let candidates = neighbors.filter { $0 != lastEmpty }
            let pool = candidates.isEmpty ? neighbors : candidates

            // Next LCG step to pick index
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let chosen = pool[Int(s >> 33) % pool.count]

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
