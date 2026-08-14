import SwiftUI

struct GameEntry: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let make: () -> AnyView
}

// MARK: - Game Registry

let allGames: [GameEntry] = [
    // 1-10: Original Games
    GameEntry(name: "Flappy Bird",    icon: "bird.fill",              color: .cyan,
              make: { AnyView(FlappyView()) }),
    GameEntry(name: "2048",           icon: "square.grid.2x2.fill",   color: .orange,
              make: { AnyView(Puzzle2048View()) }),
    GameEntry(name: "Wordle",         icon: "textformat.abc",          color: .green,
              make: { AnyView(WordleView()) }),
    GameEntry(name: "Runner",         icon: "figure.run",              color: .purple,
              make: { AnyView(RunnerView()) }),
    GameEntry(name: "Match 3",        icon: "star.fill",               color: .yellow,
              make: { AnyView(Match3View()) }),
    GameEntry(name: "Tower Defense",  icon: "shield.fill",             color: .red,
              make: { AnyView(DefenseView()) }),
    GameEntry(name: "Stacker",        icon: "square.stack.fill",       color: .indigo,
              make: { AnyView(StackerView()) }),
    GameEntry(name: "Jumper",         icon: "arrow.up.circle.fill",    color: .teal,
              make: { AnyView(JumperView()) }),
    GameEntry(name: "Dodge",          icon: "bolt.circle.fill",        color: .pink,
              make: { AnyView(DodgeView()) }),
    GameEntry(name: "Memory",         icon: "brain.fill",              color: .mint,
              make: { AnyView(MemoryView()) }),
    // 11-20
    GameEntry(name: "Snake",          icon: "point.3.connected.trianglepath.dotted", color: .green,
              make: { AnyView(SnakeView()) }),
    GameEntry(name: "Breakout",       icon: "rectangle.split.3x1.fill",color: .blue,
              make: { AnyView(BreakoutView()) }),
    GameEntry(name: "Tetris Lite",    icon: "square.grid.3x3.fill",    color: .purple,
              make: { AnyView(TetrisView()) }),
    GameEntry(name: "Space Shooter",  icon: "airplane",                color: .cyan,
              make: { AnyView(SpaceShooterView()) }),
    GameEntry(name: "Minesweeper",    icon: "exclamationmark.octagon.fill", color: .red,
              make: { AnyView(MinesweeperView()) }),
    GameEntry(name: "Sudoku",         icon: "grid",                    color: .orange,
              make: { AnyView(SudokuView()) }),
    GameEntry(name: "Simon Says",     icon: "circle.grid.2x2.fill",   color: .yellow,
              make: { AnyView(SimonView()) }),
    GameEntry(name: "Whack-a-Mole",   icon: "hand.tap.fill",          color: .brown,
              make: { AnyView(WhackView()) }),
    GameEntry(name: "Bubble Shooter", icon: "circle.fill",             color: .teal,
              make: { AnyView(BubbleShooterView()) }),
    GameEntry(name: "Sliding Puzzle", icon: "rectangle.3.group.fill",  color: .indigo,
              make: { AnyView(SlidingPuzzleView()) }),
    // 21-30
    GameEntry(name: "Connect Four",   icon: "circle.grid.3x3.fill",   color: .red,
              make: { AnyView(ConnectFourView()) }),
    GameEntry(name: "Tic-Tac-Toe",    icon: "xmark.square.fill",      color: .blue,
              make: { AnyView(TicTacToeView()) }),
    GameEntry(name: "Trivia",         icon: "questionmark.circle.fill",color: .purple,
              make: { AnyView(TriviaView()) }),
    GameEntry(name: "Color Match",    icon: "paintpalette.fill",       color: .pink,
              make: { AnyView(ColorMatchView()) }),
    GameEntry(name: "Reaction Timer", icon: "timer",                   color: .orange,
              make: { AnyView(ReactionView()) }),
    GameEntry(name: "Hangman",        icon: "person.fill.questionmark",color: .gray,
              make: { AnyView(HangmanView()) }),
    GameEntry(name: "Word Search",    icon: "magnifyingglass",         color: .teal,
              make: { AnyView(WordSearchView()) }),
    GameEntry(name: "Anagram",        icon: "textformat",              color: .green,
              make: { AnyView(AnagramView()) }),
    GameEntry(name: "Lights Out",     icon: "lightbulb.fill",          color: .yellow,
              make: { AnyView(LightsOutView()) }),
    GameEntry(name: "Pipe Connect",   icon: "arrow.triangle.turn.up.right.diamond.fill", color: .blue,
              make: { AnyView(PipeConnectView()) }),
    // 31-40
    GameEntry(name: "Color Flood",    icon: "drop.fill",               color: .cyan,
              make: { AnyView(ColorFloodView()) }),
    GameEntry(name: "Code Breaker",   icon: "lock.fill",               color: .indigo,
              make: { AnyView(CodeBreakerView()) }),
    GameEntry(name: "Asteroid Dodge", icon: "sparkles",                color: .mint,
              make: { AnyView(AsteroidView()) }),
    GameEntry(name: "Gem Catcher",    icon: "diamond.fill",            color: .pink,
              make: { AnyView(GemCatcherView()) }),
    GameEntry(name: "Gravity Switch", icon: "arrow.up.arrow.down",     color: .purple,
              make: { AnyView(GravitySwitchView()) }),
    GameEntry(name: "Number Flow",    icon: "number",                  color: .orange,
              make: { AnyView(NumberFlowView()) }),
    GameEntry(name: "Binary Game",    icon: "01.circle.fill",          color: .green,
              make: { AnyView(BinaryGameView()) }),
    GameEntry(name: "High Low",       icon: "arrow.up.arrow.down.circle.fill", color: .red,
              make: { AnyView(HighLowView()) }),
    GameEntry(name: "Fruit Slice",    icon: "scissors",                color: .red,
              make: { AnyView(FruitSliceView()) }),
    GameEntry(name: "Math Blitz",     icon: "plus.forwardslash.minus", color: .blue,
              make: { AnyView(MathBlitzView()) }),
    // 41-50
    GameEntry(name: "Flick Hoops",    icon: "basketball.fill",         color: .orange,
              make: { AnyView(FlickHoopsView()) }),
    GameEntry(name: "Darts",          icon: "target",                  color: .red,
              make: { AnyView(DartsView()) }),
    GameEntry(name: "Golf Putt",      icon: "figure.golf",             color: .green,
              make: { AnyView(GolfPuttView()) }),
    GameEntry(name: "Archery",        icon: "arrow.right.circle.fill", color: .brown,
              make: { AnyView(ArcheryView()) }),
    GameEntry(name: "Bowling",        icon: "figure.bowling",          color: .purple,
              make: { AnyView(BowlingView()) }),
    GameEntry(name: "Bubble Pop",     icon: "bubbles.and.sparkles.fill",color: .teal,
              make: { AnyView(BubblePopView()) }),
    GameEntry(name: "Rhythm Tap",     icon: "music.note",              color: .pink,
              make: { AnyView(RhythmTapView()) }),
    GameEntry(name: "Type Race",      icon: "keyboard.fill",           color: .indigo,
              make: { AnyView(TypeRaceView()) }),
    GameEntry(name: "Color Sort",     icon: "swatchpalette.fill",      color: .cyan,
              make: { AnyView(ColorSortView()) }),
    GameEntry(name: "Maze Runner",    icon: "map.fill",                color: .mint,
              make: { AnyView(MazeView()) }),
    // 51-60
    GameEntry(name: "Laser Mirror",   icon: "rays",                    color: .yellow,
              make: { AnyView(LaserMirrorView()) }),
    GameEntry(name: "Traffic Control",icon: "car.fill",                color: .red,
              make: { AnyView(TrafficView()) }),
    GameEntry(name: "Parking Puzzle", icon: "parkingsign.circle.fill", color: .blue,
              make: { AnyView(ParkingView()) }),
    GameEntry(name: "Orbit Game",     icon: "globe",                   color: .purple,
              make: { AnyView(OrbitView()) }),
    GameEntry(name: "Spin Target",    icon: "scope",                   color: .orange,
              make: { AnyView(SpinTargetView()) }),
    GameEntry(name: "Air Hockey",     icon: "circle.hexagongrid.fill", color: .cyan,
              make: { AnyView(AirHockeyView()) }),
    GameEntry(name: "Pinball",        icon: "circle.fill",             color: .indigo,
              make: { AnyView(PinballView()) }),
    GameEntry(name: "Sokoban",        icon: "shippingbox.fill",        color: .brown,
              make: { AnyView(SokobanView()) }),
    GameEntry(name: "Nonogram",       icon: "squareshape.split.2x2",   color: .teal,
              make: { AnyView(NonogramView()) }),
    GameEntry(name: "Sand Fall",      icon: "waveform",                color: .yellow,
              make: { AnyView(SandFallView()) }),
    // 61-70
    GameEntry(name: "Rope Cut",       icon: "scissors.circle.fill",    color: .green,
              make: { AnyView(RopeCutView()) }),
    GameEntry(name: "Water Flow",     icon: "drop.circle.fill",        color: .blue,
              make: { AnyView(WaterFlowView()) }),
    GameEntry(name: "Balance Ball",   icon: "level.fill",              color: .mint,
              make: { AnyView(BalanceBallView()) }),
    GameEntry(name: "Tower Climb",    icon: "arrow.up.to.line",        color: .purple,
              make: { AnyView(TowerClimbView()) }),
    GameEntry(name: "Emoji Match",    icon: "face.smiling.fill",       color: .yellow,
              make: { AnyView(EmojiMatchView()) }),
    GameEntry(name: "Shadow Match",   icon: "circle.lefthalf.filled",  color: .gray,
              make: { AnyView(ShadowMatchView()) }),
    GameEntry(name: "Catch Fish",     icon: "fish.fill",               color: .teal,
              make: { AnyView(CatchFishView()) }),
    GameEntry(name: "Stack Sort",     icon: "list.number",             color: .indigo,
              make: { AnyView(StackSortView()) }),
    GameEntry(name: "Letter Chain",   icon: "link",                    color: .orange,
              make: { AnyView(LetterChainView()) }),
    GameEntry(name: "Escape Code",    icon: "key.fill",                color: .red,
              make: { AnyView(EscapeCodeView()) }),
    // 71-80
    GameEntry(name: "Number Merge",   icon: "plus.circle.fill",        color: .blue,
              make: { AnyView(NumberMergeView()) }),
    GameEntry(name: "Circuit Board",  icon: "cpu.fill",                color: .green,
              make: { AnyView(CircuitView()) }),
    GameEntry(name: "Dungeon Crawl",  icon: "sword.fill",              color: .brown,
              make: { AnyView(DungeonView()) }),
    GameEntry(name: "Beat the Clock", icon: "alarm.fill",              color: .red,
              make: { AnyView(BeatClockView()) }),
    GameEntry(name: "Spot Diff",      icon: "eye.fill",                color: .teal,
              make: { AnyView(SpotDiffView()) }),
    GameEntry(name: "Crossy Hop",     icon: "hare.fill",               color: .green,
              make: { AnyView(CrossyHopView()) }),
    GameEntry(name: "Magnet Ball",    icon: "magnet.fill",             color: .purple,
              make: { AnyView(MagnetBallView()) }),
    GameEntry(name: "Brick Blast",    icon: "square.fill",             color: .orange,
              make: { AnyView(BrickBlastView()) }),
    GameEntry(name: "Zen Painter",    icon: "paintbrush.fill",         color: .mint,
              make: { AnyView(ZenPainterView()) }),
    GameEntry(name: "Gravity Puzzle", icon: "arrow.down.circle.fill",  color: .cyan,
              make: { AnyView(GravityPuzzleView()) }),
    // 81-90
    GameEntry(name: "Word Chain",     icon: "arrow.right.doc.on.clipboard", color: .blue,
              make: { AnyView(WordChainView()) }),
    GameEntry(name: "Memory Seq",     icon: "list.number.rtl",         color: .indigo,
              make: { AnyView(MemorySeqView()) }),
    GameEntry(name: "Prime Finder",   icon: "number.circle.fill",      color: .orange,
              make: { AnyView(PrimeFinderView()) }),
    GameEntry(name: "Color Wave",     icon: "waveform.path",           color: .pink,
              make: { AnyView(ColorWaveView()) }),
    GameEntry(name: "Flip Cards",     icon: "rectangle.on.rectangle.fill", color: .red,
              make: { AnyView(FlipCardsView()) }),
    GameEntry(name: "Pic Cross",      icon: "squareshape.dotted.squareshape", color: .teal,
              make: { AnyView(PicCrossView()) }),
    GameEntry(name: "Path Finder",    icon: "point.3.filled.connected.trianglepath.dotted", color: .mint,
              make: { AnyView(PathFinderView()) }),
    GameEntry(name: "Infinity Hop",   icon: "infinity.circle.fill",    color: .purple,
              make: { AnyView(InfinityHopView()) }),
    GameEntry(name: "Block Push",     icon: "arrow.forward.square.fill",color: .brown,
              make: { AnyView(BlockPushView()) }),
    GameEntry(name: "Final Gauntlet", icon: "flag.checkered.2.crossed", color: .red,
              make: { AnyView(FinalGauntletView()) }),
    // 91-100: New Games
    GameEntry(name: "Pong",           icon: "dot.circle.fill",             color: .blue,
              make: { AnyView(PongView()) }),
    GameEntry(name: "Chain Reaction", icon: "burst.fill",                  color: .orange,
              make: { AnyView(ChainReactionView()) }),
    GameEntry(name: "Solitaire",      icon: "suit.spade.fill",             color: .green,
              make: { AnyView(SolitaireView()) }),
    GameEntry(name: "Blackjack",      icon: "suit.heart.fill",             color: .red,
              make: { AnyView(BlackjackView()) }),
    GameEntry(name: "Checkers",       icon: "checkerboard.rectangle",      color: .brown,
              make: { AnyView(CheckersView()) }),
    GameEntry(name: "Tower of Hanoi", icon: "pyramid.fill",                color: .purple,
              make: { AnyView(TowerHanoiView()) }),
    GameEntry(name: "Farkle",         icon: "die.face.5.fill",             color: .yellow,
              make: { AnyView(FarkleView()) }),
    GameEntry(name: "Crossword",      icon: "squareshape.split.3x3",       color: .indigo,
              make: { AnyView(CrosswordView()) }),
    GameEntry(name: "Flag Quiz",      icon: "flag.fill",                   color: .red,
              make: { AnyView(FlagQuizView()) }),
    GameEntry(name: "Pixel Art",      icon: "square.grid.3x3.fill",        color: .pink,
              make: { AnyView(PixelArtView()) }),
]

// MARK: - Content View

struct ContentView: View {
    @State private var searchText = ""
    @State private var randomDest: GameEntry? = nil

    static let featured: [GameEntry] = [
        allGames[0],  // Flappy Bird
        allGames[12], // Tetris
        allGames[2],  // Wordle
        allGames[13], // Space Shooter
        allGames[1],  // 2048
        allGames[18], // Bubble Shooter
        allGames[22], // Trivia
        allGames[32], // Asteroid Dodge
    ]

    var filtered: [GameEntry] {
        searchText.isEmpty
            ? allGames
            : allGames.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if searchText.isEmpty {
                        heroSection
                        statsStrip
                        featuredSection
                    }
                    Section {
                        ForEach(filtered) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                gameRow(game)
                            }
                            .buttonStyle(.plain)
                            if game.id != filtered.last?.id {
                                Divider().padding(.leading, 86)
                            }
                        }
                    } header: {
                        listHeader
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ゲームを検索…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $randomDest) { game in
            NavigationStack {
                GameDetailView(game: game)
            }
        }
    }

    // MARK: - Hero

    var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.08, blue: 0.55),
                    Color(red: 0.06, green: 0.30, blue: 0.80),
                    Color(red: 0.00, green: 0.58, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            // Decorative blobs
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 220)
                .blur(radius: 2)
                .offset(x: 100, y: -70)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 160)
                .blur(radius: 2)
                .offset(x: -120, y: 30)
            Circle()
                .fill(Color(red: 0.4, green: 0.2, blue: 1.0).opacity(0.25))
                .frame(width: 180)
                .blur(radius: 20)
                .offset(x: -60, y: 80)

            // Content
            VStack(spacing: 20) {
                Spacer().frame(height: 60) // safe area

                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
                        )
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)

                // Title
                VStack(spacing: 6) {
                    Text("Games Hub")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("100のミニゲームを、ひとつのアプリで")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }

                // Surprise Me button
                Button {
                    randomDest = allGames[Int.random(in: 0..<allGames.count)]
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .bold))
                        Text("サプライズゲーム")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.15, green: 0.05, blue: 0.50))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 5)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .frame(minHeight: 380)
    }

    // MARK: - Stats Strip

    var statsStrip: some View {
        HStack(spacing: 0) {
            statPill(value: "100", label: "ゲーム", icon: "gamecontroller.fill")
            statDivider
            statPill(value: "100%", label: "SwiftUI", icon: "swift")
            statDivider
            statPill(value: "0", label: "広告", icon: "hand.raised.fill")
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundStyle(Color(.separator))
        }
    }

    var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 40)
    }

    func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Featured Section

    var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("フィーチャー")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                Text("8ゲーム")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ContentView.featured) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            featuredCard(game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 24)
        .background(Color(.systemBackground))
    }

    func featuredCard(_ game: GameEntry) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [game.color, game.color.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 162, height: 210)

            // Large decorative icon
            Image(systemName: game.icon)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: 60, y: -18)
                .clipped()

            // Small icon + text
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 36, height: 36)
                    Image(systemName: game.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(game.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .frame(width: 162, height: 210)
        .shadow(color: game.color.opacity(0.45), radius: 14, x: 0, y: 7)
    }

    // MARK: - All Games List

    var listHeader: some View {
        HStack {
            Text(searchText.isEmpty ? "すべてのゲーム" : "検索結果")
                .font(.system(size: 22, weight: .black, design: .rounded))
            Spacer()
            if searchText.isEmpty {
                Text("\(allGames.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundStyle(Color(.separator))
        }
    }

    func gameRow(_ game: GameEntry) -> some View {
        HStack(spacing: 14) {
            // App-style icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [game.color, game.color.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: game.color.opacity(0.3), radius: 6, x: 0, y: 3)
                Image(systemName: game.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(game.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Game Detail

struct GameDetailView: View {
    let game: GameEntry

    var body: some View {
        game.make()
            .navigationTitle(game.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
