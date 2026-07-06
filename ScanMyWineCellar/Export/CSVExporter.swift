import Foundation

/// Builds a spreadsheet-friendly CSV of the cellar and writes it to a
/// temporary file for the share sheet.
enum CSVExporter {
    static func export(_ wines: [Wine], cellarName: String = "MyWineCellar") throws -> URL {
        var lines = ["Cellar,Name,Producer,Vintage,Color,Region,Country,Appellation,Grape Varieties,Quantity,Notes,Date Added"]
        let dateFormatter = ISO8601DateFormatter()
        for wine in wines {
            let fields = [
                wine.cellar?.name ?? cellarName,
                wine.name,
                wine.producer,
                wine.vintage > 0 ? String(wine.vintage) : "NV",
                wine.color.label,
                wine.region,
                wine.country,
                wine.appellation,
                wine.grapeVarieties,
                String(wine.quantity),
                wine.notes,
                dateFormatter.string(from: wine.dateAdded),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        let csv = lines.joined(separator: "\r\n")

        let safeName = String(cellarName.map { $0.isLetter || $0.isNumber ? $0 : "-" })
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(Self.fileDateStamp()).csv")
        // Prepend a BOM so Excel opens the file as UTF-8.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csv.data(using: .utf8) ?? Data())
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func fileDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
