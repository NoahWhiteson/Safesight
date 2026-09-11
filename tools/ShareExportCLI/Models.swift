//
//  Models.swift
//  ShareExportCLI — minimal types matching Safesight/ScanModels.swift for native export.
//

import Foundation
import UIKit

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

    static func sanitized(
        x: Double?,
        y: Double?,
        width: Double?,
        height: Double?,
        index: Int,
        total: Int
    ) -> NormalizedRect {
        guard var sx = x, var sy = y, var sw = width, var sh = height,
              sw.isFinite, sh.isFinite, sx.isFinite, sy.isFinite else {
            return fallback(index: index, total: max(total, 1))
        }

        let maxV = max(abs(sx), abs(sy), abs(sw), abs(sh))
        if maxV > 100 {
            sx /= 1000; sy /= 1000; sw /= 1000; sh /= 1000
        } else if maxV > 1.5 {
            sx /= 100; sy /= 100; sw /= 100; sh /= 100
        }

        if sw > sx, sh > sy, (sx + sw > 1.02 || sy + sh > 1.02 || sw > 0.7 || sh > 0.7) {
            sw -= sx
            sh -= sy
        }

        if sx < 0 { sw += sx; sx = 0 }
        if sy < 0 { sh += sy; sy = 0 }

        sx = clamp01(sx)
        sy = clamp01(sy)
        sw = max(0, sw)
        sh = max(0, sh)

        if sw < 0.012 || sh < 0.012 {
            return fallback(index: index, total: max(total, 1))
        }

        if sw > 0.72 || sh > 0.72 || (sw > 0.55 && sh > 0.55) {
            return tightened(x: sx, y: sy, width: sw, height: sh)
        }

        sw = min(sw, 1 - sx)
        sh = min(sh, 1 - sy)
        if sw < 0.012 || sh < 0.012 {
            return fallback(index: index, total: max(total, 1))
        }

        if sw < 0.04 {
            let cx = sx + sw / 2
            sw = 0.04
            sx = clamp01(cx - sw / 2)
            sw = min(sw, 1 - sx)
        }
        if sh < 0.04 {
            let cy = sy + sh / 2
            sh = 0.04
            sy = clamp01(cy - sh / 2)
            sh = min(sh, 1 - sy)
        }

        return NormalizedRect(x: sx, y: sy, width: sw, height: sh)
    }

    private static func tightened(x: Double, y: Double, width: Double, height: Double) -> NormalizedRect {
        var sx = x, sy = y, sw = width, sh = height
        let maxW = 0.52, maxH = 0.52
        if sw > maxW {
            let cx = sx + sw / 2
            sw = maxW
            sx = cx - sw / 2
        }
        if sh > maxH {
            let cy = sy + sh / 2
            sh = maxH
            sy = cy - sh / 2
        }
        sx = clamp01(sx)
        sy = clamp01(sy)
        sw = min(max(sw, 0.04), 1 - sx)
        sh = min(max(sh, 0.04), 1 - sy)
        return NormalizedRect(x: sx, y: sy, width: sw, height: sh)
    }

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

enum HazardLifecycleStatus: String, Codable, CaseIterable, Hashable {
    case open
    case fixed
    case dismissed
}

struct ScanHazardDTO: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var severity: HazardSeverity
    var icon: String
    var boundingBox: NormalizedRect
    var fixSteps: [String]
    var focusArea: String?
    var confidence: Int
    var status: HazardLifecycleStatus

    enum CodingKeys: String, CodingKey {
        case id, title, detail, severity, icon, boundingBox, fixSteps, focusArea, confidence, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decode(String.self, forKey: .detail)
        severity = try c.decode(HazardSeverity.self, forKey: .severity)
        icon = try c.decode(String.self, forKey: .icon)
        let rawBox = try c.decode(NormalizedRect.self, forKey: .boundingBox)
        boundingBox = NormalizedRect.sanitized(
            x: rawBox.x,
            y: rawBox.y,
            width: rawBox.width,
            height: rawBox.height,
            index: 0,
            total: 1
        )
        fixSteps = try c.decode([String].self, forKey: .fixSteps)
        focusArea = try c.decodeIfPresent(String.self, forKey: .focusArea)
        if let i = try? c.decode(Int.self, forKey: .confidence) {
            confidence = min(99, max(40, i))
        } else if let d = try? c.decode(Double.self, forKey: .confidence) {
            let scaled = (d > 0 && d <= 1) ? d * 100 : d
            confidence = min(99, max(40, Int(scaled.rounded())))
        } else {
            confidence = 72
        }
        status = try c.decodeIfPresent(HazardLifecycleStatus.self, forKey: .status) ?? .open
    }
}

enum HazardSeverity: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct ScanAnalysisResponse: Codable {
    var score: Int
    var summary: String
    var hazards: [ScanHazardDTO]
}

extension UIImage {
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
