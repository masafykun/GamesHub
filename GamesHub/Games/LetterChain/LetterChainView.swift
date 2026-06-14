import SwiftUI

// MARK: - Models

enum LtChGamePhase { case start, playing, gameOver }

struct LtChCell: Identifiable {
    let id: Int
    let letter: Character
    var isHighlighted: Bool = false
    var isSelected: Bool = false
}

// MARK: - LetterChainView

struct LetterChainView: View {
    @State private var phase: LtChGamePhase = .start
    @State private var grid: [LtChCell] = []
    @State private var selectedIndices: [Int] = []
    @State private var startIndex: Int = 0
    @State private var score: Int = 0
    @State private var message: String = ""
    @State private var showMessage: Bool = false

    let gridSize = 5
    let wordList: Set<String> = [
        "act","age","ago","aid","aim","air","all","ant","ape","arc","are","ark","arm","art","ate","axe",
        "bad","bag","ban","bar","bat","bay","bed","bet","big","bit","bow","box","boy","bug","bus","but",
        "cab","can","cap","car","cat","cob","cod","cog","cop","cow","cry","cup","cut",
        "dad","dam","day","den","dew","did","dig","dim","dip","dog","dot","dry","dug","dye",
        "ear","eat","egg","ego","elf","elm","end","era","eve","eve",
        "fad","fan","far","fat","fee","few","fig","fin","fit","fix","fly","fog","for","fox","fry","fun","fur",
        "gap","gas","gem","get","gig","gin","gnu","god","got","gun","gut","guy",
        "had","ham","has","hat","hay","hen","her","him","his","hit","hog","hop","hot","how","hub","hug","hum","hut",
        "ice","icy","ill","imp","ink","ion","ire",
        "jab","jar","jaw","jay","jet","job","jog","joy","jug",
        "keg","key","kin","kit",
        "lab","lag","lap","law","lax","lay","leg","lid","lip","lit","log","low",
        "mad","man","map","mat","max","may","men","met","mix","mob","mod","mop","mud","mug","mum",
        "nag","nap","net","new","nip","nod","nor","not","now","nun","nut",
        "oak","oar","odd","oil","old","opt","orb","ore","our","out","owe","owl","own",
        "pad","pal","pan","pat","paw","pay","peg","pen","per","pet","pie","pig","pin","pit","ply","pod","pop","pot","pry","pub","pun","pup","pus","put",
        "rag","ram","ran","rat","raw","ray","red","ref","rib","rid","rig","rim","rip","rob","rod","rot","row","rub","rug","rum","run","rut",
        "sag","sap","sat","saw","say","sea","set","sew","shy","sin","sip","sit","six","ski","sky","sly","sob","sod","son","sow","spa","spy","sty","sub","sue","sum","sun","sup",
        "tab","tan","tap","tar","tax","ten","the","tie","tin","tip","toe","ton","too","top","toy","try","tub","tug","two",
        "urn","use",
        "van","vat","vet","vow",
        "wad","war","was","wax","web","wed","wet","who","why","wig","win","wit","woe","wok","won","woo","wry",
        "yam","yap","yew","you",
        "zap","zen","zig","zip","zoo",
        "able","acid","aged","also","area","army","away","baby","back","ball","band","bank","bare","barn","base","bath","bear","beat","been","bell","best","bird","bite","blue","bold","bolt","bond","bone","book","bore","born","both","brag","brew","brow","burn","busy",
        "cage","cake","calm","came","cane","care","case","cave","cell","cent","chip","cite","clam","clap","clay","clip","club","clue","coal","coat","code","coil","coin","cold","come","cone","cook","cool","cope","cord","core","corn","cost","cozy","crab","crew","crop","curb","cure","curl","cute",
        "damp","dare","dark","data","date","dawn","dead","deal","dear","debt","deck","deed","deep","deft","deli","deny","desk","dice","diet","dirt","disc","disk","does","dome","done","door","dose","dove","down","drag","draw","drew","drip","drop","drum","dual","duel","dune","dusk","dust","duty",
        "each","edge","else","emit","epic","even","ever","evil","exam","exit",
        "face","fact","fade","fail","fair","fake","fall","fame","fast","fate","fawn","fear","feat","feel","felt","fern","fill","film","find","fine","fire","firm","fish","fist","five","flag","flat","flaw","flea","flew","flip","flit","flog","flow","foam","fold","fond","font","food","fool","foot","ford","fore","fork","form","fort","foul","four","free","from","fuel","full",
        "gain","gale","game","gate","gave","gaze","germ","gift","girl","give","glad","glee","glow","glue","goal","gold","golf","gone","good","goon","gore","gown","grab","gray","grew","grey","grid","grim","grin","grip","grit","grow","gulf","gust","guts",
        "hack","hail","hair","half","hall","halt","hand","hang","hard","hare","harm","harp","hash","hate","haul","head","heal","heap","hear","heat","heel","held","hell","help","herb","here","hero","high","hike","hill","hint","hire","hold","hole","home","hood","hoof","hook","hope","horn","hose","host","hour","hull","hung","hunt","hurt",
        "idea","idle","inch","into","iron",
        "jack","jail","join","joke","jolt","jump","just",
        "keen","keep","kill","kind","king","knew","knob","knot","know",
        "lack","lake","lamb","lame","land","lane","lark","last","late","lava","lawn","lead","leaf","leak","lean","leap","lend","lens","lest","life","lift","like","lily","lime","line","link","lion","list","live","load","loan","lock","loft","lone","long","look","loom","loon","loop","lore","lose","loss","lost","loud","love","luck","lump","lung",
        "made","mail","main","make","male","mane","mare","mark","mars","mast","meal","mean","meet","melt","menu","mere","mesh","mild","mile","mill","mind","mine","mint","mire","miss","mist","mode","mole","molt","moon","more","morn","most","moth","move","much","mule","must",
        "nail","name","navy","near","neck","need","nest","next","nice","nine","node","none","noon","note","noun","nude",
        "obey","once","only","open","oven","over",
        "pace","pack","page","pain","pair","pale","palm","park","part","pass","past","path","pave","peak","peal","peel","peer","pelt","pick","pile","pine","pink","pipe","plan","play","plea","plot","plow","ploy","plug","plum","plus","poem","poet","poll","pond","pool","poor","pore","port","pose","post","pour","pray","prey","prod","prop","pull","pump","pure","push",
        "race","rack","rage","rail","rain","rake","rank","rare","rash","rate","read","real","reap","rear","reel","rein","rely","rent","rest","rich","ride","ring","riot","ripe","rise","risk","roam","roar","robe","rock","role","roll","roof","room","rope","rose","rude","ruin","rule","rush",
        "safe","sage","sail","sale","salt","same","sand","sane","sang","save","scan","scar","seal","seam","seat","seek","seem","self","sell","send","sent","shed","ship","shoe","shop","shot","show","side","sigh","sign","silk","sill","sing","sink","site","size","skid","skin","skip","slam","slap","slid","slim","slip","slot","slow","slug","slum","snap","snip","snow","soak","soap","soar","sock","sofa","soft","soil","sold","sole","some","song","sore","sort","soul","sour","span","spin","spot","stab","star","stem","step","stew","stir","stop","stow","stub","stud","stun","such","suit","surf",
        "tail","tale","tall","tame","tang","tape","task","teal","team","tear","tell","tend","tent","term","test","text","than","that","them","then","they","thin","this","thorn","thou","thus","tide","tile","till","time","tiny","tire","told","toll","tomb","tone","took","tore","torn","toss","tote","tour","town","trap","tree","trim","trip","true","tuft","tuna","tune","turn","twig","twin",
        "ugly","undo","unit","upon","used",
        "vale","vane","vary","vast","veal","veil","vein","very","vest","vile","vine","visa","void","volt",
        "wade","wage","wake","walk","wall","wand","want","ward","warm","wart","wave","weak","weal","wean","wear","weed","week","well","welt","went","were","west","when","whim","whip","wide","wife","wild","will","wilt","wind","wine","wing","wink","wise","wish","with","wolf","wood","wool","word","work","worm","worn","wrap","wren",
        "yard","year","yell","your",
        "zeal","zero","zone"
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .playing: gameView
            case .gameOver: gameOverView
            }
        }
    }

    // MARK: Start Screen
    var startView: some View {
        VStack(spacing: 24) {
            Text("Letter Chain")
                .font(.largeTitle.bold())
            Text("Tap adjacent letters to form words (3+ letters). The last letter becomes your next starting point!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Start Game") {
                startGame()
                phase = .playing
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding()
    }

    // MARK: Game Screen
    var gameView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Score: \(score)")
                    .font(.title2.bold())
                Spacer()
                Button("Quit") { phase = .gameOver }
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)

            Text("Current word: \(currentWord)")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            if showMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(message.contains("+") ? .green : .red)
                    .transition(.opacity)
            }

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gridSize), spacing: 8) {
                ForEach(grid) { cell in
                    cellView(cell)
                        .onTapGesture { handleTap(cell.id) }
                }
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Clear") { clearSelection() }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Submit") { submitWord() }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(selectedIndices.count >= 3 ? Color.green : Color.gray.opacity(0.3))
                    .foregroundStyle(selectedIndices.count >= 3 ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(selectedIndices.count < 3)
            }
        }
    }

    // MARK: Game Over Screen
    var gameOverView: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.largeTitle.bold())
            Text("Final Score: \(score)")
                .font(.title.bold())
                .foregroundStyle(Color.accentColor)
            Button("Play Again") {
                startGame()
                phase = .playing
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            Button("Menu") { phase = .start }
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func cellView(_ cell: LtChCell) -> some View {
        let isStart = cell.id == startIndex && selectedIndices.isEmpty
        let bgColor: Color = cell.isSelected ? .accentColor : (isStart ? .orange : Color(.secondarySystemBackground))
        let fgColor: Color = cell.isSelected || isStart ? .white : .primary

        Text(String(cell.letter))
            .font(.title2.bold())
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(bgColor)
            .foregroundStyle(fgColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isStart && selectedIndices.isEmpty ? Color.orange : Color.clear, lineWidth: 2)
            )
    }

    var currentWord: String {
        String(selectedIndices.map { grid[$0].letter })
    }

    // MARK: Game Logic
    func startGame() {
        let letters = "AAABBBCCDDEEEEFFGGHHHIIIJKKLLMMNNOOOPPQRRSSTTTUUUVVWWXYYZ"
        grid = (0..<25).map { i in
            LtChCell(id: i, letter: letters.randomElement() ?? "A")
        }
        startIndex = Int.random(in: 0..<25)
        selectedIndices = []
        score = 0
        showMessage = false
    }

    func handleTap(_ id: Int) {
        let expectedStart = selectedIndices.isEmpty ? startIndex : (selectedIndices.last ?? startIndex)
        guard isAdjacent(from: expectedStart, to: id) || (selectedIndices.isEmpty && id == startIndex) else { return }
        guard !selectedIndices.contains(id) else { return }
        if selectedIndices.isEmpty && id != startIndex { return }

        selectedIndices.append(id)
        grid[id].isSelected = true
    }

    func clearSelection() {
        for i in selectedIndices { grid[i].isSelected = false }
        selectedIndices = []
    }

    func submitWord() {
        let word = currentWord.lowercased()
        if wordList.contains(word) {
            let points = word.count * word.count
            score += points
            showMsg("+\(points) pts!")
            let lastIndex = selectedIndices.last ?? startIndex
            for i in selectedIndices { grid[i].isSelected = false }
            startIndex = lastIndex
            selectedIndices = []
        } else {
            showMsg("Not a valid word!")
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
