import Foundation

/// A wine detected in a scan, editable in the review screen before it is
/// committed to the cellar. Empty strings / 0 mean "unknown".
struct ScannedWine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var producer: String
    var vintage: Int
    var color: WineColor
    var region: String
    var country: String
    var grapeVarieties: String
    var appellation: String
    var quantity: Int
    var include: Bool = true

    enum CodingKeys: String, CodingKey {
        case name
        case producer
        case vintage
        case color
        case region
        case country
        case grapeVarieties = "grape_varieties"
        case appellation
        case quantity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        producer = try c.decodeIfPresent(String.self, forKey: .producer) ?? ""
        vintage = try c.decodeIfPresent(Int.self, forKey: .vintage) ?? 0
        let colorRaw = try c.decodeIfPresent(String.self, forKey: .color) ?? "unknown"
        color = WineColor(rawValue: colorRaw) ?? .unknown
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? ""
        grapeVarieties = try c.decodeIfPresent(String.self, forKey: .grapeVarieties) ?? ""
        appellation = try c.decodeIfPresent(String.self, forKey: .appellation) ?? ""
        quantity = max(1, try c.decodeIfPresent(Int.self, forKey: .quantity) ?? 1)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(producer, forKey: .producer)
        try c.encode(vintage, forKey: .vintage)
        try c.encode(color.rawValue, forKey: .color)
        try c.encode(region, forKey: .region)
        try c.encode(country, forKey: .country)
        try c.encode(grapeVarieties, forKey: .grapeVarieties)
        try c.encode(appellation, forKey: .appellation)
        try c.encode(quantity, forKey: .quantity)
    }

    func toWine() -> Wine {
        Wine(
            name: name,
            producer: producer,
            vintage: vintage,
            color: color,
            region: region,
            country: country,
            grapeVarieties: grapeVarieties,
            appellation: appellation,
            quantity: quantity
        )
    }
}
