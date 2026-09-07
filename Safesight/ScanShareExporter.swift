//
//  ScanShareExporter.swift
//  Safesight
//
//  Renders a shareable PNG: annotated scan + logo + score.
//

import SwiftUI
import UIKit

enum ScanShareExporter {
    /// Max long-edge for the exported PNG.
    private static let maxLongEdge: CGFloat = 1600
    private static let pad: CGFloat = 28

    static func renderPNG(image: UIImage, hazards: [ScanHazardDTO], score: Int) -> Data? {
        renderUIImage(image: image, hazards: hazards, score: score)?.pngData()
    }

    static func renderUIImage(image: UIImage, hazards: [ScanHazardDTO], score: Int) -> UIImage? {
        let source = image.normalizedUp()
        let srcSize = source.size
        guard srcSize.width > 1, srcSize.height > 1 else { return nil }

        let scale = min(1, maxLongEdge / max(srcSize.width, srcSize.height))
        let canvas = CGSize(
            width: (srcSize.width * scale).rounded(.down),
            height: (srcSize.height * scale).rounded(.down)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Photo
            source.draw(in: CGRect(origin: .zero, size: canvas))

            // Soft vignette so overlays read on bright/dark photos
            let colors = [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.28).cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.55, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: canvas.height * 0.62),
                    end: CGPoint(x: 0, y: canvas.height),
                    options: []
                )
            }

            // Top wash for logo legibility
            if let topGrad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.black.withAlphaComponent(0.32).cgColor,
                    UIColor.black.withAlphaComponent(0).cgColor,
                ] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    topGrad,
                    start: .zero,
                    end: CGPoint(x: 0, y: canvas.height * 0.18),
                    options: []
                )
            }

            drawAnnotations(hazards: hazards, in: canvas, context: cg)
            drawLogo(in: canvas, context: cg)
            drawScore(score, in: canvas)
        }
    }

    // MARK: - Annotations

    private static func drawAnnotations(hazards: [ScanHazardDTO], in canvas: CGSize, context: CGContext) {
        let visible = hazards.filter { $0.status != .dismissed }
        var occupied: [CGRect] = []

        for (index, hazard) in visible.enumerated() {
            let box = hazard.boundingBox.cgRect(in: canvas)
            let color = uiColor(for: hazard)
            let line: CGFloat = max(2.5, min(canvas.width, canvas.height) * 0.0035)

            // Box
            let path = UIBezierPath(
                roundedRect: box.insetBy(dx: line / 2, dy: line / 2),
                cornerRadius: 4
            )
            color.withAlphaComponent(0.18).setFill()
            path.fill()
            color.setStroke()
            path.lineWidth = line
            path.stroke()

            let title = hazard.status == .fixed ? "Fixed · \(hazard.title)" : hazard.title
            let conf = "\(hazard.confidence)%"
            let labelSize = estimateLabelSize(title: title, confidence: conf, canvas: canvas)
            let labelRect = placeLabel(
                for: box,
                size: labelSize,
                canvas: canvas,
                occupied: occupied,
                index: index
            )
            occupied.append(labelRect.insetBy(dx: -4, dy: -3))
            drawLabelTab(
                title: title,
                confidence: conf,
                color: color,
                rect: labelRect,
                aboveBox: labelRect.midY <= box.minY + 2
            )
        }
    }

    private static func estimateLabelSize(title: String, confidence: String, canvas: CGSize) -> CGSize {
        let scale = max(0.85, min(canvas.width, canvas.height) / 390)
        let fontSize = 11 * scale
        let titleFont = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let confFont = UIFont.systemFont(ofSize: fontSize * 0.9, weight: .semibold)
        let titleW = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let confW = (confidence as NSString).size(withAttributes: [.font: confFont]).width
        let h = 20 * scale
        let w = min(canvas.width * 0.72, titleW + confW + 28 * scale)
        return CGSize(width: max(56 * scale, w), height: h)
    }

    private static func placeLabel(
        for box: CGRect,
        size: CGSize,
        canvas: CGSize,
        occupied: [CGRect],
        index: Int
    ) -> CGRect {
        let inset = CGRect(origin: .zero, size: canvas).insetBy(dx: 8, dy: 8)
        let candidates: [CGRect] = [
            CGRect(x: box.minX, y: box.minY - size.height + 1, width: size.width, height: size.height),
            CGRect(x: box.minX, y: box.maxY - 1, width: size.width, height: size.height),
            CGRect(x: box.maxX - size.width, y: box.minY - size.height + 1, width: size.width, height: size.height),
            CGRect(x: box.minX, y: box.midY - size.height / 2, width: size.width, height: size.height),
        ]

        for raw in candidates {
            let clamped = clamp(raw, in: inset)
            if !occupied.contains(where: { $0.intersects(clamped.insetBy(dx: -3, dy: -2)) }) {
                return clamped
            }
        }

        // Fallback: stagger downward so stacked hazards don’t fully collide.
        let staggered = CGRect(
            x: box.minX,
            y: min(inset.maxY - size.height, box.minY + CGFloat(index) * (size.height + 4)),
            width: size.width,
            height: size.height
        )
        return clamp(staggered, in: inset)
    }

    private static func clamp(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var r = rect
        if r.width > bounds.width { r.size.width = bounds.width }
        if r.height > bounds.height { r.size.height = bounds.height }
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        return r
    }

    private static func drawLabelTab(
        title: String,
        confidence: String,
        color: UIColor,
        rect: CGRect,
        aboveBox: Bool
    ) {
        let path: UIBezierPath
        if aboveBox {
            path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: 4, height: 4)
            )
        } else {
            path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.bottomLeft, .bottomRight],
                cornerRadii: CGSize(width: 4, height: 4)
            )
        }
        color.setFill()
        path.fill()

        let scale = rect.height / 20
        let titleFont = UIFont.systemFont(ofSize: 11 * scale, weight: .bold)
        let confFont = UIFont.systemFont(ofSize: 10 * scale, weight: .semibold)
        let confW = (confidence as NSString).size(withAttributes: [.font: confFont]).width
        let pad: CGFloat = 7 * scale

        let titleRect = CGRect(
            x: rect.minX + pad,
            y: rect.minY,
            width: max(0, rect.width - confW - pad * 2.4),
            height: rect.height
        )
        let confRect = CGRect(
            x: rect.maxX - pad - confW,
            y: rect.minY,
            width: confW,
            height: rect.height
        )

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
        ]
        let confPara = NSMutableParagraphStyle()
        confPara.alignment = .right
        let confAttrs: [NSAttributedString.Key: Any] = [
            .font: confFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.92),
            .paragraphStyle: confPara,
        ]

        let titleH = (title as NSString).boundingRect(
            with: CGSize(width: titleRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: titleAttrs,
            context: nil
        ).height
        let confH = (confidence as NSString).size(withAttributes: confAttrs).height

        (title as NSString).draw(
            in: CGRect(
                x: titleRect.minX,
                y: titleRect.midY - titleH / 2,
                width: titleRect.width,
                height: titleH
            ),
            withAttributes: titleAttrs
        )
        (confidence as NSString).draw(
            in: CGRect(
                x: confRect.minX,
                y: confRect.midY - confH / 2,
                width: confRect.width,
                height: confH
            ),
            withAttributes: confAttrs
        )
    }

    private static func uiColor(for hazard: ScanHazardDTO) -> UIColor {
        if hazard.status == .fixed {
            return UIColor(red: 0.20, green: 0.68, blue: 0.45, alpha: 1)
        }
        switch hazard.severity {
        case .high: return UIColor(red: 0.92, green: 0.28, blue: 0.25, alpha: 1)
        case .medium: return UIColor(red: 0.95, green: 0.62, blue: 0.12, alpha: 1)
        case .low: return UIColor(red: 0.20, green: 0.68, blue: 0.45, alpha: 1)
        }
    }

    // MARK: - Chrome

    private static func drawLogo(in canvas: CGSize, context: CGContext) {
        let logoSide = max(36, min(canvas.width, canvas.height) * 0.072)
        let rect = CGRect(x: pad, y: pad, width: logoSide, height: logoSide)

        guard let logo = UIImage(named: "AppLogo")?.withRenderingMode(.alwaysTemplate) else {
            let mark = "S" as NSString
            let font = UIFont.systemFont(ofSize: logoSide * 0.55, weight: .bold)
            let size = mark.size(withAttributes: [.font: font])
            context.setBlendMode(.difference)
            mark.draw(
                at: CGPoint(
                    x: rect.midX - size.width / 2,
                    y: rect.midY - size.height / 2
                ),
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor.white,
                ]
            )
            context.setBlendMode(.normal)
            return
        }

        // Match Scan tab: white template + difference blend (inverts against the photo).
        let tinted = logo.withTintColor(.white, renderingMode: .alwaysOriginal)
        context.saveGState()
        context.setBlendMode(.difference)
        tinted.draw(in: rect)
        context.restoreGState()
    }

    private static func drawScore(_ score: Int, in canvas: CGSize) {
        let clamped = min(100, max(0, score))
        let scale = max(0.75, min(canvas.width, canvas.height) / 420)
        let diameter: CGFloat = 88 * scale
        let lineWidth: CGFloat = 7.5 * scale
        let bottomInset = pad + 18 * scale
        let center = CGPoint(
            x: canvas.width / 2,
            y: canvas.height - bottomInset - diameter / 2
        )
        let ringRect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        // Soft white disk so the drawer-style ring reads on any photo
        let disk = UIBezierPath(ovalIn: ringRect.insetBy(dx: -8 * scale, dy: -8 * scale))
        UIColor.white.withAlphaComponent(0.94).setFill()
        disk.fill()

        // Track (matches ScanResultsDrawer)
        let track = UIBezierPath(ovalIn: ringRect)
        UIColor.black.withAlphaComponent(0.06).setStroke()
        track.lineWidth = lineWidth
        track.stroke()

        // Progress arc
        let progress = CGFloat(clamped) / 100
        let start = -CGFloat.pi / 2
        let end = start + (2 * .pi * progress)
        let arc = UIBezierPath(
            arcCenter: center,
            radius: diameter / 2,
            startAngle: start,
            endAngle: end,
            clockwise: true
        )
        scoreUIColor(clamped).setStroke()
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        arc.stroke()

        // Score + /100
        let scoreFont = UIFont.systemFont(ofSize: 28 * scale, weight: .bold)
        let subFont = UIFont.systemFont(ofSize: 11 * scale, weight: .semibold)
        let scoreText = "\(clamped)" as NSString
        let subText = "/ 100" as NSString
        let scoreSize = scoreText.size(withAttributes: [.font: scoreFont])
        let subSize = subText.size(withAttributes: [.font: subFont])
        let stackH = scoreSize.height + 1 + subSize.height
        let scoreY = center.y - stackH / 2

        scoreText.draw(
            at: CGPoint(x: center.x - scoreSize.width / 2, y: scoreY),
            withAttributes: [
                .font: scoreFont,
                .foregroundColor: UIColor(white: 0.08, alpha: 1),
            ]
        )
        subText.draw(
            at: CGPoint(
                x: center.x - subSize.width / 2,
                y: scoreY + scoreSize.height + 1
            ),
            withAttributes: [
                .font: subFont,
                .foregroundColor: UIColor(white: 0.45, alpha: 1),
            ]
        )
    }

    private static func scoreUIColor(_ score: Int) -> UIColor {
        if score >= 85 { return UIColor(red: 0.20, green: 0.68, blue: 0.45, alpha: 1) }
        if score >= 65 { return UIColor(red: 0.95, green: 0.62, blue: 0.12, alpha: 1) }
        return UIColor(red: 0.92, green: 0.28, blue: 0.25, alpha: 1)
    }
}

// MARK: - System share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum ScanSharePresenter {
    static func makeShareItems(for scan: ScanResult, image: UIImage?) async -> [Any]? {
        guard let image else { return nil }
        let hazards = scan.hazards
        let score = scan.score
        let idPrefix = String(scan.id.uuidString.prefix(8))

        let data = await Task.detached(priority: .userInitiated) {
            ScanShareExporter.renderPNG(image: image, hazards: hazards, score: score)
        }.value
        guard let data else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Safesight-\(idPrefix).png")
        do {
            try data.write(to: url, options: .atomic)
            return [url]
        } catch {
            guard let ui = UIImage(data: data) else { return nil }
            return [ui]
        }
    }
}
