import Foundation
import SwiftData

@Model
final class Rack {
    var name: String
    var orderIndex: Int
    var floorCount: Int
    var bottlesPerFloor: Int
    /// Custom floor names, indexed bottom-up; "" means the default "Floor N".
    var floorNames: [String]
    var cellar: Cellar?

    @Relationship(deleteRule: .nullify, inverse: \Wine.rack)
    var wines: [Wine]?

    init(
        name: String,
        orderIndex: Int,
        floorCount: Int = 6,
        bottlesPerFloor: Int = 8
    ) {
        self.name = name
        self.orderIndex = orderIndex
        self.floorCount = floorCount
        self.bottlesPerFloor = bottlesPerFloor
        self.floorNames = []
    }

    /// Display name of a shelf (0 = bottom shelf, shown as "Shelf 1").
    func floorName(_ index: Int) -> String {
        let custom = index < floorNames.count ? floorNames[index] : ""
        return custom.isEmpty ? "Shelf \(index + 1)" : custom
    }

    func customFloorName(_ index: Int) -> String {
        index < floorNames.count ? floorNames[index] : ""
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
