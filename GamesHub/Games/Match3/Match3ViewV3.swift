import SwiftUI


// MARK: - Inner Shadow Modifier (Inset/Pressed look)

struct Match3V3InnerShadowModifier: ViewModifier {
    let radius: CGFloat
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color(white: 0.60).opacity(isPressed ? 0.50 : 0.20), lineWidth: isPressed ? 2 : 1)
            )
            .shadow(
                color: isPressed ? Color(white: 0.55).opacity(0.55) : Color.clear,
                radius: isPressed ? 4 : 0,
                x: isPressed ? 3 : 0,
                y: isPressed ? 3 : 0
            )
            .shadow(
                color: isPressed ? Color.white.opacity(0.80) : Color.clear,
                radius: isPressed ? 4 : 0,
                x: isPressed ? -3 : 0,
                y: isPressed ? -3 : 0
            )
    }
}

// MARK: - Gem Color (V3, Pastel)

enum Match3V3GemColor: Int, CaseIterable {
    case rose, sky, sage, butter, lavender

    var pastelColor: Color {
        switch self {
        case .rose:     return Color(red: 0.95, green: 0.72, blue: 0.74)
        case .sky:      return Color(red: 0.68, green: 0.83, blue: 0.96)
        case .sage:     return Color(red: 0.72, green: 0.88, blue: 0.76)
        case .butter:   return Color(red: 0.99, green: 0.95, blue: 0.68)
        case .lavender: return Color(red: 0.82, green: 0.75, blue: 0.95)
        }
    }

    var shadowColor: Color {
        pastelColor.opacity(0.55)
    }

    var symbol: String {
        switch self {
        case .rose:     return "suit.heart.fill"
        case .sky:      return "drop.fill"
        case .sage:     return "leaf.fill"
        case .butter:   return "star.fill"
        case .lavender: return "moon.fill"
        }
    }
}

// MARK: - Gem (V3)

struct Match3V3Gem: Identifiable, Equatable {
    let id: UUID
    var color: Match3V3GemColor

    init(color: Match3V3GemColor) {
        self.id = UUID()
        self.color = color
    }

    static func == (lhs: Match3V3Gem, rhs: Match3V3Gem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - LCG Seeded RNG

struct Match3V3LCG {
    var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
        if state == 0 { state = 1 }
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }

    mutating func nextColor() -> Match3V3GemColor {
        let idx = Int(next()) % Match3V3GemColor.allCases.count
        return Match3V3GemColor.allCases[idx]
    }
}

// MARK: - Board (V3)

class Match3V3Board: ObservableObject {
    static let size = 8

    @Published var grid: [[Match3V3Gem?]]
    @Published var score: Int = 0
    @Published var movesRemaining: Int = 30
    @Published var selectedPosition: (row: Int, col: Int)? = nil
    @Published var isGameOver: Bool = false

    private var rng: Match3V3LCG

    init(seed: Int) {
        rng = Match3V3LCG(seed: seed)
        grid = Array(
            repeating: Array(repeating: nil, count: Match3V3Board.size),
            count: Match3V3Board.size
        )
        fillBoardSeeded()
        resolveInitialMatches()
    }

    func nextColor() -> Match3V3GemColor {
        rng.nextColor()
    }

    func fillBoardSeeded() {
        for row in 0..<Match3V3Board.size {
            for col in 0..<Match3V3Board.size {
                if grid[row][col] == nil {
                    grid[row][col] = Match3V3Gem(color: nextColor())
                }
            }
        }
    }

    func fillBoard() {
        for row in 0..<Match3V3Board.size {
            for col in 0..<Match3V3Board.size {
                if grid[row][col] == nil {
                    grid[row][col] = Match3V3Gem(color: nextColor())
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
                grid[pos.row][pos.col] = Match3V3Gem(color: nextColor())
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
            var current = matched
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

        if movesRemaining <= 0 {
            isGameOver = true
        }
    }

    func swapGems(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) {
        let tmp = grid[a.row][a.col]
        grid[a.row][a.col] = grid[b.row][b.col]
        grid[b.row][b.col] = tmp
    }

    func findMatches() -> [(row: Int, col: Int)] {
        var matched: Set<[Int]> = []

        for row in 0..<Match3V3Board.size {
            var col = 0
            while col < Match3V3Board.size {
                guard let gem = grid[row][col] else { col += 1; continue }
                var len = 1
                while col + len < Match3V3Board.size,
                      grid[row][col + len]?.color == gem.color { len += 1 }
                if len >= 3 { for k in 0..<len { matched.insert([row, col + k]) } }
                col += len
            }
        }

        for col in 0..<Match3V3Board.size {
            var row = 0
            while row < Match3V3Board.size {
                guard let gem = grid[row][col] else { row += 1; continue }
                var len = 1
                while row + len < Match3V3Board.size,
                      grid[row + len][col]?.color == gem.color { len += 1 }
                if len >= 3 { for k in 0..<len { matched.insert([row + k, col]) } }
                row += len
            }
        }

        return matched.map { (row: $0[0], col: $0[1]) }
    }

    func dropGems() {
        for col in 0..<Match3V3Board.size {
            var write = Match3V3Board.size - 1
            for row in stride(from: Match3V3Board.size - 1, through: 0, by: -1) {
                if let gem = grid[row][col] {
                    grid[write][col] = gem
                    if write != row { grid[row][col] = nil }
                    write -= 1
                }
            }
            while write >= 0 { grid[write][col] = nil; write -= 1 }
        }
    }

    func restart(seed: Int) {
        rng = Match3V3LCG(seed: seed)
        grid = Array(
            repeating: Array(repeating: nil, count: Match3V3Board.size),
            count: Match3V3Board.size
        )
        score = 0
        movesRemaining = 30
        selectedPosition = nil
        isGameOver = false
        fillBoardSeeded()
        resolveInitialMatches()
    }
}

// MARK: - Gem Cell V3 (Neumorphism)

struct Match3V3GemCell: View {
    let gem: Match3V3Gem
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.90), radius: 4, x: -3, y: -3)
                .shadow(color: Color(white: 0.60).opacity(0.55), radius: 4, x: 3, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    gem.color.pastelColor.opacity(0.55),
                                    gem.color.pastelColor.opacity(0.25)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected
                                ? gem.color.pastelColor.opacity(0.85)
                                : Color.white.opacity(0.45),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )

            Image(systemName: gem.color.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.38, height: size * 0.38)
                .foregroundStyle(gem.color.pastelColor.opacity(0.70))
                .shadow(color: gem.color.pastelColor.opacity(0.4), radius: 2)
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isSelected)
    }
}

// MARK: - Main View V3

struct Match3ViewV3: View {
    @State var seedInt: Int = 42
    @StateObject private var board: Match3V3Board

    private let padding: CGFloat = 8

    init() {
        let initialSeed = 42
        _seedInt = State(initialValue: initialSeed)
        _board = StateObject(wrappedValue: Match3V3Board(seed: initialSeed))
    }

    var gemSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return (screen - padding * 2 - CGFloat(Match3V3Board.size + 1) * 4) / CGFloat(Match3V3Board.size)
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            softGridBackground

            VStack(spacing: 10) {
                hudView
                boardView
                seedView
            }
            .padding(padding)

            if board.isGameOver {
                gameOverOverlay
            }
        }
    }

    // MARK: - Soft Grid Background

    var softGridBackground: some View {
        GeometryReader { geo in
            let cols = 12
            let rows = 20
            let cw = geo.size.width / CGFloat(cols)
            let rh = geo.size.height / CGFloat(rows)

            ZStack {
                ForEach(0..<cols, id: \.self) { c in
                    ForEach(0..<rows, id: \.self) { r in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.88).opacity(0.45))
                            .frame(width: cw * 0.7, height: rh * 0.7)
                            .position(
                                x: CGFloat(c) * cw + cw / 2,
                                y: CGFloat(r) * rh + rh / 2
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Neumorphic HUD

    var hudView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.systemGray))
                Text("\(board.score)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(.darkGray))
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("MOVES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.systemGray))
                Text("\(board.movesRemaining)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(board.movesRemaining <= 5
                                     ? Color(red: 0.90, green: 0.40, blue: 0.40)
                                     : Color(.darkGray))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neumorphicCard(radius: 16)
    }

    // MARK: - Board

    var boardView: some View {
        VStack(spacing: 4) {
            ForEach(0..<Match3V3Board.size, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<Match3V3Board.size, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .padding(8)
        .neumorphicCard(radius: 20)
    }

    @ViewBuilder
    func cellView(row: Int, col: Int) -> some View {
        let isSelected = board.selectedPosition?.row == row && board.selectedPosition?.col == col

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(width: gemSize, height: gemSize)
                .modifier(Match3V3InnerShadowModifier(radius: 12, isPressed: false))

            if let gem = board.grid[row][col] {
                Match3V3GemCell(gem: gem, isSelected: isSelected, size: gemSize)
                    .transition(.scale.combined(with: .opacity))
                    .id(gem.id)
            }
        }
        .frame(width: gemSize, height: gemSize)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                board.tap(row: row, col: col)
            }
        }
    }

    // MARK: - Seed Display

    var seedView: some View {
        Text("SEED: \(seedInt)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color(.systemGray2))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .neumorphicCard(radius: 10)
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Game Over")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(Color(.darkGray))

                Text("Final Score")
                    .font(.headline)
                    .foregroundColor(Color(.systemGray))

                Text("\(board.score)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.70, green: 0.55, blue: 0.90))
                    .monospacedDigit()

                Text("SEED: \(seedInt)")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray2))

                Button(action: {
                    let newSeed = Int.random(in: 1...99999)
                    seedInt = newSeed
                    withAnimation(.spring()) {
                        board.restart(seed: newSeed)
                    }
                }) {
                    Text("New Game")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.darkGray))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                        .padding(4)
                }
            }
            .padding(36)
            .neumorphicCard(radius: 28)
            .padding(24)
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview {
    Match3ViewV3()
}
