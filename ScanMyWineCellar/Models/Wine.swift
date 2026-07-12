import Foundation
import SwiftData

// LEGACY — the original SwiftData model, kept unchanged so LegacyMigrator
// can open old stores. The app itself uses CDWine (CoreDataModels.swift).
// Do not modify: the declarations must keep matching the old store's schema.

@Model
final class Wine {
    var name: String
    var producer: String
    /// 0 means unknown / non-vintage
    var vintage: Int
    var colorRaw: String
    var region: String
    var country: String
    var grapeVarieties: String
    var appellation: String
    var quantity: Int
    var notes: String
    var dateAdded: Date
    var cellar: Cellar?
    /// Where this wine lives: nil rack = not placed on the map yet.
    /// Location is tracked per wine (all bottles together) for now.
    var rack: Rack?
    var floorIndex: Int = 0

    init(
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
