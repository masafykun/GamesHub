import SwiftUI

// MARK: - Models

struct ColorFloodCell {
    var colorIndex: Int
}

enum ColorFloodDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var gridSize: Int {
        switch self {
        case .easy:   return 7
        case .medium: return 8
        case .hard:   return 10
        }
    }

    var colorCount: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 5
        case .hard:   return 6
        }
    }

    var maxMoves: Int {
        switch self {
        case .easy:   return 30
        case .medium: return 25
        case .hard:   return 28
        }
    }

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

// MARK: - View Model Logic Helpers

private func colorFloodComputeDifficulty(scores: [Int]) -> ColorFloodDifficulty {
    guard !scores.isEmpty else { return .medium }
    let avg = Double(scores.reduce(0, +)) / Double(scores.count)
    // avg is percentage of board filled relative to max moves
    // High score (>= 80) means player is good -> increase difficulty
    // Low score (< 40) means player is struggling -> decrease difficulty
    if avg >= 75 {
        return .hard
    } else if avg >= 45 {
        return .medium
    } else {
        return .easy
    }
}

// MARK: - Main View

struct ColorFloodViewV2: View {

    // MARK: Difficulty & Scoring
    @State var roundScores: [Int] = []
    @State private var difficulty: ColorFloodDifficulty = .medium

    // MARK: Board State
    @State private var grid: [[ColorFloodCell]] = []
    @State private var playerRegion: Set<ColorFloodCoord> = []
    @State private var moves: Int = 0
    @State private var gamePhase: ColorFloodPhase = .playing

    // MARK: Animation
    @State private var animatingFlood: Bool = false
    @State private var selectedColor: Int? = nil
    @State private var winPulse: Bool = false
    @State private var showResultOverlay: Bool = false

    // MARK: Computed
    private var gridSize: Int { difficulty.gridSize }
    private var colorCount: Int { difficulty.colorCount }
    private var maxMoves: Int { difficulty.maxMoves }

    private let colorPalette: [Color] = [
        Color(red: 0.95, green: 0.27, blue: 0.27), // red
        Color(red: 0.20, green: 0.78, blue: 0.35), // green
        Color(red: 0.25, green: 0.55, blue: 0.95), // blue
        Color(red: 0.98, green: 0.75, blue: 0.15), // yellow
        Color(red: 0.85, green: 0.25, blue: 0.90), // purple
        Color(red: 0.15, green: 0.88, blue: 0.88), // cyan
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 16) {
                headerBar
                difficultyBadge
                boardView
                Spacer(minLength: 8)
                colorButtons
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if showResultOverlay {
                resultOverlay
            }
        }
        .onAppear { startNewGame() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.07, blue: 0.15),
                Color(red: 0.10, green: 0.05, blue: 0.20),
                Color(red: 0.05, green: 0.10, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Color Flood")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("V2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 16) {
                movesCounter
                Button(action: { startNewGame() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding(.top, 4)
    }

    private var movesCounter: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Text("\(moves)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(moveColor)
            Text("/ \(maxMoves)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var moveColor: Color {
        let ratio = Double(moves) / Double(maxMoves)
        if ratio < 0.5 { return .green }
        if ratio < 0.8 { return .orange }
        return .red
    }

    // MARK: - Difficulty Badge

    private var difficultyBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(difficulty.badgeColor)
                .frame(width: 8, height: 8)
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(difficulty.badgeColor)
            Text("· \(gridSize)×\(gridSize) · \(colorCount) colors")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            if !roundScores.isEmpty {
                Text("Avg: \(Int(Double(roundScores.reduce(0, +)) / Double(roundScores.count)))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / CGFloat(gridSize)
            ZStack {
                // Glass card backing
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                VStack(spacing: 2) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                let coord = ColorFloodCoord(row: row, col: col)
                                let inRegion = playerRegion.contains(coord)
                                let colorIdx = grid.isEmpty ? 0 : grid[row][col].colorIndex
                                RoundedRectangle(cornerRadius: cellCornerRadius(size: cellSize))
                                    .fill(colorPalette[min(colorIdx, colorPalette.count - 1)])
                                    .frame(width: cellSize - 2, height: cellSize - 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cellCornerRadius(size: cellSize))
                                            .fill(
                                                inRegion
                                                ? LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                : LinearGradient(colors: [.black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cellCornerRadius(size: cellSize))
                                            .strokeBorder(inRegion ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                    .scaleEffect(inRegion && winPulse ? 0.92 : 1.0)
                                    .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: winPulse)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellCornerRadius(size: CGFloat) -> CGFloat {
        max(2, size * 0.18)
    }

    // MARK: - Color Buttons

    private var colorButtons: some View {
        HStack(spacing: 10) {
            ForEach(0..<colorCount, id: \.self) { idx in
                let isCurrent = !playerRegion.isEmpty && !grid.isEmpty
                    && grid[0][0].colorIndex == idx
                    && playerRegion.contains(ColorFloodCoord(row: 0, col: 0))
                    && colorIndexOfRegion() == idx

                Button(action: {
                    colorFloodTapColor(idx)
                }) {
                    ZStack {
                        Circle()
                            .fill(colorPalette[idx])
                            .shadow(color: colorPalette[idx].opacity(0.6), radius: isCurrent ? 14 : 6, x: 0, y: 0)
                        if isCurrent {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                        }
                        if selectedColor == idx {
                            Circle()
                                .fill(.white.opacity(0.3))
                        }
                    }
                }
                .frame(width: 52, height: 52)
                .scaleEffect(isCurrent ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCurrent)
                .disabled(gamePhase != .playing || animatingFlood)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func colorIndexOfRegion() -> Int {
        guard !grid.isEmpty, let first = playerRegion.first else { return -1 }
        return grid[first.row][first.col].colorIndex
    }

    // MARK: - Result Overlay

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { } // absorb taps

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(gamePhase == .won ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: gamePhase == .won ? "star.fill" : "xmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(gamePhase == .won ? .yellow : .red)
                }

                VStack(spacing: 8) {
                    Text(gamePhase == .won ? "You Win!" : "Game Over")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(gamePhase == .won
                         ? "Flooded in \(moves) moves"
                         : "Ran out of moves!")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))

                    if !roundScores.isEmpty {
                        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
                        Text(String(format: "5-round avg: %.0f%%", avg))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("Next")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        Text(colorFloodComputeDifficulty(scores: roundScores).rawValue)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(colorFloodComputeDifficulty(scores: roundScores).badgeColor)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Button(action: { startNewGame() }) {
                        Text("Play Again")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 4)
                    }
                }
            }
            .padding(36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 28)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: showResultOverlay)
    }

    // MARK: - Game Logic

    private func startNewGame() {
        withAnimation(.easeOut(duration: 0.2)) {
            showResultOverlay = false
        }
        winPulse = false
        animatingFlood = false
        selectedColor = nil
        moves = 0
        gamePhase = .playing

        let size = gridSize
        let colors = colorCount
        var newGrid: [[ColorFloodCell]] = []
        for _ in 0..<size {
            var row: [ColorFloodCell] = []
            for _ in 0..<size {
                row.append(ColorFloodCell(colorIndex: Int.random(in: 0..<colors)))
            }
            newGrid.append(row)
        }
        grid = newGrid
        playerRegion = colorFloodBuildInitialRegion(grid: newGrid, size: size)
    }

    private func colorFloodBuildInitialRegion(grid: [[ColorFloodCell]], size: Int) -> Set<ColorFloodCoord> {
        let startColor = grid[0][0].colorIndex
        var region = Set<ColorFloodCoord>()
        var queue = [ColorFloodCoord(row: 0, col: 0)]
        region.insert(ColorFloodCoord(row: 0, col: 0))
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for neighbor in colorFloodNeighbors(coord: cur, size: size) {
                if !region.contains(neighbor) && grid[neighbor.row][neighbor.col].colorIndex == startColor {
                    region.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        return region
    }

    private func colorFloodTapColor(_ colorIdx: Int) {
        guard gamePhase == .playing, !animatingFlood else { return }
        let currentColor = colorIndexOfRegion()
        guard colorIdx != currentColor else { return }

        selectedColor = colorIdx
        moves += 1
        animatingFlood = true

        // Flood fill: color all cells in playerRegion to new color, then expand
        withAnimation(.easeInOut(duration: 0.18)) {
            for coord in playerRegion {
                grid[coord.row][coord.col].colorIndex = colorIdx
            }
        }

        // Expand region to absorb adjacent matching cells
        let expanded = colorFloodExpandRegion(
            current: playerRegion,
            grid: grid,
            colorIdx: colorIdx,
            size: gridSize
        )

        withAnimation(.easeInOut(duration: 0.22)) {
            playerRegion = expanded
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            animatingFlood = false
            selectedColor = nil
            checkWinLose()
        }
    }

    private func colorFloodExpandRegion(
        current: Set<ColorFloodCoord>,
        grid: [[ColorFloodCell]],
        colorIdx: Int,
        size: Int
    ) -> Set<ColorFloodCoord> {
        var region = current
        var queue = Array(current)
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for neighbor in colorFloodNeighbors(coord: cur, size: size) {
                if !region.contains(neighbor) && grid[neighbor.row][neighbor.col].colorIndex == colorIdx {
                    region.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
        return region
    }

    private func colorFloodNeighbors(coord: ColorFloodCoord, size: Int) -> [ColorFloodCoord] {
        var result: [ColorFloodCoord] = []
        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for (dr, dc) in deltas {
            let nr = coord.row + dr
            let nc = coord.col + dc
            if nr >= 0 && nr < size && nc >= 0 && nc < size {
                result.append(ColorFloodCoord(row: nr, col: nc))
            }
        }
        return result
    }

    private func checkWinLose() {
        let totalCells = gridSize * gridSize
        let won = playerRegion.count == totalCells
        let lost = moves >= maxMoves && !won

        if won {
            gamePhase = .won
            winPulse = true
            let score = max(0, 100 - Int((Double(moves) / Double(maxMoves)) * 100))
            appendScore(score)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                showResultOverlay = true
            }
        } else if lost {
            gamePhase = .lost
            let score = Int((Double(playerRegion.count) / Double(totalCells)) * 100)
            appendScore(score)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showResultOverlay = true
            }
        }
    }

    private func appendScore(_ score: Int) {
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        difficulty = colorFloodComputeDifficulty(scores: roundScores)
    }
}

// MARK: - Supporting Types

struct ColorFloodCoord: Hashable {
    let row: Int
    let col: Int
}

enum ColorFloodPhase {
    case playing, won, lost
}

// MARK: - Preview

#Preview {
    ColorFloodViewV2()
        .preferredColorScheme(.dark)
}
