import SwiftUI
import SwiftData

@main
struct ScanMyWineCellarApp: App {
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            CellarView()
                .preferredColorScheme(
                    appearance == "light" ? .light : appearance == "dark" ? .dark : nil
                )
        }
        .modelContainer(for: [Wine.self, Cellar.self, Rack.self])
    }
}
