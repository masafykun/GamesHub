import SwiftUI

// MARK: - Model

enum ColorFloodColorV3: Int, CaseIterable {
    case red = 0, orange, yellow, green, blue

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.90, green: 0.30, blue: 0.30)
        case .orange: return Color(red: 0.95, green: 0.60, blue: 0.20)
        case .yellow: return Color(red: 0.95, green: 0.85, blue: 0.20)
        case .green:  return Color(red: 0.25, green: 0.75, blue: 0.45)
        case .blue:   return Color(red: 0.25, green: 0.50, blue: 0.90)
        }
    }
}

struct ColorFloodBoardV3 {
    static let size = 8
    static let maxMoves = 25
    static let colorCount = ColorFloodColorV3.allCases.count

    var cells: [[Int]]  // 0-based color indices

    // Generate board from seed using LCG
    init(seed: Int) {
        var s = UInt64(seed)
        var grid = [[Int]](repeating: [Int](repeating: 0, count: ColorFloodBoardV3.size),
                           count: ColorFloodBoardV3.size)
        for row in 0..<ColorFloodBoardV3.size {
            for col in 0..<ColorFloodBoardV3.size {
                s = s &* 6364136223846793005 &+ 1442695040888963407
                grid[row][col] = Int((s >> 33) % UInt64(ColorFloodBoardV3.colorCount))
            }
        }
        cells = grid
    }

    // Current color of the player's region (top-left cell)
    var playerColor: Int { cells[0][0] }

    // Flood-fill from top-left with chosen color
    mutating func flood(with newColor: Int) {
        let oldColor = cells[0][0]
        guard newColor != oldColor else { return }
        floodFill(row: 0, col: 0, oldColor: oldColor, newColor: newColor)
    }

    private mutating func floodFill(row: Int, col: Int, oldColor: Int, newColor: Int) {
        var stack: [(Int, Int)] = [(row, col)]
        while !stack.isEmpty {
            let (r, c) = stack.removeLast()
            guard r >= 0, r < ColorFloodBoardV3.size,
                  c >= 0, c < ColorFloodBoardV3.size,
                  cells[r][c] == oldColor else { continue }
            cells[r][c] = newColor
            stack.append((r - 1, c))
            stack.append((r + 1, c))
            stack.append((r, c - 1))
            stack.append((r, c + 1))
        }
    }

    // Determine which cells belong to player's region (connected from top-left)
    func playerRegion() -> Set<ColorFloodCellV3> {
        let target = cells[0][0]
        var visited = Set<ColorFloodCellV3>()
        var stack: [ColorFloodCellV3] = [ColorFloodCellV3(row: 0, col: 0)]
        while !stack.isEmpty {
            let pos = stack.removeLast()
            guard pos.row >= 0, pos.row < ColorFloodBoardV3.size,
                  pos.col >= 0, pos.col < ColorFloodBoardV3.size,
                  !visited.contains(pos),
                  cells[pos.row][pos.col] == target else { continue }
            visited.insert(pos)
            stack.append(ColorFloodCellV3(row: pos.row - 1, col: pos.col))
            stack.append(ColorFloodCellV3(row: pos.row + 1, col: pos.col))
            stack.append(ColorFloodCellV3(row: pos.row, col: pos.col - 1))
            stack.append(ColorFloodCellV3(row: pos.row, col: pos.col + 1))
        }
        return visited
    }

    var isAllSameColor: Bool {
        let first = cells[0][0]
        return cells.allSatisfy { row in row.allSatisfy { $0 == first } }
    }
}

struct ColorFloodCellV3: Hashable {
    let row: Int
    let col: Int
}

// MARK: - Game State

enum ColorFloodGameStateV3 {
    case playing, won, lost
}

// MARK: - Main View

struct ColorFloodViewV3: View {
    @State var seedInt: Int = 1
    @State private var board: ColorFloodBoardV3 = ColorFloodBoardV3(seed: 1)
    @State private var moves: Int = 0
    @State private var gameState: ColorFloodGameStateV3 = .playing
    @State private var playerRegion: Set<ColorFloodCellV3> = []
    @State private var animatingColor: Int? = nil

    let maxMoves = ColorFloodBoardV3.maxMoves
    let gridSize = ColorFloodBoardV3.size

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                // Seed display
                seedView

                // Grid
                gridView

                // Color buttons
                colorButtonsView

                // Game over overlay trigger area (handled inline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Overlay
            if gameState != .playing {
                overlayView
            }
        }
        .onAppear {
            startGame(seed: seedInt)
        }
    }

    // MARK: - Sub-views

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("COLOR FLOOD")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("V3 · Procedural")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOVES")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                HStack(alignment: .bottom, spacing: 2) {
                    Text("\(moves)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(movesColor)
                    Text("/ \(maxMoves)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neumorphicCard()
    }

    private var seedView: some View {
        HStack {
            Image(systemName: "number.square.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            Text("SEED: #\(seedInt)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
            Text("8×8 · 5 Colors")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .neumorphicCard()
    }

    private var gridView: some View {
        GeometryReader { geo in
            let totalSpacing = CGFloat(gridSize - 1) * 3
            let cellSize = (geo.size.width - totalSpacing) / CGFloat(gridSize)

            VStack(spacing: 3) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let colorIdx = board.cells[row][col]
                            let isInRegion = playerRegion.contains(ColorFloodCellV3(row: row, col: col))
                            let cellColor = ColorFloodColorV3(rawValue: colorIdx)?.color ?? .gray

                            RoundedRectangle(cornerRadius: 5)
                                .fill(cellColor)
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(
                                            isInRegion ? Color.white.opacity(0.6) : Color.clear,
                                            lineWidth: isInRegion ? 1.5 : 0
                                        )
                                )
                                .shadow(
                                    color: isInRegion ? cellColor.opacity(0.5) : Color.black.opacity(0.08),
                                    radius: isInRegion ? 4 : 2,
                                    x: isInRegion ? 0 : 1,
                                    y: isInRegion ? 0 : 1
                                )
                                .scaleEffect(isInRegion ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isInRegion)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
        .neumorphicCard()
    }

    private var colorButtonsView: some View {
        VStack(spacing: 12) {
            Text("CHOOSE COLOR")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(ColorFloodColorV3.allCases, id: \.rawValue) { colorOption in
                    let isCurrentColor = (colorOption.rawValue == board.playerColor)
                    let isDisabled = (gameState != .playing)

                    Button {
                        guard gameState == .playing else { return }
                        guard colorOption.rawValue != board.playerColor else { return }
                        tapColor(colorOption.rawValue)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorOption.color)
                                .shadow(color: colorOption.color.opacity(0.5), radius: isCurrentColor ? 8 : 3, x: 0, y: isCurrentColor ? 4 : 2)

                            if isCurrentColor {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 2.5)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                            }
                        }
                        .frame(height: 50)
                        .scaleEffect(isCurrentColor ? 1.08 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCurrentColor)
                    }
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.5 : 1.0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neumorphicCard()
    }

    private var overlayView: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .blur(radius: 0)

            VStack(spacing: 24) {
                // Icon
                Image(systemName: gameState == .won ? "star.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(gameState == .won ? .yellow : Color(red: 0.9, green: 0.3, blue: 0.3))
                    .shadow(color: gameState == .won ? .yellow.opacity(0.6) : Color.red.opacity(0.4), radius: 12)

                // Title
                Text(gameState == .won ? "YOU WIN!" : "GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                // Stats
                VStack(spacing: 8) {
                    HStack {
                        Text("Seed")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("#\(seedInt)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    Divider()
                    HStack {
                        Text("Moves used")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(moves) / \(maxMoves)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(movesColor)
                    }
                    if gameState == .won {
                        Divider()
                        HStack {
                            Text("Rating")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(winRating)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .neumorphicCard()

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        restartGame(sameSeed: true)
                    } label: {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .neumorphicCard()

                    Button {
                        restartGame(sameSeed: false)
                    } label: {
                        Label("New Seed", systemImage: "dice")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.25, green: 0.50, blue: 0.90), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(red: 0.25, green: 0.50, blue: 0.90).opacity(0.4), radius: 8, y: 4)
                    }
                }
            }
            .padding(28)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .white.opacity(0.7), radius: 12, x: -6, y: -6)
            .shadow(color: Color(.systemGray4), radius: 12, x: 6, y: 6)
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gameState)
    }

    // MARK: - Computed

    private var movesColor: Color {
        let ratio = Double(moves) / Double(maxMoves)
        if ratio < 0.5 { return .green }
        if ratio < 0.8 { return .orange }
        return .red
    }

    private var winRating: String {
        let ratio = Double(moves) / Double(maxMoves)
        if ratio <= 0.5 { return "★★★ Perfect!" }
        if ratio <= 0.75 { return "★★☆ Great!" }
        return "★☆☆ Good!"
    }

    // MARK: - Actions

    private func tapColor(_ colorIdx: Int) {
        guard gameState == .playing else { return }
        board.flood(with: colorIdx)
        moves += 1
        playerRegion = board.playerRegion()

        if board.isAllSameColor {
            withAnimation { gameState = .won }
        } else if moves >= maxMoves {
            withAnimation { gameState = .lost }
        }
    }

    private func startGame(seed: Int) {
        board = ColorFloodBoardV3(seed: seed)
        moves = 0
        gameState = .playing
        playerRegion = board.playerRegion()
    }

    private func restartGame(sameSeed: Bool) {
        if !sameSeed {
            seedInt += 1
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            startGame(seed: seedInt)
        }
    }
}

// MARK: - Preview

#Preview {
    ColorFloodViewV3()
}
