import CoreData
import Foundation

// The app's storage models, backed by Core Data so the cellar can later
// sync and be shared with family via CloudKit (CKShare) — SwiftData cannot
// share across Apple IDs. The schema is defined in code in
// PersistenceController.model; every attribute has a default value and
// every relationship is optional, which is the shape CloudKit requires.

@objc(CDCellar)
final class CDCellar: NSManagedObject, Identifiable {
    @NSManaged var name: String
    @NSManaged var dateCreated: Date
    @NSManaged var wines: NSSet?
    @NSManaged var racks: NSSet?

    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
        self.dateCreated = .now
    }

    /// "My Cellar", then "My Cellar 2", "My Cellar 3", …
    static func nextDefaultName(existing: [String]) -> String {
        if !existing.contains("My Cellar") { return "My Cellar" }
        var n = 2
        while existing.contains("My Cellar \(n)") { n += 1 }
        return "My Cellar \(n)"
    }
}

@objc(CDRack)
final class CDRack: NSManagedObject, Identifiable {
    @NSManaged var name: String
    @NSManaged var orderIndex: Int
    @NSManaged var floorCount: Int
    @NSManaged var bottlesPerFloor: Int
    /// JSON-encoded [String] of custom shelf names, indexed bottom-up;
    /// "" means the default "Shelf N". Stored as data because CloudKit
    /// has no array attribute type.
    @NSManaged var floorNamesData: Data?
    @NSManaged var cellar: CDCellar?
    @NSManaged var wines: NSSet?

    convenience init(
        context: NSManagedObjectContext,
        name: String,
        orderIndex: Int,
        floorCount: Int = 6,
        bottlesPerFloor: Int = 8
    ) {
        self.init(context: context)
        self.name = name
        self.orderIndex = orderIndex
        self.floorCount = floorCount
        self.bottlesPerFloor = bottlesPerFloor
    }

    var winesArray: [CDWine] {
        (wines as? Set<CDWine>)?.sorted { $0.name < $1.name } ?? []
    }

    var floorNames: [String] {
        get {
            floorNamesData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        }
        set {
            floorNamesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Display name of a shelf (0 = bottom shelf, shown as "Shelf 1").
    func floorName(_ index: Int) -> String {
        let custom = customFloorName(index)
        return custom.isEmpty ? "Shelf \(index + 1)" : custom
    }

    func customFloorName(_ index: Int) -> String {
        let names = floorNames
        return index < names.count ? names[index] : ""
    }

    func setFloorName(_ name: String, at index: Int) {
        var names = floorNames
        while names.count <= index { names.append("") }
        names[index] = name.trimmingCharacters(in: .whitespaces)
        floorNames = names
    }

    /// "Rack A", "Rack B", … past Z falls back to numbers.
    static func nextDefaultName(existing: [String]) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for letter in letters {
            let candidate = "Rack \(letter)"
            if !existing.contains(candidate) { return candidate }
        }
        var n = 27
        while existing.contains("Rack \(n)") { n += 1 }
        return "Rack \(n)"
    }
}

@objc(CDWine)
final class CDWine: NSManagedObject, Identifiable {
    @NSManaged var name: String
    @NSManaged var producer: String
    /// 0 means unknown / non-vintage
    @NSManaged var vintage: Int
    @NSManaged var colorRaw: String
    @NSManaged var region: String
    @NSManaged var country: String
    @NSManaged var grapeVarieties: String
    @NSManaged var appellation: String
    @NSManaged var quantity: Int
    @NSManaged var notes: String
    @NSManaged var dateAdded: Date
    @NSManaged var cellar: CDCellar?
    /// Where this wine lives: nil rack = not placed on the map yet.
    /// Location is tracked per wine (all bottles together) for now.
    @NSManaged var rack: CDRack?
    @NSManaged var floorIndex: Int

    convenience init(
        context: NSManagedObjectContext,
        name: String,
        producer: String = "",
        vintage: Int = 0,
        color: WineColor = .unknown,
        region: String = "",
        country: String = "",
        grapeVarieties: String = "",
        appellation: String = "",
        quantity: Int = 1,
        notes: String = "",
        dateAdded: Date = .now
    ) {
        self.init(context: context)
        self.name = name
        self.producer = producer
        self.vintage = vintage
        self.colorRaw = color.rawValue
        self.region = region
        self.country = country
        self.grapeVarieties = grapeVarieties
        self.appellation = appellation
        self.quantity = quantity
        self.notes = notes
        self.dateAdded = dateAdded
    }

    var color: WineColor {
        get { WineColor(rawValue: colorRaw) ?? .unknown }
        set { colorRaw = newValue.rawValue }
    }

    var vintageLabel: String {
        vintage > 0 ? String(vintage) : "NV"
    }

    var locationLabel: String {
        guard let rack else { return "" }
        return "\(rack.name) · \(rack.floorName(floorIndex))"
    }

    /// Key used to merge duplicates when adding scanned wines.
    var mergeKey: String {
        [name.lowercased(), producer.lowercased(), String(vintage)]
            .joined(separator: "|")
            .trimmingCharacters(in: .whitespaces)
    }
}
