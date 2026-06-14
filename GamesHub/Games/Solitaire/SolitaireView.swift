import SwiftUI

// MARK: - Models (file-scoped, private)

private struct SolitaireCard: Identifiable, Equatable {
    let id = UUID()
    let suit: String
    let rank: String
    let rankValue: Int
    let isRed: Bool
    var isFaceUp: Bool
}

private enum SolitaireSource: Equatable {
    case tableau(Int)
    case waste
}

// MARK: - Game Engine

private class SolitaireGame: ObservableObject {
    @Published var tableau: [[SolitaireCard]] = Array(repeating: [], count: 7)
    @Published var foundations: [[SolitaireCard]] = Array(repeating: [], count: 4)
    @Published var stock: [SolitaireCard] = []
    @Published var waste: [SolitaireCard] = []
    @Published var selectedSource: SolitaireSource? = nil
    @Published var moves: Int = 0
    @Published var isWon: Bool = false

    let suits = ["♠️", "♥️", "♣️", "♦️"]
    let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

    func newGame() {
        var deck: [SolitaireCard] = []
        for (si, suit) in suits.enumerated() {
            let isRed = si == 1 || si == 3
            for (ri, rank) in ranks.enumerated() {
                deck.append(SolitaireCard(suit: suit, rank: rank, rankValue: ri + 1, isRed: isRed, isFaceUp: false))
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
            // Try to place selected card here
            if let src = selectedSource {
                tryMove(to: col, fromSource: src)
            }
            return
        }

        // If tapping face-down top card, flip it
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
        let card: SolitaireCard?
        switch src {
        case .waste:
            card = waste.last
        case .tableau(let col):
            card = tableau[col].last
        }
        guard let c = card else { return }

        if canPlaceOnFoundation(card: c, foundIdx: foundIdx) {
            switch src {
            case .waste:
                waste.removeLast()
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

    private func tryMove(to destCol: Int, fromSource src: SolitaireSource) {
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
            // Find the first face-up card in srcCol to move as a stack
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

    private func canPlaceOnTableau(card: SolitaireCard, col: Int) -> Bool {
        if tableau[col].isEmpty {
            return card.rankValue == 13 // King
        }
        guard let top = tableau[col].last, top.isFaceUp else { return false }
        return top.rankValue == card.rankValue + 1 && top.isRed != card.isRed
    }

    private func canPlaceOnFoundation(card: SolitaireCard, foundIdx: Int) -> Bool {
        let pile = foundations[foundIdx]
        if pile.isEmpty {
            return card.rankValue == 1
        }
        guard let top = pile.last else { return false }
        return top.suit == card.suit && top.rankValue == card.rankValue - 1
    }

    private func flipTopTableau(col: Int) {
        guard !tableau[col].isEmpty else { return }
        let last = tableau[col].count - 1
        if !tableau[col][last].isFaceUp {
            tableau[col][last].isFaceUp = true
        }
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

    private func emptyOrMatchingFoundation(for card: SolitaireCard) -> Int? {
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

// MARK: - Card Views

private struct SolitaireCardView: View {
    let card: SolitaireCard
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: isSelected ? 2.5 : 1)
                )
            if card.isFaceUp {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(card.suit)
                        .font(.system(size: 24))
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.suit)
                                .font(.system(size: 11))
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .rotationEffect(.degrees(180))
                    }
                }
                .padding(4)
                .foregroundColor(card.isRed ? .red : .black)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(3)
            }
        }
        .frame(width: 60, height: 90)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 2)
    }
}

private struct EmptySlotView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            .frame(width: 60, height: 90)
    }
}

// MARK: - Main View

struct SolitaireView: View {
    @StateObject private var game = SolitaireGame()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Solitaire")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Moves: \(game.moves)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("New") { game.newGame() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        // Top row: stock, waste, foundations
                        topRow

                        // Tableau
                        tableauRow
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)
                }
            }

            // Win overlay
            if game.isWon {
                winOverlay
            }
        }
        .onAppear { game.newGame() }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            // Stock
            Button(action: { game.tapStock() }) {
                if game.stock.isEmpty {
                    ZStack {
                        EmptySlotView()
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [.blue.opacity(0.8), .indigo.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("🂠")
                            .font(.system(size: 36))
                    }
                    .frame(width: 60, height: 90)
                    .shadow(radius: 3)
                }
            }

            // Waste
            Button(action: { game.tapWaste() }) {
                if let top = game.waste.last {
                    SolitaireCardView(card: top, isSelected: game.selectedSource == .waste)
                } else {
                    EmptySlotView()
                }
            }

            Spacer()

            // Foundations
            ForEach(0..<4, id: \.self) { fi in
                Button(action: { game.tapFoundation(foundIdx: fi) }) {
                    if let top = game.foundations[fi].last {
                        SolitaireCardView(card: top, isSelected: false)
                    } else {
                        ZStack {
                            EmptySlotView()
                            Text(["♠️","♥️","♣️","♦️"][fi])
                                .font(.system(size: 24))
                                .opacity(0.4)
                        }
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
            // Tap target for empty column
            Button(action: { game.tapTableau(col: col) }) {
                EmptySlotView()
            }

            if !game.tableau[col].isEmpty {
                ZStack(alignment: .top) {
                    ForEach(Array(game.tableau[col].enumerated()), id: \.element.id) { idx, card in
                        Button(action: {
                            // Tapping any face-up card in the column selects the column
                            // Tapping face-down just flips top
                            game.tapTableau(col: col)
                        }) {
                            SolitaireCardView(
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

    private func isCardSelected(card: SolitaireCard, col: Int, idx: Int) -> Bool {
        guard case .tableau(let sc) = game.selectedSource, sc == col else { return false }
        guard let faceUpStart = game.tableau[col].firstIndex(where: { $0.isFaceUp }) else { return false }
        return idx >= faceUpStart
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("YOU WIN! 🎉")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Completed in \(game.moves) moves")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                Button("Play Again") { game.newGame() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemIndigo))
                    .shadow(radius: 20)
            )
        }
    }
}
