import SwiftUI

// MARK: - Gem Color

enum Match3GemColor: Int, CaseIterable {
    case red, blue, green, yellow, purple

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.90, green: 0.22, blue: 0.22)
        case .blue:   return Color(red: 0.18, green: 0.45, blue: 0.90)
        case .green:  return Color(red: 0.15, green: 0.72, blue: 0.30)
        case .yellow: return Color(red: 0.97, green: 0.78, blue: 0.10)
        case .purple: return Color(red: 0.62, green: 0.18, blue: 0.88)
        }
    }

    var symbol: String {
        switch self {
        case .red:    return "suit.heart.fill"
        case .blue:   return "drop.fill"
        case .green:  return "leaf.fill"
        case .yellow: return "star.fill"
        case .purple: return "moon.fill"
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
    static let gemColors = Match3GemColor.allCases

    @Published var grid: [[Match3Gem?]]
    @Published var score: Int = 0
    @Published var movesRemaining: Int = 30
    @Published var selectedPosition: (row: Int, col: Int)? = nil
    @Published var isGameOver: Bool = false
    @Published var animatingRemoval: Set<UUID> = []

    init() {
        grid = Array(
            repeating: Array(repeating: nil, count: Match3Board.size),
            count: Match3Board.size
        )
        fillBoard()
        resolveInitialMatches()
    }

    // MARK: - Board Setup

    func fillBoard() {
        for row in 0..<Match3Board.size {
            for col in 0..<Match3Board.size {
                if grid[row][col] == nil {
                    grid[row][col] = Match3Gem(color: randomColor())
                }
            }
        }
    }

    func randomColor() -> Match3GemColor {
        Match3Board.gemColors.randomElement()!
    }

    func resolveInitialMatches() {
        var iterations = 0
        while iterations < 100 {
            let matched = findMatches()
            if matched.isEmpty { break }
            for pos in matched {
                grid[pos.row][pos.col] = Match3Gem(color: randomColor())
            }
            iterations += 1
        }
    }

    // MARK: - Selection & Swap

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
        let rowDiff = abs(a.row - b.row)
        let colDiff = abs(a.col - b.col)
        return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1)
    }

    func attemptSwap(from: (row: Int, col: Int), to: (row: Int, col: Int)) {
        movesRemaining -= 1
        swapGems(from, to)

        let matched = findMatches()
        if matched.isEmpty {
            swapGems(from, to) // revert
        } else {
            var currentMatches = matched
            while !currentMatches.isEmpty {
                score += currentMatches.count * 10
                for pos in currentMatches {
                    grid[pos.row][pos.col] = nil
                }
                dropGems()
                fillBoard()
                currentMatches = findMatches()
            }
        }

        if movesRemaining <= 0 {
            isGameOver = true
        }
    }

    func swapGems(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) {
        let tmp = grid[a.row][a.col]
        grid[a.row][a.col] = grid[b.row][b.col]
        grid[b.row][b.col] = tmp
    }

    // MARK: - Match Detection

    func findMatches() -> [(row: Int, col: Int)] {
        var matched: Set<[Int]> = []

        for row in 0..<Match3Board.size {
            var col = 0
            while col < Match3Board.size {
                guard let gem = grid[row][col] else { col += 1; continue }
                var length = 1
                while col + length < Match3Board.size,
                      grid[row][col + length]?.color == gem.color {
                    length += 1
                }
                if length >= 3 {
                    for k in 0..<length {
                        matched.insert([row, col + k])
                    }
                }
                col += length
            }
        }

        for col in 0..<Match3Board.size {
            var row = 0
            while row < Match3Board.size {
                guard let gem = grid[row][col] else { row += 1; continue }
                var length = 1
                while row + length < Match3Board.size,
                      grid[row + length][col]?.color == gem.color {
                    length += 1
                }
                if length >= 3 {
                    for k in 0..<length {
                        matched.insert([row + k, col])
                    }
                }
                row += length
            }
        }

        return matched.map { (row: $0[0], col: $0[1]) }
    }

    // MARK: - Gravity / Drop

    func dropGems() {
        for col in 0..<Match3Board.size {
            var writeRow = Match3Board.size - 1
            for row in stride(from: Match3Board.size - 1, through: 0, by: -1) {
                if let gem = grid[row][col] {
                    grid[writeRow][col] = gem
                    if writeRow != row {
                        grid[row][col] = nil
                    }
                    writeRow -= 1
                }
            }
            while writeRow >= 0 {
                grid[writeRow][col] = nil
                writeRow -= 1
            }
        }
    }

    // MARK: - Restart

    func restart() {
        grid = Array(
            repeating: Array(repeating: nil, count: Match3Board.size),
            count: Match3Board.size
        )
        score = 0
        movesRemaining = 30
        selectedPosition = nil
        isGameOver = false
        animatingRemoval = []
        fillBoard()
        resolveInitialMatches()
    }
}

// MARK: - Gem Cell View

struct Match3GemCell: View {
    let gem: Match3Gem
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [gem.color.color.opacity(0.85), gem.color.color]),
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.7
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.yellow : Color.white.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1.5
                        )
                )
                .shadow(color: gem.color.color.opacity(0.5), radius: isSelected ? 6 : 3)

            Image(systemName: gem.color.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.38, height: size * 0.38)
                .foregroundColor(.white.opacity(0.90))
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.12 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Main View

struct Match3View: View {
    @StateObject private var board = Match3Board()

    private let padding: CGFloat = 8

    var gemSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return (screen - padding * 2 - CGFloat(Match3Board.size + 1) * 4) / CGFloat(Match3Board.size)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.12, green: 0.06, blue: 0.28)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
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

    // MARK: - HUD

    var hudView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(board.score)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("MOVES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(board.movesRemaining)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(board.movesRemaining <= 5 ? .red : .white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
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
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    @ViewBuilder
    func cellView(row: Int, col: Int) -> some View {
        let isSelected = board.selectedPosition?.row == row && board.selectedPosition?.col == col

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .frame(width: gemSize, height: gemSize)

            if let gem = board.grid[row][col] {
                Match3GemCell(gem: gem, isSelected: isSelected, size: gemSize)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: gemSize, height: gemSize)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                board.tap(row: row, col: col)
            }
        }
    }

    // MARK: - Footer

    var footerView: some View {
        Text("Match 3+ gems in a row or column")
            .font(.caption)
            .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(.white)

                Text("Final Score")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))

                Text("\(board.score)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(.yellow)
                    .monospacedDigit()

                Button(action: {
                    withAnimation(.spring()) {
                        board.restart()
                    }
                }) {
                    Text("Restart")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .cornerRadius(14)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.22))
                    .shadow(color: .black.opacity(0.5), radius: 24)
            )
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview {
    Match3View()
}
