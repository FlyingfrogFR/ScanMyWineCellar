import Foundation

/// Suggests floor names from what's actually stored on the floor —
/// dominant region, vintage range, color — always overridable by the user.
enum FloorNaming {
    static func suggestions(for wines: [CDWine]) -> [String] {
        guard !wines.isEmpty else { return [] }
        var out: [String] = []

        // Dominant region: at least half the wines share it.
        let regionGroups = Dictionary(grouping: wines.filter { !$0.region.isEmpty }, by: \.region)
        let topRegion = regionGroups.max { $0.value.count < $1.value.count }
        if let topRegion, topRegion.value.count * 2 >= wines.count {
            out.append(topRegion.key)
        }

        // Vintage range.
        let years = wines.map(\.vintage).filter { $0 > 0 }
        if let lo = years.min(), let hi = years.max() {
            out.append(lo == hi ? String(lo) : "\(lo) – \(hi)")
        }

        // Single color.
        let colors = Set(wines.map(\.color))
        if colors.count == 1, let color = colors.first, color != .unknown {
            let plural: String
            switch color {
            case .sparkling: plural = "Sparkling"
            case .rose: plural = "Rosés"
            default: plural = color.label + "s"
            }
            out.append(plural)
            if let region = topRegion, region.value.count * 2 >= wines.count {
                out.append("\(region.key) \(plural.lowercased())")
            }
        }

        // Dominant country as a fallback when regions are missing.
        if out.isEmpty {
            let countryGroups = Dictionary(grouping: wines.filter { !$0.country.isEmpty }, by: \.country)
            if let top = countryGroups.max(by: { $0.value.count < $1.value.count }),
               top.value.count * 2 >= wines.count {
                out.append(top.key)
            }
        }

        // Dedupe, keep order, cap at 4.
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }.prefix(4).map { $0 }
    }
}
