//
//  GeminiScanAnalyzer.swift
//  Safesight
//
//  Sends the captured room photo + selected focus areas to Gemini and
//  parses a structured ScanAnalysisResponse.
//

import Foundation
import UIKit

enum GeminiScanPrompt {
    static let system = """
    You are Safesight, a residential home-safety vision analyst.

    JOB
    Find ONLY hazards in the user’s selected Focus Areas. Ignore everything else.

    HARD RULES
    1. focusArea on each hazard MUST exactly match one selected Focus Area string.
    2. Do not invent unseen hazards. If none apply, return hazards: [] and a short summary.
    3. Camera-visible issues only (no gas/CO/radon/invisible risks).
    4. Bounding boxes: normalized 0…1, origin top-left, tight crop, stay in bounds.
    5. Severity: High = immediate injury/fire/egress; Medium = fix soon; Low = minor.
    6. score: 0–100 for THIS frame vs selected focus areas only.
    7. icon: short SF Symbol name (bolt.fill, figure.stairs, lightbulb.fill, etc.).
    8. Recommend ONLY products that fix the listed hazards (e.g. anti-tip straps for unanchored bookshelf — never stair treads unless stairs are the hazard).
    9. JSON only — no markdown.

    STRICT LENGTH LIMITS (never exceed)
    - summary: max 110 characters, 1 sentence
    - title: max 36 characters
    - detail: max 90 characters, 1 sentence
    - fixSteps: exactly 2 steps, each max 70 characters
    - nextSteps: max 3 items, each max 70 characters
    - hazards: max 4 total
    - products: max 3; each must map to a listed hazard
    Prefer blunt, plain language. No filler.

    OUTPUT SCHEMA
    {
      "score": number,
      "summary": string,
      "hazards": [
        {
          "title": string,
          "detail": string,
          "severity": "High" | "Medium" | "Low",
          "icon": string,
          "focusArea": string,
          "boundingBox": { "x": number, "y": number, "width": number, "height": number },
          "fixSteps": [string, string]
        }
      ],
      "products": [
        {
          "name": string,
          "searchQuery": string,
          "reason": string,
          "icon": string
        }
      ],
      "nextSteps": [string]
    }
    """

    static func userPrompt(focusAreas: [String], dwelling: String?) -> String {
        let areas = focusAreas.isEmpty
            ? "(none selected — return empty hazards)"
            : focusAreas.map { "- \($0)" }.joined(separator: "\n")
        let home = dwelling ?? "unknown dwelling type"
        return """
        Analyze this photo for Safesight. Keep all text short per length limits.

        Dwelling: \(home)

        Focus Areas ONLY:
        \(areas)
        """
    }
}

struct GeminiScanAnalyzer: ScanAnalyzing {
    var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = true
        // Prefer HTTP/2 over flaky QUIC paths on some Wi‑Fi / cellular handoffs.
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }()

    func analyze(request: ScanAnalysisRequest, image: UIImage) async throws -> ScanAnalysisResponse {
        guard let jpeg = Self.compressedJPEG(from: image) else {
            throw ScanAnalysisError.invalidResponse
        }

        let focusAreas = request.focusAreas
        let body = GeminiGenerateRequest(
            systemInstruction: .init(parts: [.init(text: GeminiScanPrompt.system)]),
            contents: [
                .init(role: "user", parts: [
                    .init(text: GeminiScanPrompt.userPrompt(
                        focusAreas: focusAreas,
                        dwelling: request.dwelling
                    )),
                    .init(inlineData: .init(
                        mimeType: "image/jpeg",
                        data: jpeg.base64EncodedString()
                    ))
                ])
            ],
            generationConfig: .init(
                temperature: 0.2,
                responseMimeType: "application/json",
                thinkingConfig: .init(thinkingLevel: "LOW")
            )
        )

        let payload = try JSONEncoder().encode(body)
        var lastError: Error?

        // Retry transient drops (-1005 / -1001) — common with large multimodal POSTs.
        for attempt in 1...3 {
            var urlRequest = URLRequest(url: GeminiConfig.generateContentURL)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.timeoutInterval = 60
            urlRequest.httpBody = payload

            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw ScanAnalysisError.invalidResponse
                }

                guard (200...299).contains(http.statusCode) else {
                    #if DEBUG
                    let message = String(data: data, encoding: .utf8) ?? ""
                    print("Gemini error \(http.statusCode): \(message.prefix(500))")
                    #endif
                    // 429 / 5xx — retry
                    if http.statusCode == 429 || (500...599).contains(http.statusCode), attempt < 3 {
                        try await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
                        continue
                    }
                    throw ScanAnalysisError.invalidResponse
                }

                let envelope = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
                guard let text = envelope.firstText else {
                    throw ScanAnalysisError.invalidResponse
                }

                let cleaned = Self.stripCodeFences(text)
                guard let jsonData = cleaned.data(using: .utf8) else {
                    throw ScanAnalysisError.invalidResponse
                }

                let parsed = try JSONDecoder().decode(GeminiScanPayload.self, from: jsonData)
                return parsed.toScanAnalysisResponse(allowedFocusAreas: Set(focusAreas))
            } catch let error as ScanAnalysisError {
                throw error
            } catch {
                lastError = error
                let ns = error as NSError
                let retryable = ns.domain == NSURLErrorDomain && [
                    NSURLErrorTimedOut,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorCannotConnectToHost
                ].contains(ns.code)
                if retryable, attempt < 3 {
                    #if DEBUG
                    print("Gemini network retry \(attempt): \(ns.code)")
                    #endif
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 600_000_000)
                    continue
                }
                throw ScanAnalysisError.network(error)
            }
        }

        throw ScanAnalysisError.network(lastError ?? URLError(.unknown))
    }

    /// Downscale + compress so multimodal POSTs survive flaky Wi‑Fi.
    private static func compressedJPEG(from image: UIImage, maxDimension: CGFloat = 1280) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scaled: UIImage
        if longest > maxDimension {
            let scale = maxDimension / longest
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: target)
            scaled = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            scaled = image
        }
        return scaled.jpegData(compressionQuality: 0.55)
            ?? scaled.jpegData(compressionQuality: 0.4)
    }

    private static func stripCodeFences(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
            text = text.replacingOccurrences(of: "```", with: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}

// MARK: - Request / response DTOs

private struct GeminiGenerateRequest: Encodable {
    var systemInstruction: GeminiContent
    var contents: [GeminiContent]
    var generationConfig: GeminiGenerationConfig

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig = "generation_config"
    }
}

private struct GeminiContent: Encodable {
    var role: String?
    var parts: [GeminiPart]

    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(parts, forKey: .parts)
    }

    enum CodingKeys: String, CodingKey {
        case role, parts
    }
}

private struct GeminiPart: Encodable {
    var text: String?
    var inlineData: GeminiInlineData?

    init(text: String) {
        self.text = text
    }

    init(inlineData: GeminiInlineData) {
        self.inlineData = inlineData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(inlineData, forKey: .inlineData)
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GeminiInlineData: Encodable {
    var mimeType: String
    var data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiGenerationConfig: Encodable {
    var temperature: Double
    var responseMimeType: String
    var thinkingConfig: GeminiThinkingConfig?

    enum CodingKeys: String, CodingKey {
        case temperature
        case responseMimeType = "response_mime_type"
        case thinkingConfig = "thinking_config"
    }
}

private struct GeminiThinkingConfig: Encodable {
    var thinkingLevel: String

    enum CodingKeys: String, CodingKey {
        case thinkingLevel = "thinking_level"
    }
}

private struct GeminiGenerateResponse: Decodable {
    var candidates: [Candidate]?

    struct Candidate: Decodable {
        var content: Content?
    }

    struct Content: Decodable {
        var parts: [Part]?
    }

    struct Part: Decodable {
        var text: String?
    }

    var firstText: String? {
        candidates?.first?.content?.parts?.compactMap(\.text).first
    }
}

private struct GeminiScanPayload: Decodable {
    var score: Int?
    var summary: String?
    var hazards: [Hazard]?
    var products: [Product]?
    var nextSteps: [String]?

    struct Hazard: Decodable {
        var title: String?
        var detail: String?
        var severity: String?
        var icon: String?
        var focusArea: String?
        var boundingBox: Box?
        var fixSteps: [String]?
    }

    struct Product: Decodable {
        var name: String?
        var searchQuery: String?
        var reason: String?
        var icon: String?
    }

    struct Box: Decodable {
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
    }

    func toScanAnalysisResponse(allowedFocusAreas: Set<String>) -> ScanAnalysisResponse {
        let allowed = allowedFocusAreas
        let mappedHazards: [ScanHazardDTO] = (hazards ?? []).compactMap { h in
            guard let title = h.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                return nil
            }
            let focus = h.focusArea?.trimmingCharacters(in: .whitespacesAndNewlines)
            if !allowed.isEmpty {
                guard let focus, allowed.contains(focus) else { return nil }
            }

            let severity = HazardSeverity(rawValue: h.severity ?? "") ?? .medium
            let box = h.boundingBox
            let normalized = NormalizedRect(
                x: clamp01(box?.x ?? 0.1),
                y: clamp01(box?.y ?? 0.1),
                width: clamp01(box?.width ?? 0.2),
                height: clamp01(box?.height ?? 0.2)
            )

            let icon = (h.icon?.isEmpty == false) ? h.icon! : defaultIcon(for: focus)
            let steps = (h.fixSteps ?? [])
                .map { $0.trimmed(to: 70) }
                .filter { !$0.isEmpty }
            let clampedSteps = Array((steps.isEmpty ? ["Inspect and fix this issue."] : steps).prefix(2))

            return ScanHazardDTO(
                title: title.trimmed(to: 36),
                detail: (h.detail ?? "").trimmed(to: 90),
                severity: severity,
                icon: icon,
                boundingBox: normalized,
                fixSteps: clampedSteps,
                focusArea: focus
            )
        }

        let limitedHazards = Array(mappedHazards.prefix(4))
        let score = min(100, max(0, score ?? (limitedHazards.isEmpty ? 92 : 70)))
        let summaryText = (summary ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? (limitedHazards.isEmpty
                ? "No issues found in your selected focus areas."
                : "Found \(limitedHazards.count) issue\(limitedHazards.count == 1 ? "" : "s") in your focus areas.")

        let steps = Array((nextSteps ?? []).map { $0.trimmed(to: 70) }.filter { !$0.isEmpty }.prefix(3))

        let mappedProducts: [ScanProductDTO] = (products ?? []).compactMap { p in
            guard let name = p.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            return ScanProductDTO(
                name: name.trimmed(to: 42),
                reason: (p.reason ?? "").trimmed(to: 70),
                priceLabel: "Shop on Amazon",
                icon: (p.icon?.isEmpty == false) ? p.icon! : "cart.fill",
                searchQuery: p.searchQuery?.trimmed(to: 80)
            )
        }

        return ScanAnalysisResponse(
            score: score,
            summary: summaryText.trimmed(to: 110),
            hazards: limitedHazards,
            products: Array(mappedProducts.prefix(3)),
            nextSteps: steps
        )
    }

    private func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func defaultIcon(for focus: String?) -> String {
        SafetyInterest(rawValue: focus ?? "")?.icon ?? "exclamationmark.triangle.fill"
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func trimmed(to max: Int) -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let end = t.index(t.startIndex, offsetBy: max - 1)
        return String(t[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
