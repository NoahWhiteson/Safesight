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
}

// MARK: - AI wire format

struct ScanAnalysisRequest: Codable {
    var scanId: UUID
    var focusAreas: [String]
    var dwelling: String?
    /// Optional when the image is uploaded as multipart instead of inline base64.
    var imageBase64: String?
}

struct ScanAnalysisResponse: Codable {
    var score: Int
    var summary: String
    var hazards: [ScanHazardDTO]
    var products: [ScanProductDTO]
    var nextSteps: [String]
}

struct ScanHazardDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var severity: HazardSeverity
    var icon: String
    var boundingBox: NormalizedRect
    var fixSteps: [String]

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        severity: HazardSeverity,
        icon: String,
        boundingBox: NormalizedRect,
        fixSteps: [String]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.icon = icon
        self.boundingBox = boundingBox
        self.fixSteps = fixSteps
    }
}

struct ScanProductDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var reason: String
    var priceLabel: String
    var icon: String
    /// Asset catalog name for card art (Home-style cards).
    var imageName: String?
    var productURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        reason: String,
        priceLabel: String,
        icon: String,
        imageName: String? = nil,
        productURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.reason = reason
        self.priceLabel = priceLabel
        self.icon = icon
        self.imageName = imageName
        self.productURL = productURL
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

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        imageFileName: String,
        score: Int,
        summary: String,
        hazards: [ScanHazardDTO],
        products: [ScanProductDTO],
        nextSteps: [String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.score = score
        self.summary = summary
        self.hazards = hazards
        self.products = products
        self.nextSteps = nextSteps
    }

    init(id: UUID, imageFileName: String, response: ScanAnalysisResponse) {
        self.init(
            id: id,
            imageFileName: imageFileName,
            score: response.score,
            summary: response.summary,
            hazards: response.hazards,
            products: response.products,
            nextSteps: response.nextSteps
        )
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
                    ]
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
                    ]
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
                    ]
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
                    ]
                )
            ],
            products: [
                ScanProductDTO(
                    name: "Non-slip stair treads",
                    reason: "Secures loose runners and adds grip on steps.",
                    priceLabel: "From $18",
                    icon: "square.stack.3d.up.fill",
                    imageName: "HazardTape"
                ),
                ScanProductDTO(
                    name: "Surge-protected power strip",
                    reason: "Replaces daisy-chained outlets with a safer single strip.",
                    priceLabel: "From $24",
                    icon: "powerstrip.fill",
                    imageName: "HazardPipes"
                ),
                ScanProductDTO(
                    name: "Motion hallway light",
                    reason: "Fills the dark stretch without a full fixture swap.",
                    priceLabel: "From $15",
                    icon: "sensor.fill",
                    imageName: "HazardGood"
                )
            ],
            nextSteps: [
                "Secure or replace the stair runner before the next high-traffic day.",
                "Unplug the daisy chain and consolidate into one surge strip.",
                "Clear 36\" of path to the secondary exit.",
                "Add a motion light or brighter bulb in the hallway."
            ]
        )
    }
}
