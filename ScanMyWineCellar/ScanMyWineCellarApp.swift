import SwiftUI

@main
struct ScanMyWineCellarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase

    private let persistence = PersistenceController.shared

    init() {
        LegacyMigrator.migrateIfNeeded(into: PersistenceController.shared.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            CellarView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .preferredColorScheme(
                    appearance == "light" ? .light : appearance == "dark" ? .dark : nil
                )
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                persistence.save()
            }
        }
    }
}
