import CoreData
import UIKit

/// The Core Data stack. NSPersistentCloudKitContainer is used so the store
/// can later sync and be shared via CloudKit; no CloudKit options are
/// attached yet, so today it behaves as a purely local store.
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    private var saveTask: Task<Void, Never>?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(
            name: "ScanMyWineCellar",
            managedObjectModel: Self.model
        )
        let description = NSPersistentStoreDescription(
            url: inMemory
                ? URL(fileURLWithPath: "/dev/null")
                : NSPersistentContainer.defaultDirectoryURL()
                    .appendingPathComponent("ScanMyWineCellar.sqlite")
        )
        // Required once CloudKit mirroring is turned on; harmless before.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load the cellar database: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

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
