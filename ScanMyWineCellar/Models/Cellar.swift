import Foundation
import SwiftData

// LEGACY — the original SwiftData model, kept unchanged so LegacyMigrator
// can open old stores. The app itself uses CDCellar (CoreDataModels.swift).
// Do not modify: the declarations must keep matching the old store's schema.

@Model
final class Cellar {
    var name: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade, inverse: \Wine.cellar)
    var wines: [Wine]?

    @Relationship(deleteRule: .cascade, inverse: \Rack.cellar)
    var racks: [Rack]?

    init(name: String, dateCreated: Date = .now) {
        self.name = name
        self.dateCreated = dateCreated
    }

    /// "My Cellar", then "My Cellar 2", "My Cellar 3", …
    static func nextDefaultName(existing: [String]) -> String {
        if !existing.contains("My Cellar") { return "My Cellar" }
        var n = 2
        while existing.contains("My Cellar \(n)") { n += 1 }
        return "My Cellar \(n)"
    }
}
