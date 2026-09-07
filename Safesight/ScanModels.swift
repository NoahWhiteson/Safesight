//
//  ScanModels.swift
//  Safesight
//
//  Codable request/response shapes for the scan pipeline.
//  Swap PlaceholderScanAnalyzer for a real HTTP client later — same types.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Geometry (normalized 0…1, top-left origin)

struct NormalizedRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func cgRect(in size: CGSize) -> CGRect {
        CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    /// Keep AI boxes precise. Only invent a rect when coords are missing / nonsense.
    static func sanitized(
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        index: Int,
        total: Int
    ) -> NormalizedRect {
        let missing = x == nil || y == nil || width == nil || height == nil
        var sx = x ?? 0
        var sy = y ?? 0
        var sw = width ?? 0
        var sh = height ?? 0

        // Model sometimes returns 0…100 percentages.
        if sx > 1 || sy > 1 || sw > 1 || sh > 1 {
            sx /= 100
            sy /= 100
            sw /= 100
            sh /= 100
        }

        sx = clamp01(sx)
        sy = clamp01(sy)
        sw = max(0, sw)
        sh = max(0, sh)

        let zeroed = sw < 0.01 || sh < 0.01
        let nearlyFull = sw > 0.95 && sh > 0.95
        if missing || zeroed || nearlyFull {
            return fallback(index: index, total: max(total, 1))
        }

        // Preserve tight boxes; only clamp so the rect stays on-canvas.
        sw = min(sw, 1 - sx)
        sh = min(sh, 1 - sy)
        if sw < 0.01 || sh < 0.01 {
            return fallback(index: index, total: max(total, 1))
        }
        return NormalizedRect(x: sx, y: sy, width: sw, height: sh)
    }

    /// Last-resort box when the model omitted usable coords — keep near center, lightly offset by index.
    static func fallback(index: Int, total: Int) -> NormalizedRect {
        let n = max(total, 1)
        let spread = min(0.18, 0.06 * Double(n - 1))
        let offset = (Double(index) - Double(n - 1) / 2) * (spread / max(Double(n - 1), 1))
        return NormalizedRect(
            x: clamp01(0.34 + offset),
            y: clamp01(0.36 + offset * 0.4),
            width: 0.28,
            height: 0.22
        )
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - AI wire format

struct ScanAnalysisRequest: Codable {
    var scanId: UUID
    var focusAreas: [String]
    var dwelling: String?
    /// Optional when the image is uploaded as multipart instead of inline base64.
    var imageBase64: String?
    /// 0.1…1.0 — how hard Gemini should dig for hazards.
    var aggressiveness: Double
    var maxHazards: Int

    init(
        scanId: UUID,
        focusAreas: [String],
        dwelling: String? = nil,
        imageBase64: String? = nil,
        aggressiveness: Double = 0.55,
        maxHazards: Int = 4
    ) {
        self.scanId = scanId
        self.focusAreas = focusAreas
        self.dwelling = dwelling
        self.imageBase64 = imageBase64
        self.aggressiveness = aggressiveness
        self.maxHazards = maxHazards
    }
}

struct ScanAnalysisResponse: Codable {
    var score: Int
    var summary: String
    var hazards: [ScanHazardDTO]
    var products: [ScanProductDTO]
    var nextSteps: [String]
}

enum HazardLifecycleStatus: String, Codable, CaseIterable, Hashable {
    case open
    case fixed
    case dismissed

    var isOpen: Bool { self == .open }

    var label: String {
        switch self {
        case .open: return "Open"
        case .fixed: return "Fixed"
        case .dismissed: return "Dismissed"
        }
    }
}

struct ScanHazardDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var severity: HazardSeverity
    var icon: String
    var boundingBox: NormalizedRect
    var fixSteps: [String]
    /// Matches `SafetyInterest.rawValue` for filtering on the Hazards tab.
    var focusArea: String?
    /// User lifecycle — open until Fixed or Dismissed.
    var status: HazardLifecycleStatus

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        severity: HazardSeverity,
        icon: String,
        boundingBox: NormalizedRect,
        fixSteps: [String],
        focusArea: String? = nil,
        status: HazardLifecycleStatus = .open
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.icon = icon
        self.boundingBox = boundingBox
        self.fixSteps = fixSteps
        self.focusArea = focusArea
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id, title, detail, severity, icon, boundingBox, fixSteps, focusArea, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decode(String.self, forKey: .detail)
        severity = try c.decode(HazardSeverity.self, forKey: .severity)
        icon = try c.decode(String.self, forKey: .icon)
        boundingBox = try c.decode(NormalizedRect.self, forKey: .boundingBox)
        fixSteps = try c.decode([String].self, forKey: .fixSteps)
        focusArea = try c.decodeIfPresent(String.self, forKey: .focusArea)
        status = try c.decodeIfPresent(HazardLifecycleStatus.self, forKey: .status) ?? .open
    }

    var focusInterest: SafetyInterest? {
        focusArea.flatMap { SafetyInterest(rawValue: $0) }
    }

    var isOpen: Bool { status.isOpen }
}

struct ScanProductDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var reason: String
    var priceLabel: String
    var icon: String
    /// Asset catalog name for card art (legacy / offline).
    var imageName: String?
    /// Remote product image URL.
    var imageURL: String?
    var productURL: String?
    var asin: String?
    /// Amazon search keywords for this fix (preferred over name alone).
    var searchQuery: String?

    init(
        id: UUID = UUID(),
        name: String,
        reason: String,
        priceLabel: String,
        icon: String,
        imageName: String? = nil,
        imageURL: String? = nil,
        productURL: String? = nil,
        asin: String? = nil,
        searchQuery: String? = nil
    ) {
        self.id = id
        self.name = name
        self.reason = reason
        self.priceLabel = priceLabel
        self.icon = icon
        self.imageName = imageName
        self.imageURL = imageURL
        self.productURL = productURL
        self.asin = asin
        self.searchQuery = searchQuery
    }
}

enum HazardSeverity: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .high: return Color(red: 0.92, green: 0.28, blue: 0.25)
        case .medium: return Color(red: 0.95, green: 0.62, blue: 0.12)
        case .low: return Color(red: 0.20, green: 0.68, blue: 0.45)
        }
    }
}

// MARK: - Persisted scan

struct ScanResult: Codable, Identifiable, Hashable {
    var id: UUID
    var createdAt: Date
    var imageFileName: String
    var score: Int
    var summary: String
    var hazards: [ScanHazardDTO]
    var products: [ScanProductDTO]
    var nextSteps: [String]
    /// Starred scans skip the 60-day auto-delete.
    var isStarred: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        imageFileName: String,
        score: Int,
        summary: String,
        hazards: [ScanHazardDTO],
        products: [ScanProductDTO],
        nextSteps: [String],
        isStarred: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.score = score
        self.summary = summary
        self.hazards = hazards
        self.products = products
        self.nextSteps = nextSteps
        self.isStarred = isStarred
    }

    init(id: UUID, imageFileName: String, response: ScanAnalysisResponse) {
        self.init(
            id: id,
            imageFileName: imageFileName,
            score: response.score,
            summary: response.summary,
            hazards: response.hazards,
            products: response.products,
            nextSteps: response.nextSteps,
            isStarred: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, imageFileName, score, summary, hazards, products, nextSteps, isStarred
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        imageFileName = try c.decode(String.self, forKey: .imageFileName)
        score = try c.decode(Int.self, forKey: .score)
        summary = try c.decode(String.self, forKey: .summary)
        hazards = try c.decode([ScanHazardDTO].self, forKey: .hazards)
        products = try c.decode([ScanProductDTO].self, forKey: .products)
        nextSteps = try c.decode([String].self, forKey: .nextSteps)
        isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
    }

    var openHazards: [ScanHazardDTO] {
        hazards.filter(\.isOpen)
    }

    var openHazardCount: Int { openHazards.count }

    var fixedHazardCount: Int {
        hazards.filter { $0.status == .fixed }.count
    }

    /// Recalculate score from remaining open hazards after lifecycle changes.
    mutating func recomputeScoreFromOpenHazards() {
        let open = openHazards
        if open.isEmpty {
            score = hazards.isEmpty ? score : max(score, 94)
            return
        }
        let high = open.filter { $0.severity == .high }.count
        let medium = open.filter { $0.severity == .medium }.count
        let low = open.filter { $0.severity == .low }.count
        score = max(18, min(98, 100 - high * 18 - medium * 10 - low * 4))
    }
}

// MARK: - Placeholder AI payload

enum ScanPlaceholderPayload {
    static func response() -> ScanAnalysisResponse {
        ScanAnalysisResponse(
            score: 72,
            summary: "A few fixable issues showed up in this frame. Address the high-severity items first.",
            hazards: [
                ScanHazardDTO(
                    title: "Loose stair runner",
                    detail: "Carpet edge is lifting near the top step — trip risk on descent.",
                    severity: .high,
                    icon: "figure.stairs",
                    boundingBox: NormalizedRect(x: 0.18, y: 0.42, width: 0.38, height: 0.28),
                    fixSteps: [
                        "Lift the loose edge and vacuum grit from under the runner.",
                        "Apply double-sided stair tape or non-slip treads along each step.",
                        "Press firmly and test the stair with a slow walk-down."
                    ],
                    focusArea: SafetyInterest.stairs.rawValue
                ),
                ScanHazardDTO(
                    title: "Overloaded outlet",
                    detail: "Power strip daisy-chained under the desk with visible cable clutter.",
                    severity: .medium,
                    icon: "bolt.fill",
                    boundingBox: NormalizedRect(x: 0.58, y: 0.55, width: 0.28, height: 0.22),
                    fixSteps: [
                        "Unplug the daisy-chained strip immediately.",
                        "Consolidate devices onto one surge-protected strip.",
                        "Route cables with clips so the outlet stays clear."
                    ],
                    focusArea: SafetyInterest.electric.rawValue
                ),
                ScanHazardDTO(
                    title: "Blocked secondary exit",
                    detail: "Tall plant and storage bins narrow the path to the back door.",
                    severity: .medium,
                    icon: "door.left.hand.open",
                    boundingBox: NormalizedRect(x: 0.62, y: 0.12, width: 0.30, height: 0.40),
                    fixSteps: [
                        "Move bins and the plant at least 36\" off the exit path.",
                        "Keep the door swing fully clear.",
                        "Recheck the route with lights off."
                    ],
                    focusArea: SafetyInterest.blocked.rawValue
                ),
                ScanHazardDTO(
                    title: "Dim hallway lighting",
                    detail: "Single bulb leaves a dark stretch between rooms after dusk.",
                    severity: .low,
                    icon: "lightbulb.fill",
                    boundingBox: NormalizedRect(x: 0.35, y: 0.08, width: 0.22, height: 0.16),
                    fixSteps: [
                        "Swap in a higher-lumen bulb (800+ lm).",
                        "Add a plug-in motion light for overnight coverage.",
                        "Confirm both ends of the hallway are lit."
                    ],
                    focusArea: SafetyInterest.nightLighting.rawValue
                )
            ],
            products: [], // filled by AmazonProductService after analyze
            nextSteps: [
                "Secure or replace the stair runner before the next high-traffic day.",
                "Unplug the daisy chain and consolidate into one surge strip.",
                "Clear 36\" of path to the secondary exit.",
                "Add a motion light or brighter bulb in the hallway."
            ]
        )
    }
}
