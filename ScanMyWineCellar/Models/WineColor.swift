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
