//
//  AmazonProductService.swift
//  Safesight
//
//  Picks products that actually match each hazard (no junk fallback),
//  links to Amazon search, and loads a real product-style thumbnail.
//

import Combine
import Foundation
import UIKit

/// Paste your Amazon Associates tracking ID after approval (e.g. `safesight-20`).
/// Leave empty until approved — links still work, they just won’t pay you.
enum AmazonAssociatesConfig {
    static var associateTag: String = ""
}

struct AmazonCatalogItem: Identifiable, Hashable {
    var id: String { searchQuery }
    let fallbackTitle: String
    let searchQuery: String
    let reason: String
    let icon: String
    /// At least one of these must appear in the hazard text.
    let requiredAny: [String]
    let boostTags: [String]

    var productURL: URL { Self.amazonSearchURL(query: searchQuery) }
    var imageURL: URL { Self.productImageURL(query: searchQuery) }

    static func amazonSearchURL(query: String) -> URL {
        var components = URLComponents(string: "https://www.amazon.com/s")!
        var items = [URLQueryItem(name: "k", value: query)]
        let tag = AmazonAssociatesConfig.associateTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty {
            items.append(URLQueryItem(name: "tag", value: tag))
        }
        components.queryItems = items
        return components.url!
    }

    /// Bing image thumb — real JPEG for the shopping query (Amazon widget host is dead).
    static func productImageURL(query: String) -> URL {
        var components = URLComponents(string: "https://www.bing.com/th")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "w", value: "400"),
            URLQueryItem(name: "h", value: "400"),
            URLQueryItem(name: "c", value: "7"),
            URLQueryItem(name: "rs", value: "1"),
            URLQueryItem(name: "p", value: "0"),
            URLQueryItem(name: "pid", value: "1.7")
        ]
        return components.url!
    }
}

enum AmazonCatalog {
    static let items: [AmazonCatalogItem] = [
        AmazonCatalogItem(
            fallbackTitle: "Furniture Anti-Tip Straps",
            searchQuery: "furniture anti tip straps bookcase wall anchor",
            reason: "Anchors tall furniture so it can't tip over.",
            icon: "screwdriver",
            requiredAny: [
                "bookshelf", "bookcase", "dresser", "cabinet", "furniture",
                "unanchored", "anchor", "tip-over", "tipping", "tall shelf",
                "armoire", "tv stand", "not secured", "not anchored"
            ],
            boostTags: ["child", "quake", "wall", "tip"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Non-Slip Stair Treads",
            searchQuery: "non slip stair treads indoor peel and stick",
            reason: "Adds grip on loose or bare stairs.",
            icon: "figure.stairs",
            requiredAny: ["stair", "steps", "tread", "banister", "handrail"],
            boostTags: ["trip", "slip", "fall"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Surge Protector Power Strip",
            searchQuery: "surge protector power strip",
            reason: "Replace daisy-chained outlets safely.",
            icon: "bolt.fill",
            requiredAny: ["outlet", "electric", "power strip", "surge", "extension cord", "daisy"],
            boostTags: ["cable", "plug", "overloaded"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Motion Sensor Night Light",
            searchQuery: "motion sensor night light plug in hallway",
            reason: "Lights dark paths automatically.",
            icon: "lightbulb.fill",
            requiredAny: ["dark", "night light", "hallway light", "dim hallway", "poor lighting"],
            boostTags: ["motion", "light", "hallway"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Over-the-Door Organizer",
            searchQuery: "over the door organizer storage clear clutter",
            reason: "Clears clutter blocking exits.",
            icon: "door.left.hand.open",
            requiredAny: ["blocked exit", "blocked door", "egress", "path blocked", "clutter blocking"],
            boostTags: ["exit", "doorway"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Cable Management Clips",
            searchQuery: "cable clips cord management adhesive",
            reason: "Keeps cords off the floor.",
            icon: "cable.connector",
            requiredAny: ["cord", "cable across", "loose cable", "wire on floor", "trip hazard cord"],
            boostTags: ["trip", "clutter"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Child Safety Outlet Covers",
            searchQuery: "child proof outlet covers safety caps",
            reason: "Covers unused outlets for kids.",
            icon: "figure.and.child.holdinghands",
            requiredAny: ["child", "outlet cover", "baby proof", "kid", "toddler"],
            boostTags: ["outlet", "electric", "proof"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Smoke / CO Detector",
            searchQuery: "combination smoke and carbon monoxide detector",
            reason: "Detects fire and CO early.",
            icon: "flame.fill",
            requiredAny: ["smoke", "detector", "fire alarm", "carbon monoxide", "co alarm"],
            boostTags: ["fire"]
        ),
        AmazonCatalogItem(
            fallbackTitle: "Doorway Baby Gate",
            searchQuery: "pressure mount baby safety gate doorway",
            reason: "Blocks stairs or rooms for toddlers.",
            icon: "rectangle.split.2x1",
            requiredAny: ["baby gate", "stair gate", "child gate", "toddler access"],
            boostTags: ["child", "stair"]
        )
    ]

    /// Strict match — return nothing rather than unrelated junk.
    static func matches(for hazards: [ScanHazardDTO]) -> [AmazonCatalogItem] {
        guard !hazards.isEmpty else { return [] }

        var scored: [(AmazonCatalogItem, Int)] = []
        for item in items {
            var score = 0
            for hazard in hazards {
                let hay = (
                    hazard.title + " " + hazard.detail + " " + (hazard.focusArea ?? "")
                ).lowercased()

                guard item.requiredAny.contains(where: { hay.contains($0.lowercased()) }) else {
                    continue
                }
                score += 10
                for tag in item.boostTags where hay.contains(tag.lowercased()) {
                    score += 2
                }
            }
            if score > 0 { scored.append((item, score)) }
        }

        var seen = Set<String>()
        var out: [AmazonCatalogItem] = []
        for item in scored.sorted(by: { $0.1 > $1.1 }).map(\.0) where seen.insert(item.id).inserted {
            out.append(item)
            if out.count >= 4 { break }
        }
        return out
    }

    static func products(for hazards: [ScanHazardDTO]) -> [ScanProductDTO] {
        matches(for: hazards).map(dto(from:))
    }

    static func dto(from item: AmazonCatalogItem) -> ScanProductDTO {
        ScanProductDTO(
            id: UUID(uuidString: SeedUUID.stable(from: item.searchQuery)) ?? UUID(),
            name: item.fallbackTitle,
            reason: item.reason,
            priceLabel: "Shop on Amazon",
            icon: item.icon,
            imageName: nil,
            imageURL: item.imageURL.absoluteString,
            productURL: item.productURL.absoluteString,
            asin: nil,
            searchQuery: item.searchQuery
        )
    }

    static func enrichSuggestion(name: String, searchQuery: String?, reason: String, icon: String?) -> ScanProductDTO {
        let q = (searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? name
        return ScanProductDTO(
            id: UUID(uuidString: SeedUUID.stable(from: q)) ?? UUID(),
            name: name.trimmedProduct(to: 42),
            reason: reason.trimmedProduct(to: 70),
            priceLabel: "Shop on Amazon",
            icon: (icon?.isEmpty == false) ? icon! : "cart.fill",
            imageName: nil,
            imageURL: AmazonCatalogItem.productImageURL(query: q).absoluteString,
            productURL: AmazonCatalogItem.amazonSearchURL(query: q).absoluteString,
            asin: nil,
            searchQuery: q
        )
    }

    static func isUnusableImageURL(_ raw: String?) -> Bool {
        guard let raw, let host = URL(string: raw)?.host?.lowercased() else { return true }
        return host.contains("amazon-adsystem")
    }
}

enum SeedUUID {
    static func stable(from string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let hex = String(format: "%016llx", hash)
        let a = String(hex.prefix(8))
        let b = String(hex.dropFirst(8).prefix(4))
        let c = "4" + String(hex.dropFirst(12).prefix(3))
        let d = "a" + String(hex.prefix(3))
        let e = String((hex + hex).prefix(12))
        return "\(a)-\(b)-\(c)-\(d)-\(e)"
    }
}

private extension String {
    func trimmedProduct(to max: Int) -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let end = t.index(t.startIndex, offsetBy: max - 1)
        return String(t[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

@MainActor
final class AmazonProductService: ObservableObject {
    static let shared = AmazonProductService()

    /// Prefer Gemini suggestions when present; otherwise strict catalog match.
    func products(
        for hazards: [ScanHazardDTO],
        suggested: [ScanProductDTO] = []
    ) async -> [ScanProductDTO] {
        let fromGemini = suggested.compactMap { seed -> ScanProductDTO? in
            let name = seed.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return AmazonCatalog.enrichSuggestion(
                name: name,
                searchQuery: seed.searchQuery,
                reason: seed.reason,
                icon: seed.icon
            )
        }

        if !fromGemini.isEmpty {
            return Array(fromGemini.prefix(4))
        }
        return AmazonCatalog.products(for: hazards)
    }
}
