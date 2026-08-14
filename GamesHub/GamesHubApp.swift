import SwiftUI

@main
struct GamesHubApp: App {
    var body: some Scene {
        WindowGroup {
            // The hub and every game are designed on dark surfaces; locking the
            // scheme keeps navigation bars and system materials legible on top of them.
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
