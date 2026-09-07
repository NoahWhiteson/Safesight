//
//  HazardsView.swift
//  Safesight
//

import SwiftUI
import UIKit

// MARK: - Open hazard (flattened from scan history)

struct OpenHazardItem: Identifiable, Hashable {
    var id: UUID { hazard.id }
    let hazard: ScanHazardDTO
    let scan: ScanResult
}

extension ScanHistoryStore {
    /// All hazards across scans, newest scan first, High → Low severity.
    var openHazards: [OpenHazardItem] {
        let severityRank: [HazardSeverity: Int] = [.high: 0, .medium: 1, .low: 2]
        return scans.flatMap { scan in
            scan.hazards.map { OpenHazardItem(hazard: $0, scan: scan) }
        }
        .sorted {
            let l = severityRank[$0.hazard.severity] ?? 9
            let r = severityRank[$1.hazard.severity] ?? 9
            if l != r { return l < r }
            return $0.scan.createdAt > $1.scan.createdAt
        }
    }
}

// MARK: - Image crop

enum HazardCropper {
    /// Zoomed crop around a normalized box, with padding so context still reads.
    static func crop(_ image: UIImage, box: NormalizedRect, padding: CGFloat = 0.14) -> UIImage? {
        let upright = image.normalizedUp()
        guard let cg = upright.cgImage else { return nil }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)

        var x = box.x - Double(padding)
        var y = box.y - Double(padding)
        var bw = box.width + Double(padding) * 2
        var bh = box.height + Double(padding) * 2

        if x < 0 { bw += x; x = 0 }
        if y < 0 { bh += y; y = 0 }
        bw = min(bw, 1 - x)
        bh = min(bh, 1 - y)

        let rect = CGRect(x: x * w, y: y * h, width: max(1, bw * w), height: max(1, bh * h))
            .integral
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: upright.scale, orientation: .up)
    }
}

private extension UIImage {
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

// MARK: - Tab screen (grid → drawer)

struct HazardsScreen: View {
    @ObservedObject private var history = ScanHistoryStore.shared
    @State private var selected: OpenHazardItem?

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if history.openHazards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(history.openHazards) { item in
                                Button {
                                    Haptics.light()
                                    selected = item
                                } label: {
                                    HazardGridCell(
                                        item: item,
                                        image: history.image(for: item.scan)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Hazards")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selected) { item in
                HazardDetailDrawer(
                    item: item,
                    image: history.image(for: item.scan)
                ) {
                    selected = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.68, blue: 0.45))
            Text("No open hazards")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ink)
            Text("Run a scan and anything Safesight flags will land here with a close-up, severity, and fixes.")
                .font(.system(size: 15))
                .foregroundStyle(mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid cell

private struct HazardGridCell: View {
    let item: OpenHazardItem
    let image: UIImage?

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)

    private var cropped: UIImage? {
        guard let image else { return nil }
        return HazardCropper.crop(image, box: item.hazard.boundingBox)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let cropped {
                        Image(uiImage: cropped)
                            .resizable()
                            .scaledToFill()
                    } else if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.92)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

                Text(item.hazard.severity.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(item.hazard.severity.color))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.hazard.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(item.hazard.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(mute)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Detail drawer

private struct HazardDetailDrawer: View {
    let item: OpenHazardItem
    let image: UIImage?
    var onDone: () -> Void

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)

    private var cropped: UIImage? {
        guard let image else { return nil }
        return HazardCropper.crop(image, box: item.hazard.boundingBox, padding: 0.18)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        Group {
                            if let cropped {
                                Image(uiImage: cropped)
                                    .resizable()
                                    .scaledToFill()
                            } else if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color(white: 0.92)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()

                        Text(item.hazard.severity.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(item.hazard.severity.color))
                            .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.hazard.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.hazard.severity.color)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(item.hazard.severity.color.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.hazard.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(ink)
                            Text(item.hazard.detail)
                                .font(.system(size: 15))
                                .foregroundStyle(mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("NEXT STEPS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(mute)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(item.hazard.fixSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(blue)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(blue.opacity(0.12)))
                                    Text(step)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)

                                if index < item.hazard.fixSteps.count - 1 {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        )
                    }

                    if !item.scan.products.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recommended")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(ink)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(item.scan.products) { product in
                                        RecommendedProductCard(product: product)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Hazard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
