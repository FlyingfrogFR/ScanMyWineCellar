import Foundation
import SwiftData
import SwiftUI

enum WineColor: String, Codable, CaseIterable, Identifiable {
    case red
    case white
    case rose
    case sparkling
    case dessert
    case fortified
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .red: return "Red"
        case .white: return "White"
        case .rose: return "Rosé"
        case .sparkling: return "Sparkling"
        case .dessert: return "Dessert"
        case .fortified: return "Fortified"
        case .unknown: return "Unknown"
        }
    }

    var tint: Color {
        switch self {
        case .red: return Color(red: 0.55, green: 0.05, blue: 0.15)
        case .white: return Color(red: 0.93, green: 0.85, blue: 0.55)
        case .rose: return Color(red: 0.95, green: 0.6, blue: 0.65)
        case .sparkling: return Color(red: 0.85, green: 0.75, blue: 0.45)
        case .dessert: return Color(red: 0.8, green: 0.55, blue: 0.2)
        case .fortified: return Color(red: 0.45, green: 0.2, blue: 0.35)
        case .unknown: return .gray
        }
    }
}

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

    /// Key used to merge duplicates when adding scanned wines.
    var mergeKey: String {
        [name.lowercased(), producer.lowercased(), String(vintage)]
            .joined(separator: "|")
            .trimmingCharacters(in: .whitespaces)
    }
}
