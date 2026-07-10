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

/// A storage unit detected in a photo of the cellar.
struct RackEstimate: Codable {
    let shelfCount: Int
    let bottlesPerShelf: Int
    let suggestedName: String

    enum CodingKeys: String, CodingKey {
        case shelfCount = "shelf_count"
        case bottlesPerShelf = "bottles_per_shelf"
        case suggestedName = "suggested_name"
    }
}

/// Talks to the Anthropic Messages API: identifies wines across photos and
/// estimates the physical structure (shelves, capacity) of the cellar.
struct WineScanService {
    static let model = "claude-opus-4-8"

    // MARK: - Wine identification

    private static let winesSystemPrompt = """
    You are a sommelier's assistant. You are given one or more photos of wine \
    bottles from a private cellar — either standing on racks or shelves, or \
    pulled out and laid together on a table or counter with labels facing up. \
    Identify every bottle whose label or capsule is readable enough to make a \
    confident or reasonable identification.

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

    private static let winesSchema: [String: Any] = [
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
        let text = try await Self.visionRequest(
            images: images,
            system: Self.winesSystemPrompt,
            userText: "Identify all the wine bottles in these \(images.count) photo(s) of my cellar.",
            schema: Self.winesSchema,
            apiKey: apiKey
        )
        guard let data = text.data(using: .utf8) else { throw WineScanError.emptyResponse }
        do {
            struct ScanResult: Codable { let wines: [ScannedWine] }
            return try JSONDecoder().decode(ScanResult.self, from: data).wines
        } catch {
            throw WineScanError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Cellar structure

    private static let structureSystemPrompt = """
    You are given a photo of wine storage — a wine cabinet (such as a EuroCave), \
    a wine fridge, or cellar racks. Identify each distinct storage unit visible \
    in the photo.

    For each unit:
    - Count its shelves (levels), from bottom to top. Count every level that \
    can hold bottles, including the bottom of the cabinet if bottles rest there.
    - Estimate how many bottles fit side by side on ONE shelf: use the widest \
    clearly visible shelf and count positions (slots), not just the bottles \
    currently present.
    - Suggest a short, friendly name, e.g. "EuroCave", "Wine fridge", \
    "Wall rack left".

    Only describe structure you can clearly see. If only part of a unit is \
    visible, estimate from the visible part.
    """

    private static let structureSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "racks": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "shelf_count": ["type": "integer", "description": "Number of shelf levels in this unit"],
                        "bottles_per_shelf": ["type": "integer", "description": "Bottle positions per shelf, front row only"],
                        "suggested_name": ["type": "string"],
                    ],
                    "required": ["shelf_count", "bottles_per_shelf", "suggested_name"],
                    "additionalProperties": false,
                ],
            ],
        ],
        "required": ["racks"],
        "additionalProperties": false,
    ]

    func analyzeStructure(image: UIImage, apiKey: String) async throws -> [RackEstimate] {
        let text = try await Self.visionRequest(
            images: [image],
            system: Self.structureSystemPrompt,
            userText: "Describe the wine storage in this photo.",
            schema: Self.structureSchema,
            apiKey: apiKey
        )
        guard let data = text.data(using: .utf8) else { throw WineScanError.emptyResponse }
        do {
            struct StructureResult: Codable { let racks: [RackEstimate] }
            return try JSONDecoder().decode(StructureResult.self, from: data).racks
        } catch {
            throw WineScanError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Shared plumbing

    /// Sends images + prompt with a JSON schema and returns the structured
    /// JSON text from the response.
    private static func visionRequest(
        images: [UIImage],
        system: String,
        userText: String,
        schema: [String: Any],
        apiKey: String
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw WineScanError.missingAPIKey }

        var content: [[String: Any]] = []
        for image in images {
            guard let jpeg = ImageProcessing.uploadJPEG(image) else {
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
        content.append(["type": "text", "text": userText])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": system,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": schema,
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

        guard let text = message.content.first(where: { $0.type == "text" })?.text else {
            throw WineScanError.emptyResponse
        }
        return text
    }

}

// MARK: - API response types

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
