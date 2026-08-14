import SwiftUI

// MARK: - Gem Color

enum Match3GemColor: Int, CaseIterable {
    case red, blue, green, yellow, purple, orange

    var color: Color {
        switch self {
        case .red:    return Color(red: 1.00, green: 0.20, blue: 0.25)
        case .blue:   return Color(red: 0.20, green: 0.50, blue: 1.00)
        case .green:  return Color(red: 0.10, green: 0.85, blue: 0.35)
        case .yellow: return Color(red: 1.00, green: 0.85, blue: 0.00)
        case .purple: return Color(red: 0.72, green: 0.18, blue: 1.00)
        case .orange: return Color(red: 1.00, green: 0.52, blue: 0.10)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [color.opacity(0.95), color.opacity(0.55)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var symbol: String {
        switch self {
        case .red:    return "suit.heart.fill"
        case .blue:   return "drop.fill"
        case .green:  return "leaf.fill"
        case .yellow: return "star.fill"
        case .purple: return "moon.fill"
        case .orange: return "flame.fill"
        }
    }
}

// MARK: - Gem

struct Match3Gem: Identifiable, Equatable {
    let id: UUID
    var color: Match3GemColor

    init(color: Match3GemColor) {
        self.id = UUID()
        self.color = color
    }

    static func == (lhs: Match3Gem, rhs: Match3Gem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Board

class Match3Board: ObservableObject {
    static let size = 8

    @Published var grid: [[Match3Gem?]]
    @Published var score: Int = 0
    @Published var movesRemaining: Int = 30
    @Published var selectedPosition: (row: Int, col: Int)? = nil
    @Published var isGameOver: Bool = false
    @Published var activeColorCount: Int = 5

    var availableColors: [Match3GemColor] {
        Array(Match3GemColor.allCases.prefix(activeColorCount))
    }

    init(colorCount: Int = 5) {
        self.activeColorCount = colorCount
        grid = Array(
            repeating: Array(repeating: nil, count: Match3Board.size),
            count: Match3Board.size
        )
        fillBoard()
        resolveInitialMatches()
    }

    func randomColor() -> Match3GemColor {
        availableColors.randomElement()!
    }

    func fillBoard() {
        for row in 0..<Match3Board.size {
            for col in 0..<Match3Board.size {
                if grid[row][col] == nil {
                    grid[row][col] = Match3Gem(color: randomColor())
                }
            }
        }
    }

    func resolveInitialMatches() {
        var iter = 0
        while iter < 100 {
            let matched = findMatches()
            if matched.isEmpty { break }
            for pos in matched {
                grid[pos.row][pos.col] = Match3Gem(color: randomColor())
            }
            iter += 1
        }
    }

    func tap(row: Int, col: Int) {
        guard !isGameOver else { return }
        guard grid[row][col] != nil else { return }

        if let sel = selectedPosition {
            if sel.row == row && sel.col == col {
                selectedPosition = nil
                return
            }
            if isAdjacent(sel, (row, col)) {
                selectedPosition = nil
                attemptSwap(from: sel, to: (row, col))
            } else {
                selectedPosition = (row, col)
            }
        } else {
            selectedPosition = (row, col)
        }
    }

    func isAdjacent(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) -> Bool {
        let rd = abs(a.row - b.row)
        let cd = abs(a.col - b.col)
        return (rd == 1 && cd == 0) || (rd == 0 && cd == 1)
    }

    func attemptSwap(from: (row: Int, col: Int), to: (row: Int, col: Int)) {
        movesRemaining -= 1
        swapGems(from, to)

        let matched = findMatches()
        if matched.isEmpty {
            swapGems(from, to)
        } else {
            cascade(initial: matched)
        }

        if movesRemaining <= 0 {
            isGameOver = true
        }
    }

    func cascade(initial: [(row: Int, col: Int)]) {
        var current = initial
        while !current.isEmpty {
            score += current.count * 10
            for pos in current {
                grid[pos.row][pos.col] = nil
            }
            dropGems()
            fillBoard()
            current = findMatches()
        }
    }

    func swapGems(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) {
        let tmp = grid[a.row][a.col]
        grid[a.row][a.col] = grid[b.row][b.col]
        grid[b.row][b.col] = tmp
    }

    func findMatches() -> [(row: Int, col: Int)] {
        var matched: Set<[Int]> = []

        for row in 0..<Match3Board.size {
            var col = 0
            while col < Match3Board.size {
                guard let gem = grid[row][col] else { col += 1; continue }
                var len = 1
                while col + len < Match3Board.size,
                      grid[row][col + len]?.color == gem.color { len += 1 }
                if len >= 3 { for k in 0..<len { matched.insert([row, col + k]) } }
                col += len
            }
        }

        for col in 0..<Match3Board.size {
            var row = 0
            while row < Match3Board.size {
                guard let gem = grid[row][col] else { row += 1; continue }
                var len = 1
                while row + len < Match3Board.size,
                      grid[row + len][col]?.color == gem.color { len += 1 }
                if len >= 3 { for k in 0..<len { matched.insert([row + k, col]) } }
                row += len
            }
        }

        return matched.map { (row: $0[0], col: $0[1]) }
    }

    func dropGems() {
        for col in 0..<Match3Board.size {
            var write = Match3Board.size - 1
            for row in stride(from: Match3Board.size - 1, through: 0, by: -1) {
                if let gem = grid[row][col] {
                    grid[write][col] = gem
                    if write != row { grid[row][col] = nil }
                    write -= 1
                }
            }
            while write >= 0 { grid[write][col] = nil; write -= 1 }
        }
    }

    func restart(colorCount: Int) {
        activeColorCount = colorCount
        grid = Array(
            repeating: Array(repeating: nil, count: Match3Board.size),
            count: Match3Board.size
        )
        score = 0
        movesRemaining = 30
        selectedPosition = nil
        isGameOver = false
        fillBoard()
        resolveInitialMatches()
    }
}

// MARK: - Gem Cell (Glassmorphism)

struct Match3GemCell: View {
    let gem: Match3Gem
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gem.color.gradient.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected
                                ? Color.yellow
                                : Color.white.opacity(0.35),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .shadow(color: gem.color.color.opacity(0.55), radius: isSelected ? 10 : 5)

            Image(systemName: gem.color.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.4, height: size * 0.4)
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.10 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.58), value: isSelected)
    }
}

// MARK: - Main View

struct Match3View: View {
    @StateObject private var board = Match3Board(colorCount: 5)
    @State var roundScores: [Int] = []

    private let padding: CGFloat = 8

    var colorCountForNext: Int {
        guard roundScores.count >= 1 else { return 5 }
        let last = roundScores.suffix(5)
        let avg = last.reduce(0, +) / last.count
        if avg >= 300 { return 6 }
        if avg <= 100 { return 4 }
        return 5
    }

    var difficultyLabel: String {
        "Colors: \(board.activeColorCount)"
    }

    var difficultyColor: Color {
        switch board.activeColorCount {
        case 4: return .green
        case 6: return .red
        default: return .yellow
        }
    }

    var gemSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return (screen - padding * 2 - CGFloat(Match3Board.size + 1) * 4) / CGFloat(Match3Board.size)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.10, green: 0.05, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                hudView
                boardView
                footerView
            }
            .padding(padding)

            if board.isGameOver {
                gameOverOverlay
            }
        }
    }

    // MARK: - Frosted HUD

    var hudView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text("\(board.score)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text(difficultyLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(difficultyColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.18))
                    .cornerRadius(8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("MOVES")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text("\(board.movesRemaining)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(board.movesRemaining <= 5 ? .red : .primary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    // MARK: - Board

    var boardView: some View {
        VStack(spacing: 4) {
            ForEach(0..<Match3Board.size, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<Match3Board.size, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    @ViewBuilder
    func cellView(row: Int, col: Int) -> some View {
        let isSelected = board.selectedPosition?.row == row && board.selectedPosition?.col == col

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .frame(width: gemSize, height: gemSize)

            if let gem = board.grid[row][col] {
                Match3GemCell(
                    gem: gem,
                    isSelected: isSelected,
                    size: gemSize
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.4).combined(with: .opacity),
                    removal: .scale(scale: 1.4).combined(with: .opacity)
                ))
                .id(gem.id)
            }
        }
        .frame(width: gemSize, height: gemSize)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                board.tap(row: row, col: col)
            }
        }
    }

    // MARK: - Footer

    var footerView: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < roundScores.count
                          ? Color.yellow.opacity(0.9)
                          : Color.white.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Round Over")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundStyle(.primary)

                Text("Score: \(board.score)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .monospacedDigit()

                let nextCount = colorCountForNext
                VStack(spacing: 4) {
                    Text("Next difficulty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(nextCount) Colors")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(nextCount == 6 ? .red : nextCount == 4 ? .green : .yellow)
                }

                Button(action: {
                    roundScores.append(board.score)
                    if roundScores.count > 5 { roundScores.removeFirst() }
                    withAnimation(.spring()) {
                        board.restart(colorCount: colorCountForNext)
                    }
                }) {
                    Text("Next Round")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(14)
                }
            }
            .padding(36)
            .background(.regularMaterial)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.45), radius: 28)
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview {
    Match3View()
}
