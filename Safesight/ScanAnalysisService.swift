//
//  ScanAnalysisService.swift
//  Safesight
//
//  Analyze a captured frame. Placeholder today; replace body of
//  RemoteScanAnalyzer with your API call — request/response types stay stable.
//

import Foundation
import UIKit

protocol ScanAnalyzing {
    func analyze(request: ScanAnalysisRequest, image: UIImage) async throws -> ScanAnalysisResponse
}

enum ScanAnalysisError: Error {
    case invalidResponse
    case network(Error)
}

/// Local mock — returns structured placeholder data with bounding boxes.
struct PlaceholderScanAnalyzer: ScanAnalyzing {
    var delayNanoseconds: UInt64 = 0

    func analyze(request: ScanAnalysisRequest, image: UIImage) async throws -> ScanAnalysisResponse {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        _ = request
        _ = image
        return ScanPlaceholderPayload.response()
    }
}

/// Skeleton for a future HTTPS endpoint. Wire `endpoint` + auth when ready.
struct RemoteScanAnalyzer: ScanAnalyzing {
    var endpoint: URL
    var session: URLSession = .shared

    func analyze(request: ScanAnalysisRequest, image: UIImage) async throws -> ScanAnalysisResponse {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw ScanAnalysisError.invalidResponse
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        if let meta = try? JSONEncoder().encode(request) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"meta\"\r\n")
            body.append("Content-Type: application/json\r\n\r\n")
            body.append(meta)
            body.append("\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpeg)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw ScanAnalysisError.invalidResponse
            }
            return try JSONDecoder().decode(ScanAnalysisResponse.self, from: data)
        } catch let error as ScanAnalysisError {
            throw error
        } catch {
            throw ScanAnalysisError.network(error)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum ScanAnalyzerFactory {
    /// Flip to `RemoteScanAnalyzer(endpoint:)` when the backend is live.
    static func make() -> any ScanAnalyzing {
        PlaceholderScanAnalyzer()
    }
}
