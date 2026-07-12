import CoreData
import SwiftData

/// One-time copy of the original SwiftData store ("default.store") into the
/// Core Data store that replaced it. The legacy @Model classes (Wine,
/// Cellar, Rack) are kept in the project solely so this can open the old
/// file; the old store is never modified or deleted, so a failed migration
/// simply retries on the next launch.
enum LegacyMigrator {
    private static let completedKey = "legacyStoreMigrated"

    static func migrateIfNeeded(into context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return }

        let legacyURL = URL.applicationSupportDirectory.appending(path: "default.store")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            // Fresh install — nothing to migrate.
            UserDefaults.standard.set(true, forKey: completedKey)
            return
        }

        // Only ever migrate into an empty store.
        let wineCount = (try? context.count(for: NSFetchRequest<CDWine>(entityName: "CDWine"))) ?? 0
        let cellarCount = (try? context.count(for: NSFetchRequest<CDCellar>(entityName: "CDCellar"))) ?? 0
        guard wineCount == 0, cellarCount == 0 else {
            UserDefaults.standard.set(true, forKey: completedKey)
            return
        }

        do {
            // Opened read-write so SQLite can recover its WAL journal, but
            // nothing is ever saved back to the old store.
            let configuration = ModelConfiguration(url: legacyURL)
            let modelContainer = try ModelContainer(
                for: Wine.self, Cellar.self, Rack.self,
                configurations: configuration
            )
            let source = ModelContext(modelContainer)

            let cellars = try source.fetch(
                FetchDescriptor<Cellar>(sortBy: [SortDescriptor(\.dateCreated)])
            )
            let racks = try source.fetch(
                FetchDescriptor<Rack>(sortBy: [SortDescriptor(\.orderIndex)])
            )
            let wines = try source.fetch(
                FetchDescriptor<Wine>(sortBy: [SortDescriptor(\.name)])
            )

            var cellarByID: [PersistentIdentifier: CDCellar] = [:]
            for old in cellars {
                let new = CDCellar(context: context)
                new.name = old.name
                new.dateCreated = old.dateCreated
                cellarByID[old.persistentModelID] = new
            }

            var rackByID: [PersistentIdentifier: CDRack] = [:]
            for old in racks {
                let new = CDRack(context: context)
                new.name = old.name
                new.orderIndex = old.orderIndex
                new.floorCount = old.floorCount
                new.bottlesPerFloor = old.bottlesPerFloor
                new.floorNames = old.floorNames
                new.cellar = old.cellar.flatMap { cellarByID[$0.persistentModelID] }
                rackByID[old.persistentModelID] = new
            }

            for old in wines {
                let new = CDWine(context: context)
                new.name = old.name
                new.producer = old.producer
                new.vintage = old.vintage
                new.colorRaw = old.colorRaw
                new.region = old.region
                new.country = old.country
                new.grapeVarieties = old.grapeVarieties
                new.appellation = old.appellation
                new.quantity = old.quantity
                new.notes = old.notes
                new.dateAdded = old.dateAdded
                new.floorIndex = old.floorIndex
                new.cellar = old.cellar.flatMap { cellarByID[$0.persistentModelID] }
                new.rack = old.rack.flatMap { rackByID[$0.persistentModelID] }
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: completedKey)
        } catch {
            // Leave the flag unset so the next launch retries.
            context.rollback()
        }
    }
}
