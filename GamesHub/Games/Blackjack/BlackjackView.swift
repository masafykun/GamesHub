import SwiftUI

// MARK: - Models (, file-scoped)

private struct BlackjackCard: Identifiable {
    let id = UUID()
    let suit: String
    let rank: String
    let value: Int
    var isFaceDown: Bool

    static func deck() -> [BlackjackCard] {
        let suits = ["♠︎", "♥︎", "♦︎", "♣︎"]
        let ranks: [(String, Int)] = [
            ("A", 11), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9), ("10", 10),
            ("J", 10), ("Q", 10), ("K", 10)
        ]
        var cards: [BlackjackCard] = []
        for suit in suits {
            for (rank, value) in ranks {
                cards.append(BlackjackCard(suit: suit, rank: rank, value: value, isFaceDown: false))
            }
        }
        return cards.shuffled()
    }
}

private enum BlackjackPhase {
    case betting, playing, dealerTurn, result
}

private enum BlackjackResult {
    case playerWin, dealerWin, push, blackjack, playerBust, dealerBust
}

// MARK: - ViewModel

private class BlackjackViewModel: ObservableObject {
    @Published var playerHand: [BlackjackCard] = []
    @Published var dealerHand: [BlackjackCard] = []
    @Published var chips: Int = 1000
    @Published var bet: Int = 100
    @Published var phase: BlackjackPhase = .betting
    @Published var result: BlackjackResult? = nil

    private var deck: [BlackjackCard] = []

    var playerTotal: Int { calculateTotal(hand: playerHand) }
    var dealerTotal: Int { calculateTotal(hand: dealerHand) }
    var dealerVisibleTotal: Int {
        calculateTotal(hand: dealerHand.filter { !$0.isFaceDown })
    }

    func calculateTotal(hand: [BlackjackCard]) -> Int {
        var total = 0
        var aces = 0
        for card in hand where !card.isFaceDown {
            total += card.value
            if card.rank == "A" { aces += 1 }
        }
        while total > 21 && aces > 0 {
            total -= 10
            aces -= 1
        }
        return total
    }

    func deal() {
        guard bet >= 50, bet <= chips else { return }
        deck = BlackjackCard.deck()
        playerHand = []
        dealerHand = []
        result = nil

        playerHand.append(draw())
        dealerHand.append(draw())
        playerHand.append(draw())
        var second = draw()
        second.isFaceDown = true
        dealerHand.append(second)
        chips -= bet
        phase = .playing

        if playerTotal == 21 { stand() }
    }

    func hit() {
        guard phase == .playing else { return }
        playerHand.append(draw())
        if playerTotal > 21 { revealAndFinish() }
    }

    func stand() {
        guard phase == .playing || playerTotal == 21 else { return }
        phase = .dealerTurn
        revealAndFinish()
    }

    private func revealAndFinish() {
        for i in dealerHand.indices { dealerHand[i].isFaceDown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.dealerDrawLoop() }
    }

    private func dealerDrawLoop() {
        if dealerTotal < 17 {
            dealerHand.append(draw())
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.dealerDrawLoop() }
        } else {
            determineResult()
        }
    }

    private func determineResult() {
        let pt = playerTotal, dt = dealerTotal
        if pt > 21 {
            result = .playerBust
        } else if dt > 21 {
            result = .dealerBust; chips += bet * 2
        } else if pt == 21 && playerHand.count == 2 && !(dt == 21 && dealerHand.count == 2) {
            result = .blackjack; chips += Int(Double(bet) * 2.5)
        } else if pt > dt {
            result = .playerWin; chips += bet * 2
        } else if dt > pt {
            result = .dealerWin
        } else {
            result = .push; chips += bet
        }
        phase = .result
    }

    private func draw() -> BlackjackCard {
        if deck.isEmpty { deck = BlackjackCard.deck() }
        return deck.removeFirst()
    }

    func adjustBet(_ amount: Int) {
        let newBet = bet + amount
        if newBet >= 50 && newBet <= chips { bet = newBet }
    }

    func dealAgain() {
        if chips < 50 { chips = 1000; bet = 100 }
        phase = .betting; result = nil
    }
}

// MARK: - Glassmorphic Card View

private struct GlassCardView: View {
    let card: BlackjackCard
    var isRed: Bool { card.suit == "♥︎" || card.suit == "♦︎" }

    var body: some View {
        ZStack {
            if card.isFaceDown {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 20))
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                VStack(spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 14, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isRed ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                    .padding(.top, 5)

                    Spacer()

                    Text(card.suit)
                        .font(.system(size: 24))
                        .foregroundColor(isRed ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                        .shadow(color: isRed ? .red.opacity(0.6) : .cyan.opacity(0.6), radius: 6)

                    Spacer()

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 14, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isRed ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                        .rotationEffect(.degrees(180))
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 5)
                }
            }
        }
        .frame(width: 62, height: 90)
        .shadow(color: isRed ? Color.red.opacity(0.3) : Color.cyan.opacity(0.3), radius: 10)
    }
}

// MARK: - Glass Container

private struct GlassContainer<Content: View>: View {
    let content: Content
    var accentColor: Color = .blue

    init(accentColor: Color = .blue, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(0.3), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Glow Button

private struct GlowButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.bold())
                .foregroundColor(disabled ? .gray : .white)
                .frame(minWidth: 100, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(disabled ? Color.gray.opacity(0.3) : color.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(disabled ? Color.clear : color.opacity(0.8), lineWidth: 1)
                        )
                )
                .shadow(color: disabled ? .clear : color.opacity(0.5), radius: 12, x: 0, y: 4)
        }
        .disabled(disabled)
    }
}

// MARK: - Main  View

struct BlackjackView: View {
    @StateObject private var vm = BlackjackViewModel()

    private let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.2),
            Color(red: 0.1, green: 0.0, blue: 0.25),
            Color(red: 0.05, green: 0.1, blue: 0.3)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var resultMessage: String {
        switch vm.result {
        case .playerWin:   return "You Win!"
        case .dealerWin:   return "Dealer Wins"
        case .push:        return "Push — Tie!"
        case .blackjack:   return "Blackjack! 1.5x"
        case .playerBust:  return "Bust! You Lose"
        case .dealerBust:  return "Dealer Busts!"
        case .none:        return ""
        }
    }

    var resultGlow: Color {
        switch vm.result {
        case .playerWin, .dealerBust, .blackjack: return .green
        case .dealerWin, .playerBust:             return .red
        case .push:                               return .orange
        case .none:                               return .blue
        }
    }

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 300)

            VStack(spacing: 16) {
                // Chip bar
                GlassContainer(accentColor: .yellow) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.6), radius: 8)
                        Text("Chips: \(vm.chips)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Spacer()
                        if vm.phase != .betting {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                    .foregroundColor(.cyan)
                                Text("Bet: \(vm.bet)")
                                    .foregroundColor(.cyan)
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Dealer area
                GlassContainer(accentColor: .purple) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DEALER")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)
                            if !vm.dealerHand.isEmpty {
                                Text(vm.phase == .playing ? "?" : "\(vm.dealerTotal)")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.purple.opacity(0.3)))
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -10) {
                                ForEach(vm.dealerHand) { card in
                                    GlassCardView(card: card)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Player area
                GlassContainer(accentColor: .cyan) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("YOU")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)
                            if !vm.playerHand.isEmpty {
                                Text("\(vm.playerTotal)")
                                    .font(.caption.bold())
                                    .foregroundColor(vm.playerTotal > 21 ? .red : .cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill((vm.playerTotal > 21 ? Color.red : Color.cyan).opacity(0.3))
                                    )
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -10) {
                                ForEach(vm.playerHand) { card in
                                    GlassCardView(card: card)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal)

                // Controls
                Group {
                    if vm.phase == .betting {
                        bettingControls
                    } else if vm.phase == .playing {
                        playingControls
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top)
            .animation(.easeInOut(duration: 0.35), value: vm.playerHand.count)
            .animation(.easeInOut(duration: 0.35), value: vm.dealerHand.count)

            // Result overlay
            if vm.phase == .result, let _ = vm.result {
                resultOverlay
            }
        }
    }

    private var bettingControls: some View {
        GlassContainer(accentColor: .cyan) {
            VStack(spacing: 14) {
                Text("PLACE YOUR BET")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)

                HStack(spacing: 16) {
                    GlowButton(title: "-50", color: .red, action: { vm.adjustBet(-50) },
                               disabled: vm.bet <= 50)

                    Text("\(vm.bet)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .frame(minWidth: 80)
                        .shadow(color: .cyan.opacity(0.6), radius: 8)

                    GlowButton(title: "+50", color: .green, action: { vm.adjustBet(50) },
                               disabled: vm.bet + 50 > vm.chips)
                }

                GlowButton(title: "DEAL", color: .cyan, action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { vm.deal() }
                }, disabled: vm.bet > vm.chips || vm.chips < 50)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var playingControls: some View {
        GlassContainer(accentColor: .blue) {
            HStack(spacing: 16) {
                GlowButton(title: "HIT", color: .green, action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.hit() }
                })
                GlowButton(title: "STAND", color: .red, action: {
                    withAnimation(.easeInOut) { vm.stand() }
                })
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 20) {
                Text(resultMessage)
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .shadow(color: resultGlow.opacity(0.8), radius: 20)

                VStack(spacing: 6) {
                    HStack {
                        Text("Your total:")
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(vm.playerTotal)")
                            .foregroundColor(.cyan)
                            .bold()
                    }
                    HStack {
                        Text("Dealer total:")
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(vm.dealerTotal)")
                            .foregroundColor(.purple)
                            .bold()
                    }
                }
                .font(.subheadline)

                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Chips: \(vm.chips)")
                        .font(.headline.bold())
                        .foregroundColor(.yellow)
                }
                .shadow(color: .yellow.opacity(0.5), radius: 10)

                GlowButton(title: "DEAL AGAIN", color: resultGlow) {
                    withAnimation(.spring(response: 0.4)) { vm.dealAgain() }
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(resultGlow.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: resultGlow.opacity(0.4), radius: 30, x: 0, y: 10)
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
