//
//  ScanAnalysisService.swift
//  Safesight
//
//  Analyze a captured frame via the Safesight server API.
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

/// Calls Safesight server `POST /v1/analyze` (Gemini key stays on the server).
struct RemoteScanAnalyzer: ScanAnalyzing {
    var endpoint: URL = SafesightAPIConfig.analyzeURL
    var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    func analyze(request: ScanAnalysisRequest, image: UIImage) async throws -> ScanAnalysisResponse {
        let upright = image.normalizedUp()
        guard let jpeg = compressedJPEG(from: upright) else {
            throw ScanAnalysisError.invalidResponse
        }

        var meta = request
        meta.imageBase64 = nil

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let secret = SafesightAPIConfig.apiSecret
        guard !secret.isEmpty else {
            #if DEBUG
            print("Safesight API secret missing — copy SafesightAPISecrets.example.plist → SafesightAPISecrets.plist")
            #endif
            throw ScanAnalysisError.invalidResponse
        }
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")

        var body = Data()
        if let metaData = try? JSONEncoder().encode(meta) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"meta\"\r\n")
            body.append("Content-Type: application/json\r\n\r\n")
            body.append(metaData)
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
            guard let http = response as? HTTPURLResponse else {
                throw ScanAnalysisError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                #if DEBUG
                let message = String(data: data, encoding: .utf8) ?? ""
                print("Safesight API error \(http.statusCode): \(message.prefix(400))")
                #endif
                throw ScanAnalysisError.invalidResponse
            }
            return try JSONDecoder().decode(ScanAnalysisResponse.self, from: data).withSanitizedBoxes()
        } catch let error as ScanAnalysisError {
            throw error
        } catch {
            throw ScanAnalysisError.network(error)
        }
    }

    private func compressedJPEG(from image: UIImage, maxDimension: CGFloat = 1400) -> Data? {
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
        return scaled.jpegData(compressionQuality: 0.72)
            ?? scaled.jpegData(compressionQuality: 0.55)
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
    static func make() -> any ScanAnalyzing {
        RemoteScanAnalyzer()
    }
}
