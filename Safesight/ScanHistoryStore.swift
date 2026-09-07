//
//  ScanHistoryStore.swift
//  Safesight
//

import Combine
import Foundation
import UIKit

@MainActor
final class ScanHistoryStore: ObservableObject {
    static let shared = ScanHistoryStore()

    /// Unstarred scans older than this are purged on launch / when gallery opens.
    static let retentionDays: Int = 60

    @Published private(set) var scans: [ScanResult] = []

    private let indexKey = "safesight.scanHistory.index"
    private let folderName = "Scans"

    private var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    init() {
        load()
        purgeExpired()
    }

    var latest: ScanResult? { scans.first }

    func image(for result: ScanResult) -> UIImage? {
        let url = folderURL.appendingPathComponent(result.imageFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    func save(image: UIImage, response: ScanAnalysisResponse, scanId: UUID = UUID()) -> ScanResult {
        let fileName = "\(scanId.uuidString).jpg"
        let url = folderURL.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.86) {
            try? data.write(to: url, options: .atomic)
        }

        let result = ScanResult(id: scanId, imageFileName: fileName, response: response)
        scans.insert(result, at: 0)
        persistIndex()
        syncInsights()
        return result
    }

    func delete(_ result: ScanResult) {
        delete(ids: [result.id])
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if let scan = scans.first(where: { $0.id == id }) {
                let url = folderURL.appendingPathComponent(scan.imageFileName)
                try? FileManager.default.removeItem(at: url)
            }
        }
        scans.removeAll { ids.contains($0.id) }
        persistIndex()
    }

    func setStarred(_ ids: Set<UUID>, starred: Bool) {
        guard !ids.isEmpty else { return }
        var changed = false
        for i in scans.indices where ids.contains(scans[i].id) {
            if scans[i].isStarred != starred {
                scans[i].isStarred = starred
                changed = true
            }
        }
        if changed { persistIndex() }
    }

    func toggleStarred(_ result: ScanResult) {
        setStarred([result.id], starred: !result.isStarred)
    }

    @discardableResult
    func setHazardStatus(
        scanID: UUID,
        hazardID: UUID,
        status: HazardLifecycleStatus
    ) -> ScanResult? {
        guard let index = scans.firstIndex(where: { $0.id == scanID }),
              let hIndex = scans[index].hazards.firstIndex(where: { $0.id == hazardID })
        else { return nil }

        scans[index].hazards[hIndex].status = status
        scans[index].recomputeScoreFromOpenHazards()
        persistIndex()
        syncInsights()
        return scans[index]
    }

    /// Open (non-low) hazards across all saved scans — drives Home metrics.
    var totalOpenActionableHazards: Int {
        scans
            .flatMap(\.hazards)
            .filter { $0.isOpen && $0.severity != .low }
            .count
    }

    func syncInsights() {
        let open = totalOpenActionableHazards
        let score = scans.first?.score ?? SubscriptionStore.shared.houseScore
        let summary = scans.first?.summary ?? SubscriptionStore.shared.aiSummary ?? ""
        SubscriptionStore.shared.applyScanInsights(
            score: score,
            openHazards: open,
            summary: summary
        )
    }

    /// Drops unstarred scans older than `retentionDays`.
    @discardableResult
    func purgeExpired(now: Date = Date()) -> Int {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: now
        ) ?? now.addingTimeInterval(-TimeInterval(Self.retentionDays * 86_400))

        let expired = scans.filter { !$0.isStarred && $0.createdAt < cutoff }
        guard !expired.isEmpty else { return 0 }
        delete(ids: Set(expired.map(\.id)))
        syncInsights()
        return expired.count
    }

    private func persistIndex() {
        if let data = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(data, forKey: indexKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              var decoded = try? JSONDecoder().decode([ScanResult].self, from: data) else {
            scans = []
            return
        }
        // Refresh products so old amazon-adsystem / ASIN cards never render again.
        for i in decoded.indices {
            decoded[i].products = AmazonCatalog.products(for: decoded[i].hazards)
        }
        scans = decoded.sorted { $0.createdAt > $1.createdAt }
        persistIndex()
        syncInsights()
    }
}
