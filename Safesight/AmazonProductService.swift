//
//  AmazonProductService.swift
//  Safesight
//
//  Real Amazon product recommendations.
//  - Curated ASINs always available (title / image / Amazon dp link).
//  - Optional live enrich via RapidAPI "Real-Time Amazon Data"
//    (https://rapidapi.com/letscrape-6bRBa3QguO5/api/real-time-amazon-data)
//    Set AmazonProductConfig.rapidAPIKey to enable live price/title refresh.
//

import Combine
import Foundation
import UIKit

enum AmazonProductConfig {
    /// Paste a RapidAPI key to enable live Amazon product-details fetches.
    /// Leave empty to use curated Amazon ASIN catalog + CDN images.
    static var rapidAPIKey: String = ""
    static let rapidAPIHost = "real-time-amazon-data.p.rapidapi.com"
}

struct AmazonCatalogItem: Identifiable, Hashable {
    var id: String { asin }
    let asin: String
    let fallbackTitle: String
    let reason: String
    let icon: String
    let tags: [String] // match hazard keywords

    var productURL: URL {
        URL(string: "https://www.amazon.com/dp/\(asin)")!
    }

    /// Public Amazon image widget — works without an API key.
    var imageURL: URL {
        URL(string:
            "https://ws-na.amazon-adsystem.com/widgets/q?_encoding=UTF8&MarketPlace=US&ASIN=\(asin)&ServiceVersion=20070822&ID=AsinImage&WS=1&Format=_SL500_"
        )!
    }
}

enum AmazonCatalog {
    /// Real ASINs for common home-safety fixes.
    static let items: [AmazonCatalogItem] = [
        AmazonCatalogItem(
            asin: "B09TFCYDHY",
            fallbackTitle: "ToStair Non-Slip Stair Treads (15-Pack)",
            reason: "Peel-and-stick grip for loose or bare wood stairs.",
            icon: "figure.stairs",
            tags: ["stair", "runner", "trip", "carpet"]
        ),
        AmazonCatalogItem(
            asin: "B07X35CL1F",
            fallbackTitle: "Non-Slip Carpet Stair Treads (15pcs)",
            reason: "Soft indoor treads for elders, kids, and pets.",
            icon: "square.stack.3d.up.fill",
            tags: ["stair", "runner", "trip"]
        ),
        AmazonCatalogItem(
            asin: "B00DQFGH0R",
            fallbackTitle: "Amazon Basics 6-Outlet Surge Protector",
            reason: "Replace daisy-chained strips with one protected outlet strip.",
            icon: "bolt.fill",
            tags: ["outlet", "electric", "power", "surge", "cable"]
        ),
        AmazonCatalogItem(
            asin: "B07GFLP1C7",
            fallbackTitle: "Amazon Basics 8-Outlet Surge Protector Power Strip",
            reason: "Extra outlets with surge protection for desks and entertainment.",
            icon: "powerstrip.fill",
            tags: ["outlet", "electric", "power", "surge"]
        ),
        AmazonCatalogItem(
            asin: "B07S95Y6PC",
            fallbackTitle: "LEPOWER Motion Sensor Night Light (2-Pack)",
            reason: "Plug-in motion light for dark hallways and stair landings.",
            icon: "lightbulb.fill",
            tags: ["light", "hallway", "dim", "night"]
        ),
        AmazonCatalogItem(
            asin: "B08GJ9M8Y5",
            fallbackTitle: "eufy Security Motion Sensor Night Light",
            reason: "Battery motion light you can stick anywhere along a dark path.",
            icon: "sensor.fill",
            tags: ["light", "hallway", "motion", "dim"]
        ),
        AmazonCatalogItem(
            asin: "B07YQ4P8M4",
            fallbackTitle: "SimpleHouseware Over-the-Door Organizer",
            reason: "Clear floor clutter that blocks secondary exits.",
            icon: "door.left.hand.open",
            tags: ["exit", "blocked", "clutter", "storage", "path"]
        ),
        AmazonCatalogItem(
            asin: "B08CZQXK4V",
            fallbackTitle: "Cable Clips Cord Management (40pcs)",
            reason: "Route desk cables so outlets stay clear and trip-free.",
            icon: "cable.connector",
            tags: ["cable", "outlet", "trip", "clutter"]
        )
    ]

    static func matches(for hazards: [ScanHazardDTO]) -> [AmazonCatalogItem] {
        var scored: [(AmazonCatalogItem, Int)] = []
        for item in items {
            var score = 0
            for hazard in hazards {
                let hay = (hazard.title + " " + hazard.detail).lowercased()
                for tag in item.tags where hay.contains(tag) {
                    score += 2
                }
            }
            if score > 0 { scored.append((item, score)) }
        }
        let picked = scored.sorted { $0.1 > $1.1 }.map(\.0)
        if picked.isEmpty {
            return Array(items.prefix(3))
        }
        // Unique by ASIN, cap at 6
        var seen = Set<String>()
        var out: [AmazonCatalogItem] = []
        for item in picked where seen.insert(item.asin).inserted {
            out.append(item)
            if out.count >= 6 { break }
        }
        return out
    }
}

@MainActor
final class AmazonProductService: ObservableObject {
    static let shared = AmazonProductService()

    @Published private(set) var cache: [String: ScanProductDTO] = [:]

    func products(for hazards: [ScanHazardDTO]) async -> [ScanProductDTO] {
        let seeds = AmazonCatalog.matches(for: hazards)
        var results: [ScanProductDTO] = []
        for seed in seeds {
            if let live = await fetchDetails(asin: seed.asin) {
                var merged = live
                merged.reason = seed.reason
                merged.icon = seed.icon
                cache[seed.asin] = merged
                results.append(merged)
            } else if let cached = cache[seed.asin] {
                results.append(cached)
            } else {
                let dto = ScanProductDTO(
                    name: seed.fallbackTitle,
                    reason: seed.reason,
                    priceLabel: "View on Amazon",
                    icon: seed.icon,
                    imageName: nil,
                    imageURL: seed.imageURL.absoluteString,
                    productURL: seed.productURL.absoluteString,
                    asin: seed.asin
                )
                cache[seed.asin] = dto
                results.append(dto)
            }
        }
        return results
    }

    /// Live enrich via RapidAPI when a key is configured.
    private func fetchDetails(asin: String) async -> ScanProductDTO? {
        let key = AmazonProductConfig.rapidAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        var components = URLComponents(string: "https://\(AmazonProductConfig.rapidAPIHost)/product-details")
        components?.queryItems = [
            URLQueryItem(name: "asin", value: asin),
            URLQueryItem(name: "country", value: "US")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(AmazonProductConfig.rapidAPIHost, forHTTPHeaderField: "x-rapidapi-host")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(RapidAmazonProductResponse.self, from: data)
            guard let product = decoded.data else { return nil }
            return ScanProductDTO(
                name: product.product_title ?? "Amazon product",
                reason: "",
                priceLabel: product.product_price.map { "\($0)" } ?? "View on Amazon",
                icon: "cart.fill",
                imageName: nil,
                imageURL: product.product_photo,
                productURL: product.product_url ?? "https://www.amazon.com/dp/\(asin)",
                asin: asin
            )
        } catch {
            return nil
        }
    }
}

private struct RapidAmazonProductResponse: Decodable {
    let data: RapidAmazonProduct?
}

private struct RapidAmazonProduct: Decodable {
    let product_title: String?
    let product_price: String?
    let product_photo: String?
    let product_url: String?
}
