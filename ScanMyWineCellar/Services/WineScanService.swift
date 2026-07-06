import Foundation
import UIKit

enum WineScanError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case apiError(String)
    case refused
    case truncated
    case emptyResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Add your Anthropic API key in Settings."
        case .imageEncodingFailed:
            return "Could not encode one of the photos."
        case .apiError(let message):
            return message
        case .refused:
            return "The request was declined by the model. Try different photos."
        case .truncated:
            return "The response was cut short. Try scanning fewer photos at once."
        case .emptyResponse:
            return "The model returned no result. Try again."
        case .decodingFailed(let message):
            return "Could not read the model's answer: \(message)"
        }
    }
}

/// Sends cellar photos to the Anthropic Messages API and returns the list of
/// wines identified across all photos, deduplicated by the model.
struct WineScanService {
    static let model = "claude-opus-4-8"

    /// Long edge target for uploaded photos. Claude reads labels fine at this
    /// size and it keeps each image well under the API's per-image limit.
    private static let maxImageDimension: CGFloat = 2048

    private static let systemPrompt = """
    You are a sommelier's assistant. You are given one or more photos of wine \
    bottles — typically several bottles per photo, on racks or shelves in a \
    private cellar. Identify every bottle whose label or capsule is readable \
    enough to make a confident or reasonable identification.

    Rules:
    - Group identical wines (same wine, same vintage) into a single entry and \
    set "quantity" to the number of bottles you can count across ALL photos.
    - The photos may overlap: if the same shelf appears in two photos, count \
    each physical bottle only once. When unsure whether two photos overlap, \
    prefer the lower count.
    - Use your wine knowledge to fill in region, country, appellation, grape \
    varieties, and color when the label makes the wine identifiable, even if \
    those details are not printed on the label.
    - Use an empty string for text fields you cannot determine, and 0 for an \
    unknown or non-vintage year.
    - "color" must be one of: red, white, rose, sparkling, dessert, fortified, \
    unknown.
    - Skip bottles that are completely unidentifiable (label fully hidden or \
    unreadable) rather than guessing blindly.
    """

    private static let outputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "wines": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Wine name as it would appear on a cellar list, without producer or vintage"],
                        "producer": ["type": "string"],
                        "vintage": ["type": "integer", "description": "Vintage year, 0 if unknown or non-vintage"],
                        "color": ["type": "string", "enum": ["red", "white", "rose", "sparkling", "dessert", "fortified", "unknown"]],
                        "region": ["type": "string"],
                        "country": ["type": "string"],
                        "grape_varieties": ["type": "string", "description": "Comma-separated grape varieties"],
                        "appellation": ["type": "string"],
                        "quantity": ["type": "integer", "description": "Number of bottles of this exact wine visible across all photos"],
                    ],
                    "required": ["name", "producer", "vintage", "color", "region", "country", "grape_varieties", "appellation", "quantity"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["wines"],
        "additionalProperties": false,
    ]

    func scan(images: [UIImage], apiKey: String) async throws -> [ScannedWine] {
        guard !apiKey.isEmpty else { throw WineScanError.missingAPIKey }

        var content: [[String: Any]] = []
        for image in images {
            guard let jpeg = Self.downscaledJPEG(image) else {
                throw WineScanError.imageEncodingFailed
            }
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpeg.base64EncodedString(),
                ],
            ])
        }
        content.append([
            "type": "text",
            "text": "Identify all the wine bottles in these \(images.count) photo(s) of my cellar.",
        ])

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "system": Self.systemPrompt,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": Self.outputSchema,
                ],
            ],
            "messages": [
                ["role": "user", "content": content],
            ],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 600
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WineScanError.apiError("Unexpected response from the API.")
        }
        guard http.statusCode == 200 else {
            if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw WineScanError.apiError("\(envelope.error.type): \(envelope.error.message)")
            }
            throw WineScanError.apiError("API request failed with status \(http.statusCode).")
        }

        let message = try JSONDecoder().decode(MessageResponse.self, from: data)

        switch message.stopReason {
        case "refusal":
            throw WineScanError.refused
        case "max_tokens":
            throw WineScanError.truncated
        default:
            break
        }

        guard let text = message.content.first(where: { $0.type == "text" })?.text,
              let jsonData = text.data(using: .utf8) else {
            throw WineScanError.emptyResponse
        }

        do {
            let result = try JSONDecoder().decode(ScanResult.self, from: jsonData)
            return result.wines
        } catch {
            throw WineScanError.decodingFailed(error.localizedDescription)
        }
    }

    private static func downscaledJPEG(_ image: UIImage) -> Data? {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxImageDimension else {
            return image.jpegData(compressionQuality: 0.75)
        }
        let scale = maxImageDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}

// MARK: - API response types

private struct ScanResult: Codable {
    let wines: [ScannedWine]
}

private struct MessageResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

private struct APIErrorEnvelope: Codable {
    struct APIError: Codable {
        let type: String
        let message: String
    }

    let error: APIError
}
