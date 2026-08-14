import SwiftUI

// MARK: - Models 

enum LetterChainPhase { case start, playing, gameOver }

struct LetterChainCell: Identifiable {
    let id: Int
    let letter: Character
    var isSelected: Bool = false
}

// MARK: - LetterChainView

struct LetterChainView: View {
    @State private var phase: LetterChainPhase = .start
    @State private var grid: [LetterChainCell] = []
    @State private var selectedIndices: [Int] = []
    @State private var startIndex: Int = 0
    @State private var score: Int = 0
    @State private var message: String = ""
    @State private var showMessage: Bool = false
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0
    @State private var timeLeft: Int = 90
    @State private var timer: Timer? = nil
    @AppStorage("letterChainBestScore") private var bestScore: Int = 0

    let gridSize = 5

    let wordList: Set<String> = [
        "act","age","aid","aim","air","all","ant","arc","are","arm","art","ate","axe",
        "bad","bag","ban","bar","bat","bay","bed","bet","big","bit","bow","box","boy","bug","bus","but",
        "cab","can","cap","car","cat","cop","cow","cry","cup","cut",
        "dad","dam","day","den","dew","dig","dim","dip","dog","dot","dry","dug","dye",
        "ear","eat","egg","ego","elf","elm","end","era",
        "fan","far","fat","fee","few","fig","fin","fit","fix","fly","fog","fox","fry","fun","fur",
        "gap","gas","gem","get","gin","god","got","gun","gut","guy",
        "had","ham","has","hat","hay","hen","her","him","his","hit","hog","hop","hot","how","hub","hug","hum","hut",
        "ice","icy","ill","imp","ink","ion",
        "jab","jar","jaw","jay","jet","job","jog","joy","jug",
        "keg","key","kin","kit",
        "lab","lag","lap","law","lay","leg","lid","lip","lit","log","low",
        "mad","man","map","mat","may","men","met","mix","mob","mop","mud","mug",
        "nag","nap","net","new","nip","nod","nor","not","now","nut",
        "oak","odd","oil","old","opt","ore","our","out","owe","owl","own",
        "pad","pal","pan","pat","paw","pay","peg","pen","pet","pie","pig","pin","pit","pod","pop","pot","pub","pun","put",
        "rag","ram","ran","rat","raw","ray","red","rib","rid","rig","rim","rip","rob","rod","rot","row","rub","rug","rum","run","rut",
        "sag","sap","sat","saw","say","set","sew","sin","sip","sit","sob","son","sow","sub","sum","sun",
        "tab","tan","tap","tar","tax","ten","tie","tin","tip","toe","ton","top","toy","try","tub","tug",
        "van","vat","vet","vow",
        "wad","war","was","wax","web","wed","wet","wig","win","wit","woe","won",
        "yam","yap","yew",
        "zap","zip","zoo",
        "able","acid","aged","area","army","away","baby","back","ball","band","bank","bare","barn","base","bath","bear","beat","been","bell","best","bird","bite","blue","bold","bolt","bond","bone","book","bore","born","both","burn","busy",
        "cage","cake","calm","came","cane","care","case","cave","cell","chip","clam","clap","clay","clip","club","clue","coal","coat","code","coil","coin","cold","come","cone","cook","cool","cope","cord","core","corn","cost","cozy","crab","crew","crop","curb","cure","curl","cute",
        "damp","dare","dark","data","date","dawn","dead","deal","dear","debt","deck","deed","deep","deli","deny","desk","dice","diet","dirt","disk","dome","done","door","dose","dove","down","drag","draw","drip","drop","drum","dual","dune","dusk","dust","duty",
        "edge","emit","epic","even","ever","evil","exam","exit",
        "face","fact","fade","fail","fair","fake","fall","fame","fast","fate","fear","feat","feel","felt","fern","fill","film","find","fine","fire","firm","fish","fist","five","flag","flat","flaw","flea","flew","flip","flog","flow","foam","fold","fond","font","food","fool","foot","ford","form","fort","foul","four","free","fuel","full",
        "gain","gale","game","gate","gave","gaze","germ","gift","girl","give","glad","glee","glow","glue","goal","gold","golf","gone","good","gore","gown","grab","gray","grew","grey","grid","grim","grin","grip","grit","grow","gulf","gust","guts",
        "hack","hail","hair","half","hall","halt","hand","hang","hard","hare","harm","harp","hash","hate","haul","head","heal","heap","hear","heat","heel","held","hell","help","herb","here","hero","high","hike","hill","hint","hire","hold","hole","home","hood","hook","hope","horn","hose","host","hour","hull","hung","hunt","hurt",
        "idea","idle","inch","into","iron",
        "jack","jail","join","joke","jolt","jump","just",
        "keen","keep","kill","kind","king","knew","knob","knot","know",
        "lack","lake","lamb","lame","land","lane","last","late","lava","lawn","lead","leaf","lean","leap","lend","lens","life","lift","like","lime","line","link","lion","list","live","load","loan","lock","lone","long","look","lore","lose","loss","lost","loud","love","luck","lump","lung",
        "made","mail","main","make","male","mane","mare","mark","mast","meal","mean","meet","melt","menu","mild","mile","mill","mind","mine","mint","miss","mist","mode","mole","moon","more","most","move","much","must",
        "nail","name","navy","near","neck","need","nest","next","nice","nine","node","none","noon","note","noun",
        "once","only","open","oven","over",
        "pace","pack","page","pain","pair","pale","palm","park","part","pass","past","path","pave","peak","peel","peer","pick","pile","pine","pink","pipe","plan","play","plot","plow","plug","plum","poem","poet","poll","pond","pool","poor","pore","port","pose","post","pour","pray","prey","prop","pull","pump","pure","push",
        "race","rack","rage","rail","rain","rake","rank","rare","rash","rate","read","real","reap","rear","reel","rely","rent","rest","rich","ride","ring","riot","ripe","rise","risk","roam","roar","robe","rock","role","roll","roof","room","rope","rose","rude","ruin","rule","rush",
        "safe","sage","sail","sale","salt","same","sand","sane","save","scan","scar","seal","seam","seat","seek","seem","self","sell","send","shed","ship","shoe","shop","shot","show","side","silk","sing","sink","site","size","skin","skip","slam","slap","slim","slip","slot","slow","slug","snap","snow","soak","soap","soar","sock","soft","soil","sold","sole","song","sore","sort","soul","sour","spin","spot","star","stem","step","stir","stop","stub","stud","stun","such","suit","surf",
        "tail","tale","tall","tame","tape","task","team","tear","tell","tend","tent","test","than","them","then","they","thin","this","tide","tile","till","time","tiny","tire","told","toll","tone","took","tore","toss","tour","town","trap","tree","trim","trip","true","tuna","tune","turn","twin",
        "ugly","undo","unit","upon","used",
        "vale","vary","vast","veal","veil","vein","very","vest","vine","void","volt",
        "wade","wage","wake","walk","wall","wand","want","ward","warm","wave","weak","wear","weed","week","well","went","were","west","when","whip","wide","wife","wild","will","wind","wine","wing","wise","wish","with","wolf","wood","wool","word","work","worn","wrap",
        "yard","year","yell","your",
        "zeal","zero","zone"
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.4, green: 0.2, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start: startView
            case .playing: gameView
            case .gameOver: gameOverView
            }
        }
    }

    // MARK: Start Screen
    var startView: some View {
        VStack(spacing: 28) {
            Text("Letter Chain")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Form words by tapping adjacent letters.\nThe last letter starts your next word!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)
            if difficulty > 1.0 {
                Text("Difficulty: \(String(format: "%.0f%%", difficulty * 100))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Button("Start Game") {
                startGame()
                phase = .playing
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .foregroundStyle(.white)
        }
        .padding()
    }

    // MARK: Game Screen
    var gameView: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("TIME")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(timeLeft)s")
                        .font(.title2.bold())
                        .foregroundStyle(timeLeft <= 15 ? .red : .white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MULTIPLIER")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "%.1fx", difficulty))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Word display
            HStack {
                Text(currentWord.isEmpty ? "Tap to start spelling..." : currentWord)
                    .font(.title3.bold())
                    .foregroundStyle(currentWord.isEmpty ? .white.opacity(0.5) : .white)
                Spacer()
                if showMessage {
                    Text(message)
                        .font(.headline)
                        .foregroundStyle(message.hasPrefix("+") ? Color.green : Color.red)
                        .transition(.opacity)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Grid
            VStack(spacing: 8) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let idx = row * gridSize + col
                            cellView(grid[idx])
                                .onTapGesture { handleTap(idx) }
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Buttons
            HStack(spacing: 16) {
                Button("Clear") { clearSelection() }
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.white)

                Button("Submit") { submitWord() }
                    .font(.headline.bold())
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(selectedIndices.count >= 3 ? Color.green.opacity(0.7) : Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
                    .foregroundStyle(.white)
                    .disabled(selectedIndices.count < 3)

                Button("Quit") { endRun() }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red.opacity(0.5), lineWidth: 1))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    // MARK: Game Over Screen
    var gameOverView: some View {
        VStack(spacing: 28) {
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(score)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Play Again") {
                startGame()
                phase = .playing
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .foregroundStyle(.white)

            Button("Menu") { phase = .start }
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }

    @ViewBuilder
    func cellView(_ cell: LetterChainCell) -> some View {
        let isStart = cell.id == startIndex && selectedIndices.isEmpty
        let selectionOrder = selectedIndices.firstIndex(of: cell.id)
        let isSelected = selectionOrder != nil

        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.yellow.opacity(0.6) : (isStart ? Color.orange.opacity(0.5) : Color.white.opacity(0.15)))
            RoundedRectangle(cornerRadius: 10)
                .stroke(isStart && selectedIndices.isEmpty ? Color.orange : (isSelected ? Color.yellow : Color.white.opacity(0.2)), lineWidth: 1.5)
            VStack(spacing: 0) {
                Text(String(cell.letter))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let order = selectionOrder {
                    Text("\(order + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    var currentWord: String {
        String(selectedIndices.map { grid[$0].letter })
    }

    // MARK: Game Logic
    func endRun() {
        timer?.invalidate()
        timer = nil
        bestScore = max(bestScore, score)
        phase = .gameOver
    }

    func startGame() {
        // A run now has a clock, so it actually finishes.
        score = 0
        timeLeft = 90
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeLeft > 1 {
                timeLeft -= 1
            } else {
                timeLeft = 0
                endRun()
            }
        }
        let letters: [Character] = Array("AAABBBCCDDEEEEFFGGHHHIIIJKKLLMMNNOOOPPQRRSSTTTUUUVVWWXYYZ")
        grid = (0..<25).map { i in
            LetterChainCell(id: i, letter: letters.randomElement() ?? "A")
        }
        startIndex = Int.random(in: 0..<25)
        selectedIndices = []
        showMessage = false
    }

    func handleTap(_ id: Int) {
        if selectedIndices.isEmpty {
            guard id == startIndex else { return }
            selectedIndices.append(id)
            grid[id].isSelected = true
            return
        }
        let last = selectedIndices.last!
        guard isAdjacent(from: last, to: id), !selectedIndices.contains(id) else { return }
        selectedIndices.append(id)
        grid[id].isSelected = true
    }

    func clearSelection() {
        for i in selectedIndices { grid[i].isSelected = false }
        selectedIndices = []
    }

    func submitWord() {
        let word = currentWord.lowercased()
        let isValid = wordList.contains(word)
        recentResults.append(isValid)
        if recentResults.count > 5 { recentResults.removeFirst() }

        // Adaptive difficulty: if last 5 results have >4 trues, increase difficulty ~20%
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 3.0)
            recentResults = []
        }

        if isValid {
            let points = Int(Double(word.count * word.count) * difficulty)
            score += points
            showMsg("+\(points) pts!")
            let lastIdx = selectedIndices.last ?? startIndex
            for i in selectedIndices { grid[i].isSelected = false }
            startIndex = lastIdx
            selectedIndices = []
        } else {
            showMsg("Invalid word!")
            clearSelection()
        }
    }

    func showMsg(_ text: String) {
        message = text
        withAnimation { showMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showMessage = false }
        }
    }

    func isAdjacent(from: Int, to: Int) -> Bool {
        let fromRow = from / gridSize, fromCol = from % gridSize
        let toRow = to / gridSize, toCol = to % gridSize
        return abs(fromRow - toRow) <= 1 && abs(fromCol - toCol) <= 1 && from != to
    }
}

#Preview { LetterChainView() }
