import SwiftUI
import SwiftData

@main
struct ScanMyWineCellarApp: App {
    var body: some Scene {
        WindowGroup {
            CellarView()
        }
        .modelContainer(for: [Wine.self, Cellar.self])
    }
}
