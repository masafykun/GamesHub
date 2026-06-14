import SwiftUI

// MARK: - LCG Seed Generator

private func lightsOutLCGSeed(_ seedInt: Int) -> UInt64 {
    var s = UInt64(bitPattern: Int64(seedInt))
    s = s &* 6364136223846793005 &+ 1442695040888963407
    return s
}

// MARK: - Grid Model (V3)

struct LightsOutV3Grid {
    static let size = 5
    var cells: [[Bool]]

    init() {
        cells = Array(repeating: Array(repeating: false, count: LightsOutV3Grid.size), count: LightsOutV3Grid.size)
    }

    var isAllOff: Bool {
        cells.allSatisfy { row in row.allSatisfy { !$0 } }
    }

    mutating func toggle(row: Int, col: Int) {
        let n = LightsOutV3Grid.size
        let neighbors: [(Int, Int)] = [
            (row, col),
            (row - 1, col),
            (row + 1, col),
            (row, col - 1),
            (row, col + 1)
        ]
        for (r, c) in neighbors where r >= 0 && r < n && c >= 0 && c < n {
            cells[r][c].toggle()
        }
    }
}

// MARK: - Game State (V3)

class LightsOutV3GameState: ObservableObject {
    @Published var grid: LightsOutV3Grid = LightsOutV3Grid()
    @Published var moves: Int = 0
    @Published var isWon: Bool = false

    func newPuzzle(seedInt: Int) {
        var s = lightsOutLCGSeed(seedInt)
        var g = LightsOutV3Grid()
        let n = LightsOutV3Grid.size

        // Determine number of random toggle operations (5–15) from seed
        s = s &* 6364136223846793005 &+ 1442695040888963407
        let numToggles = Int(s >> 58) % 11 + 5  // range [5, 15]

        for _ in 0..<numToggles {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let r = Int(s >> 59) % n
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let c = Int(s >> 59) % n
            g.toggle(row: r, col: c)
        }

        // If all off by coincidence, force one toggle on (0,0) to ensure non-trivial puzzle
        if g.isAllOff {
            g.toggle(row: 0, col: 0)
        }

        grid = g
        moves = 0
        isWon = false
    }

    func tap(row: Int, col: Int) {
        guard !isWon else { return }
        grid.toggle(row: row, col: col)
        moves += 1
        if grid.isAllOff {
            isWon = true
        }
    }
}

// MARK: - Neumorphic Cell (V3)

struct LightsOutV3CellView: View {
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                // Neumorphic shadows: inset when on, raised when off
                .shadow(
                    color: isOn ? Color.clear : Color(.systemGray4),
                    radius: isOn ? 0 : 5, x: isOn ? 0 : 4, y: isOn ? 0 : 4
                )
                .shadow(
                    color: isOn ? Color.clear : Color.white.opacity(0.85),
                    radius: isOn ? 0 : 5, x: isOn ? 0 : -4, y: isOn ? 0 : -4
                )

            if isOn {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.yellow.opacity(0.55), radius: 8)
            }

            Circle()
                .fill(isOn ? Color.yellow : Color(.systemGray4).opacity(0.5))
                .frame(width: 10, height: 10)
                .opacity(isOn ? 1 : 0.4)
        }
        .animation(.easeInOut(duration: 0.18), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Grid View (V3)

struct LightsOutV3GridView: View {
    @ObservedObject var state: LightsOutV3GameState

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 10
            let n = CGFloat(LightsOutV3Grid.size)
            let totalSpacing = spacing * (n - 1)
            let cellSize = (min(geo.size.width, geo.size.height) - totalSpacing) / n

            VStack(spacing: spacing) {
                ForEach(0..<LightsOutV3Grid.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<LightsOutV3Grid.size, id: \.self) { col in
                            LightsOutV3CellView(
                                isOn: state.grid.cells[row][col],
                                onTap: { state.tap(row: row, col: col) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Win Overlay (V3)

struct LightsOutV3WinOverlay: View {
    let moves: Int
    let seedInt: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("All Lights Off!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)

                Text("Solved in \(moves) move\(moves == 1 ? "" : "s")")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: onRestart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Next Puzzle")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                    .shadow(color: Color.yellow.opacity(0.45), radius: 8)
                }
            }
            .padding(36)
            .neumorphicCard(radius: 24)
            .padding(32)
        }
    }
}

// MARK: - Main View (V3)

struct LightsOutViewV3: View {
    @StateObject private var state = LightsOutV3GameState()
    @State var seedInt: Int = 1

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header card
                VStack(spacing: 4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lights Out")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Turn all lights off")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(state.moves)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(state.moves == 0 ? .secondary : .primary)
                                .animation(.none, value: state.moves)
                            Text("moves")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Seed display — always visible
                    HStack {
                        Spacer()
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .neumorphicCard()
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer(minLength: 20)

                // Grid card
                LightsOutV3GridView(state: state)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(18)
                    .neumorphicCard()
                    .padding(.horizontal, 20)

                Spacer()

                // Restart button
                Button(action: restart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                        Text("New Puzzle")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 13)
                    .neumorphicCard(radius: 30)
                }
                .padding(.bottom, 36)
            }

            // Win overlay
            if state.isWon {
                LightsOutV3WinOverlay(
                    moves: state.moves,
                    seedInt: seedInt,
                    onRestart: restart
                )
                .transition(.opacity.combined(with: .scale(scale: 0.93)))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isWon)
            }
        }
        .onAppear {
            state.newPuzzle(seedInt: seedInt)
        }
    }

    private func restart() {
        seedInt += 1
        state.newPuzzle(seedInt: seedInt)
    }
}

// MARK: - Preview

#Preview {
    LightsOutViewV3()
}
