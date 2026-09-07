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
        return result
    }

    func delete(_ result: ScanResult) {
        let url = folderURL.appendingPathComponent(result.imageFileName)
        try? FileManager.default.removeItem(at: url)
        scans.removeAll { $0.id == result.id }
        persistIndex()
    }

    private func persistIndex() {
        if let data = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(data, forKey: indexKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let decoded = try? JSONDecoder().decode([ScanResult].self, from: data) else {
            scans = []
            return
        }
        scans = decoded.sorted { $0.createdAt > $1.createdAt }
    }
}
