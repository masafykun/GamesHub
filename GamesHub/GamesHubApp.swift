import SwiftUI

@main
struct GamesHubApp: App {
    var body: some Scene {
        WindowGroup {
            // The hub and every game are designed on dark surfaces; locking the
            // scheme keeps navigation bars and system materials legible on top of them.
            root
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        // README 用のスクリーンショットを撮るための入口。
        //   xcrun simctl launch booted com.gameshub.GamesHub -openGame "Flappy Bird"
        // で、ハブを経由せずそのゲームの画面から起動する。UI 自動化ツール（idb 等）を
        // 入れずに 100 本ぶんを機械的に撮れるようにするためのもので、
        // 一覧のレイアウトが変わっても壊れない。
        if let name = UserDefaults.standard.string(forKey: "openGame"),
           let game = allGames.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            NavigationStack {
                GameDetailView(game: game)
            }
        } else {
            ContentView()
        }
        #else
        ContentView()
        #endif
    }
}
