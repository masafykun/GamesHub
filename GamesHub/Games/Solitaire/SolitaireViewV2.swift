import SwiftUI

// MARK: - Models (V2, file-scoped)

private struct SolitaireV2Card: Identifiable, Equatable {
    let id = UUID()
    let suit: String
    let rank: String
    let rankValue: Int
    let isRed: Bool
    var isFaceUp: Bool
}

private enum SolitaireV2Source: Equatable {
    case tableau(Int)
    case waste
}

// MARK: - Game Engine

private class SolitaireV2Game: ObservableObject {
    @Published var tableau: [[SolitaireV2Card]] = Array(repeating: [], count: 7)
    @Published var foundations: [[SolitaireV2Card]] = Array(repeating: [], count: 4)
    @Published var stock: [SolitaireV2Card] = []
    @Published var waste: [SolitaireV2Card] = []
    @Published var selectedSource: SolitaireV2Source? = nil
    @Published var moves: Int = 0
    @Published var isWon: Bool = false

    let suits = ["♠️", "♥️", "♣️", "♦️"]
    let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

    func newGame() {
        var deck: [SolitaireV2Card] = []
        for (si, suit) in suits.enumerated() {
            let isRed = si == 1 || si == 3
            for (ri, rank) in ranks.enumerated() {
                deck.append(SolitaireV2Card(suit: suit, rank: rank, rankValue: ri + 1, isRed: isRed, isFaceUp: false))
            }
        }
        deck.shuffle()

        tableau = Array(repeating: [], count: 7)
        foundations = Array(repeating: [], count: 4)
        waste = []
        selectedSource = nil
        moves = 0
        isWon = false

        var idx = 0
        for col in 0..<7 {
            for row in 0...col {
                var card = deck[idx]
                if row == col { card.isFaceUp = true }
                tableau[col].append(card)
                idx += 1
            }
        }
        stock = Array(deck[idx...].map { var c = $0; c.isFaceUp = false; return c })
    }

    func tapStock() {
        selectedSource = nil
        if stock.isEmpty {
            stock = waste.reversed().map { var c = $0; c.isFaceUp = false; return c }
            waste = []
        } else {
            var card = stock.removeLast()
            card.isFaceUp = true
            waste.append(card)
        }
    }

    func tapWaste() {
        guard !waste.isEmpty else { return }
        if selectedSource == .waste {
            selectedSource = nil
        } else {
            selectedSource = .waste
        }
    }

    func tapTableau(col: Int) {
        guard !tableau[col].isEmpty else {
            if let src = selectedSource {
                tryMove(to: col, fromSource: src)
            }
            return
        }
        if let last = tableau[col].last, !last.isFaceUp {
            tableau[col][tableau[col].count - 1].isFaceUp = true
            moves += 1
            return
        }
        if let src = selectedSource {
            if src == .tableau(col) {
                selectedSource = nil
            } else {
                tryMove(to: col, fromSource: src)
            }
        } else {
            selectedSource = .tableau(col)
        }
    }

    func tapFoundation(foundIdx: Int) {
        guard let src = selectedSource else { return }
        let card: SolitaireV2Card?
        switch src {
        case .waste: card = waste.last
        case .tableau(let col): card = tableau[col].last
        }
        guard let c = card else { return }
        if canPlaceOnFoundation(card: c, foundIdx: foundIdx) {
            switch src {
            case .waste: waste.removeLast()
            case .tableau(let col):
                tableau[col].removeLast()
                flipTopTableau(col: col)
            }
            foundations[foundIdx].append(c)
            selectedSource = nil
            moves += 1
            checkWin()
            autoMoveAces()
        }
    }

    private func tryMove(to destCol: Int, fromSource src: SolitaireV2Source) {
        switch src {
        case .waste:
            guard let card = waste.last else { return }
            if canPlaceOnTableau(card: card, col: destCol) {
                waste.removeLast()
                tableau[destCol].append(card)
                selectedSource = nil
                moves += 1
                autoMoveAces()
            } else {
                selectedSource = .waste
            }
        case .tableau(let srcCol):
            guard srcCol != destCol else { selectedSource = nil; return }
            let faceUpStart = tableau[srcCol].firstIndex(where: { $0.isFaceUp }) ?? (tableau[srcCol].count - 1)
            let stack = Array(tableau[srcCol][faceUpStart...])
            if let topCard = stack.first, canPlaceOnTableau(card: topCard, col: destCol) {
                tableau[srcCol].removeSubrange(faceUpStart...)
                tableau[destCol].append(contentsOf: stack)
                flipTopTableau(col: srcCol)
                selectedSource = nil
                moves += 1
                autoMoveAces()
            } else {
                selectedSource = .tableau(destCol)
            }
        }
    }

    private func canPlaceOnTableau(card: SolitaireV2Card, col: Int) -> Bool {
        if tableau[col].isEmpty { return card.rankValue == 13 }
        guard let top = tableau[col].last, top.isFaceUp else { return false }
        return top.rankValue == card.rankValue + 1 && top.isRed != card.isRed
    }

    private func canPlaceOnFoundation(card: SolitaireV2Card, foundIdx: Int) -> Bool {
        let pile = foundations[foundIdx]
        if pile.isEmpty { return card.rankValue == 1 }
        guard let top = pile.last else { return false }
        return top.suit == card.suit && top.rankValue == card.rankValue - 1
    }

    private func flipTopTableau(col: Int) {
        guard !tableau[col].isEmpty else { return }
        let last = tableau[col].count - 1
        if !tableau[col][last].isFaceUp { tableau[col][last].isFaceUp = true }
    }

    private func autoMoveAces() {
        var moved = true
        while moved {
            moved = false
            for col in 0..<7 {
                if let top = tableau[col].last, top.isFaceUp, top.rankValue == 1 {
                    if let fi = emptyOrMatchingFoundation(for: top) {
                        tableau[col].removeLast()
                        foundations[fi].append(top)
                        flipTopTableau(col: col)
                        moves += 1
                        moved = true
                    }
                }
            }
            if let top = waste.last, top.rankValue == 1 {
                if let fi = emptyOrMatchingFoundation(for: top) {
                    waste.removeLast()
                    foundations[fi].append(top)
                    moves += 1
                    moved = true
                }
            }
        }
        checkWin()
    }

    private func emptyOrMatchingFoundation(for card: SolitaireV2Card) -> Int? {
        for (i, pile) in foundations.enumerated() {
            if pile.isEmpty && card.rankValue == 1 { return i }
            if let top = pile.last, top.suit == card.suit && top.rankValue == card.rankValue - 1 { return i }
        }
        return nil
    }

    private func checkWin() {
        isWon = foundations.allSatisfy { $0.count == 13 }
    }
}

// MARK: - Card Views (Glassmorphism)

private struct SolitaireV2CardView: View {
    let card: SolitaireV2Card
    let isSelected: Bool

    private var glowColor: Color {
        isSelected ? .cyan : (card.isRed ? .pink : .blue)
    }

    var body: some View {
        ZStack {
            if card.isFaceUp {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .shadow(color: glowColor.opacity(isSelected ? 0.7 : 0.3), radius: isSelected ? 14 : 6)

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(card.isRed ? Color(red: 1, green: 0.35, blue: 0.45) : .white)
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(card.suit)
                        .font(.system(size: 26))
                        .shadow(color: glowColor.opacity(0.6), radius: 8)
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.suit)
                                .font(.system(size: 11))
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(card.isRed ? Color(red: 1, green: 0.35, blue: 0.45) : .white)
                        }
                        .rotationEffect(.degrees(180))
                    }
                }
                .padding(5)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.1, green: 0.15, blue: 0.4),
                                Color(red: 0.2, green: 0.1, blue: 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6 - CGFloat(i))
                            .stroke(Color.white.opacity(0.05 + Double(i) * 0.03), lineWidth: 1)
                            .padding(CGFloat(i * 5 + 4))
                    }
                }
                Text("✦")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: 60, height: 90)
    }
}

private struct SolitaireV2EmptySlot: View {
    var label: String = ""
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 22))
                    .opacity(0.3)
            }
        }
        .frame(width: 60, height: 90)
    }
}

// MARK: - Main View V2

struct SolitaireViewV2: View {
    @StateObject private var game = SolitaireV2Game()

    private let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.18),
            Color(red: 0.1, green: 0.05, blue: 0.25),
            Color(red: 0.05, green: 0.08, blue: 0.2)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            // Ambient glow blobs
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 100, y: 100)

            VStack(spacing: 0) {
                // Header glass pill
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SOLITAIRE")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(3)
                        Text("Moves: \(game.moves)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Button(action: { game.newGame() }) {
                        Text("New Game")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.white.opacity(0.1)),
                            alignment: .bottom
                        )
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        topRow
                        tableauRow
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)
                }
            }

            if game.isWon {
                winOverlay
            }
        }
        .onAppear { game.newGame() }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Button(action: { game.tapStock() }) {
                if game.stock.isEmpty {
                    ZStack {
                        SolitaireV2EmptySlot()
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 20))
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.15, blue: 0.4), Color(red: 0.2, green: 0.1, blue: 0.35)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: .blue.opacity(0.4), radius: 10)
                        Text("🂠")
                            .font(.system(size: 38))
                    }
                    .frame(width: 60, height: 90)
                }
            }

            Button(action: { game.tapWaste() }) {
                if let top = game.waste.last {
                    SolitaireV2CardView(card: top, isSelected: game.selectedSource == .waste)
                } else {
                    SolitaireV2EmptySlot()
                }
            }

            Spacer()

            ForEach(0..<4, id: \.self) { fi in
                Button(action: { game.tapFoundation(foundIdx: fi) }) {
                    if let top = game.foundations[fi].last {
                        SolitaireV2CardView(card: top, isSelected: false)
                    } else {
                        SolitaireV2EmptySlot(label: ["♠️","♥️","♣️","♦️"][fi])
                    }
                }
            }
        }
    }

    private var tableauRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<7, id: \.self) { col in
                tableauColumn(col: col)
            }
        }
    }

    private func tableauColumn(col: Int) -> some View {
        ZStack(alignment: .top) {
            Button(action: { game.tapTableau(col: col) }) {
                SolitaireV2EmptySlot()
            }
            if !game.tableau[col].isEmpty {
                ZStack(alignment: .top) {
                    ForEach(Array(game.tableau[col].enumerated()), id: \.element.id) { idx, card in
                        Button(action: { game.tapTableau(col: col) }) {
                            SolitaireV2CardView(
                                card: card,
                                isSelected: isCardSelected(card: card, col: col, idx: idx)
                            )
                        }
                        .offset(y: CGFloat(idx) * 28)
                    }
                }
            }
        }
        .frame(width: 60, height: max(90, 90 + CGFloat(max(0, game.tableau[col].count - 1)) * 28))
    }

    private func isCardSelected(card: SolitaireV2Card, col: Int, idx: Int) -> Bool {
        guard case .tableau(let sc) = game.selectedSource, sc == col else { return false }
        guard let faceUpStart = game.tableau[col].firstIndex(where: { $0.isFaceUp }) else { return false }
        return idx >= faceUpStart
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("YOU WIN! 🎉")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(0.8), radius: 20)
                Text("Completed in \(game.moves) moves")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Button(action: { game.newGame() }) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: .cyan.opacity(0.6), radius: 16)
                        )
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 30)
            )
            .padding(.horizontal, 30)
        }
    }
}
