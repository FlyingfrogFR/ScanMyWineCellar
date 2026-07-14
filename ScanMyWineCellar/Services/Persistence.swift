import CloudKit
import CoreData
import UIKit

/// The Core Data stack, mirrored to CloudKit. Two stores are loaded: the
/// private store (your own cellars, synced across your devices) and the
/// shared store (cellars other people shared with you via CKShare). Both
/// feed the same viewContext, so shared cellars appear in the app
/// automatically. Without an iCloud account the app simply works locally.
final class PersistenceController {
    static let shared = PersistenceController()

    static let cloudKitContainerID = "iCloud.com.scanmywinecellar.app"

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private var saveTask: Task<Void, Never>?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(
            name: "ScanMyWineCellar",
            managedObjectModel: Self.model
        )

        if inMemory {
            // Previews: a single local store, no CloudKit.
            let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
            container.persistentStoreDescriptions = [description]
        } else {
            let baseURL = NSPersistentContainer.defaultDirectoryURL()

            // Private database: the user's own data. Same store file as
            // before CloudKit was attached, so existing data is kept and
            // uploaded on first sync.
            let privateDescription = NSPersistentStoreDescription(
                url: baseURL.appendingPathComponent("ScanMyWineCellar.sqlite")
            )
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
            let privateOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions

            // Shared database: cellars shared with this user.
            let sharedDescription = NSPersistentStoreDescription(
                url: baseURL.appendingPathComponent("ScanMyWineCellar-shared.sqlite")
            )
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDescription.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
            let sharedOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerID
            )
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions

            // The private store comes first: objects created without an
            // explicit store assignment default to it.
            container.persistentStoreDescriptions = [privateDescription, sharedDescription]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load the cellar database: \(error)")
            }
        }

        for description in container.persistentStoreDescriptions {
            guard let url = description.url,
                  let store = container.persistentStoreCoordinator.persistentStore(for: url)
            else { continue }
            if description.cloudKitContainerOptions?.databaseScope == .shared {
                sharedStore = store
            } else {
                privateStore = store
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        #if DEBUG
        // Push the model's schema to the CloudKit development environment
        // once, so the record types exist. Before shipping a TestFlight
        // build, deploy the schema to production in the CloudKit Console.
        if !inMemory, !UserDefaults.standard.bool(forKey: "cloudKitSchemaPushed") {
            do {
                try container.initializeCloudKitSchema(options: [])
                UserDefaults.standard.set(true, forKey: "cloudKitSchemaPushed")
            } catch {
                print("CloudKit schema push failed (will retry next launch): \(error)")
            }
        }
        #endif

        // SwiftData autosaved; Core Data doesn't. Save shortly after any
        // change, and immediately when the app leaves the foreground.
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: container.viewContext,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleSave()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.save()
        }
    }

    func save() {
        saveTask?.cancel()
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Cellar save failed: \(error)")
            context.rollback()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    // MARK: - Sharing

    /// With two stores loaded, brand-new root objects (cellars) must be
    /// pinned to the private store explicitly.
    func assignToPrivateStore(_ object: NSManagedObject) {
        if let privateStore {
            container.viewContext.assign(object, to: privateStore)
        }
    }

    /// Returns the CKShare for a cellar, creating one (and moving the
    /// cellar with all its wines and racks into a shared CloudKit zone)
    /// if it isn't shared yet.
    func share(_ cellar: CDCellar) async throws -> (CKShare, CKContainer) {
        save()
        let ckContainer = CKContainer(identifier: Self.cloudKitContainerID)
        if let existing = try container.fetchShares(matching: [cellar.objectID])[cellar.objectID] {
            return (existing, ckContainer)
        }
        let (_, share, shareContainer) = try await container.share([cellar], to: nil)
        share[CKShare.SystemFieldKey.title] = cellar.name
        var updated = share
        if let privateStore {
            updated = try await container.persistUpdatedShare(share, in: privateStore)
        }
        return (updated, shareContainer)
    }

    /// Accepts a share invitation (from a link opened in Messages/Mail);
    /// the shared cellar then syncs into the shared store.
    func acceptShare(metadata: CKShare.Metadata) {
        guard let sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error {
                print("Failed to accept the shared cellar: \(error)")
            }
        }
    }

    // MARK: - Model

    /// The managed object model, built in code so there is no .xcdatamodeld
    /// to keep in sync. CloudKit compatibility rules: every attribute is
    /// non-optional with a default value (or optional), every relationship
    /// is optional and has an inverse, and there are no unique constraints.
    static let model: NSManagedObjectModel = {
        let cellar = NSEntityDescription()
        cellar.name = "CDCellar"
        cellar.managedObjectClassName = "CDCellar"

        let rack = NSEntityDescription()
        rack.name = "CDRack"
        rack.managedObjectClassName = "CDRack"

        let wine = NSEntityDescription()
        wine.name = "CDWine"
        wine.managedObjectClassName = "CDWine"

        // Relationships (pair-wise, with inverses).
        let wineCellar = relationship("cellar", to: cellar, toMany: false, deleteRule: .nullifyDeleteRule)
        let cellarWines = relationship("wines", to: wine, toMany: true, deleteRule: .cascadeDeleteRule)
        wineCellar.inverseRelationship = cellarWines
        cellarWines.inverseRelationship = wineCellar

        let rackCellar = relationship("cellar", to: cellar, toMany: false, deleteRule: .nullifyDeleteRule)
        let cellarRacks = relationship("racks", to: rack, toMany: true, deleteRule: .cascadeDeleteRule)
        rackCellar.inverseRelationship = cellarRacks
        cellarRacks.inverseRelationship = rackCellar

        let wineRack = relationship("rack", to: rack, toMany: false, deleteRule: .nullifyDeleteRule)
        let rackWines = relationship("wines", to: wine, toMany: true, deleteRule: .nullifyDeleteRule)
        wineRack.inverseRelationship = rackWines
        rackWines.inverseRelationship = wineRack

        cellar.properties = [
            attribute("name", .stringAttributeType, defaultValue: ""),
            attribute("dateCreated", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            cellarWines,
            cellarRacks,
        ]

        rack.properties = [
            attribute("name", .stringAttributeType, defaultValue: ""),
            attribute("orderIndex", .integer64AttributeType, defaultValue: 0),
            attribute("floorCount", .integer64AttributeType, defaultValue: 6),
            attribute("bottlesPerFloor", .integer64AttributeType, defaultValue: 8),
            attribute("floorNamesData", .binaryDataAttributeType, optional: true),
            rackCellar,
            rackWines,
        ]

        wine.properties = [
            attribute("name", .stringAttributeType, defaultValue: ""),
            attribute("producer", .stringAttributeType, defaultValue: ""),
            attribute("vintage", .integer64AttributeType, defaultValue: 0),
            attribute("colorRaw", .stringAttributeType, defaultValue: WineColor.unknown.rawValue),
            attribute("region", .stringAttributeType, defaultValue: ""),
            attribute("country", .stringAttributeType, defaultValue: ""),
            attribute("grapeVarieties", .stringAttributeType, defaultValue: ""),
            attribute("appellation", .stringAttributeType, defaultValue: ""),
            attribute("quantity", .integer64AttributeType, defaultValue: 1),
            attribute("notes", .stringAttributeType, defaultValue: ""),
            attribute("dateAdded", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("floorIndex", .integer64AttributeType, defaultValue: 0),
            wineCellar,
            wineRack,
        ]

        let model = NSManagedObjectModel()
        model.entities = [cellar, rack, wine]
        return model
    }()

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        defaultValue: Any? = nil,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.defaultValue = defaultValue
        attribute.isOptional = optional
        return attribute
    }

    private static func relationship(
        _ name: String,
        to destination: NSEntityDescription,
        toMany: Bool,
        deleteRule: NSDeleteRule
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = toMany ? 0 : 1
        relationship.isOptional = true
        relationship.deleteRule = deleteRule
        return relationship
    }
}
