//
//  VideoScanPipeline.swift
//  Safesight
//

import AVFoundation
import Foundation
import UIKit

enum VideoScanPipeline {
    static let maxRecordSeconds: TimeInterval = 15
    static let thumbnailCount = 24

    static func sampleThumbnails(from videoURL: URL, count: Int = thumbnailCount) -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0.1 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 384, height: 384)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        let n = max(1, count)
        var images: [UIImage] = []
        for i in 0..<n {
            let t = duration * (Double(i) + 0.5) / Double(n)
            let time = CMTime(seconds: t, preferredTimescale: 600)
            guard let cg = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            images.append(UIImage(cgImage: cg))
        }
        return images
    }

    static func fullFrame(from videoURL: URL, at index: Int, sampleCount: Int = thumbnailCount) -> UIImage? {
        let thumbs = sampleThumbnails(from: videoURL, count: sampleCount)
        guard thumbs.indices.contains(index) else { return thumbs.first }
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.seconds
        guard duration.isFinite, duration > 0.1 else { return thumbs[index] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1920, height: 1920)

        let n = max(1, sampleCount)
        let t = duration * (Double(index) + 0.5) / Double(n)
        let time = CMTime(seconds: t, preferredTimescale: 600)
        guard let cg = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return thumbs[index]
        }
        return UIImage(cgImage: cg).normalizedUp()
    }

    static func fallbackSegments(frameCount: Int, maxRooms: Int = 4) -> [VideoRouteSegment] {
        guard frameCount > 0 else {
            return [VideoRouteSegment(roomLabel: "space_1", bestFrameIndex: 0, confidence: 0.5)]
        }
        let rooms = min(maxRooms, max(1, frameCount / 6))
        if rooms == 1 {
            return [VideoRouteSegment(roomLabel: "space_1", bestFrameIndex: 0, confidence: 0.5)]
        }
        var segments: [VideoRouteSegment] = []
        for r in 0..<rooms {
            let idx = min(frameCount - 1, (frameCount * r) / rooms)
            segments.append(
                VideoRouteSegment(
                    roomLabel: "space_\(r + 1)",
                    bestFrameIndex: idx,
                    confidence: 0.45
                )
            )
        }
        return segments
    }

    static func displayLabel(for raw: String) -> String {
        let trimmed = raw
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Room" }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    static func placeholderHazards(roomLabel: String) -> [ScanHazardDTO] {
        [
            ScanHazardDTO(
                title: "Placeholder hazard",
                detail: "Demo item for \(roomLabel). Full analysis coming soon.",
                severity: .medium,
                icon: "exclamationmark.triangle.fill",
                boundingBox: NormalizedRect(x: 0.38, y: 0.42, width: 0.22, height: 0.18),
                fixSteps: ["Review this area in person."]
            ),
            ScanHazardDTO(
                title: "Check sightlines",
                detail: "Walkthrough preview — hazards will be detected per room later.",
                severity: .low,
                icon: "eye.fill",
                boundingBox: NormalizedRect(x: 0.52, y: 0.55, width: 0.2, height: 0.16),
                fixSteps: ["Keep paths clear."]
            ),
        ]
    }
}

struct VideoRouterService {
    var endpoint: URL = SafesightAPIConfig.videoRouteURL
    var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    func route(thumbnails: [UIImage], maxRooms: Int = 4) async throws -> VideoRouteResponse {
        let secret = SafesightAPIConfig.apiSecret
        guard !secret.isEmpty, !thumbnails.isEmpty else {
            return VideoRouteResponse(
                segments: VideoScanPipeline.fallbackSegments(frameCount: thumbnails.count, maxRooms: maxRooms)
            )
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"maxRooms\"\r\n\r\n")
        body.append("\(maxRooms)\r\n")

        for (i, image) in thumbnails.enumerated() {
            guard let jpeg = jpegThumb(from: image) else { continue }
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"frames\"; filename=\"frame-\(i).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(jpeg)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                #if DEBUG
                print("Video route HTTP error")
                #endif
                return VideoRouteResponse(
                    segments: VideoScanPipeline.fallbackSegments(frameCount: thumbnails.count, maxRooms: maxRooms)
                )
            }
            return try JSONDecoder().decode(VideoRouteResponse.self, from: data)
        } catch {
            #if DEBUG
            print("Video route failed: \(error)")
            #endif
            return VideoRouteResponse(
                segments: VideoScanPipeline.fallbackSegments(frameCount: thumbnails.count, maxRooms: maxRooms)
            )
        }
    }

    private func jpegThumb(from image: UIImage) -> Data? {
        let upright = image.normalizedUp()
        let size = upright.size
        let longest = max(size.width, size.height)
        let scaled: UIImage
        if longest > 384 {
            let scale = 384 / longest
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: target)
            scaled = renderer.image { _ in upright.draw(in: CGRect(origin: .zero, size: target)) }
        } else {
            scaled = upright
        }
        return scaled.jpegData(compressionQuality: 0.55)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

private extension CMTime {
    var seconds: Double {
        CMTimeGetSeconds(self)
    }
}
