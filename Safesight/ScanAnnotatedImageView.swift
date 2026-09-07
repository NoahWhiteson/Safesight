//
//  ScanAnnotatedImageView.swift
//  Safesight
//

import SwiftUI
import UIKit

// MARK: - Annotated photo (boxes from AI boundingBox)

struct ScanAnnotatedImageView: View {
    let image: UIImage
    let hazards: [ScanHazardDTO]
    var highlightedID: UUID?
    var onSelectHazard: ((UUID?) -> Void)? = nil

    @State private var expandedGroupID: UUID?

    var body: some View {
        GeometryReader { geo in
            let placed = placementRect(
                imageSize: image.size,
                in: geo.size,
                hazards: hazards
            )
            let clusters = Self.buildClusters(hazards: hazards, imageFrame: placed)
            let markers = Self.resolvedMarkers(
                clusters: clusters,
                expandedGroupID: effectiveExpandedID(clusters: clusters),
                canvas: geo.size
            )

            ZStack {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .frame(width: placed.width, height: placed.height)
                    .position(x: placed.midX, y: placed.midY)
                    .clipped()

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard expandedGroupID != nil else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedGroupID = nil
                        }
                        onSelectHazard?(nil)
                    }

                ForEach(markers) { marker in
                    markerLayer(marker)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onChange(of: highlightedID) { _, newID in
                guard let newID else { return }
                if let group = clusters.first(where: { $0.isGroup && $0.memberIDs.contains(newID) }) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedGroupID = group.id
                    }
                }
            }
        }
    }

    /// Auto-expand when the drawer highlights a nested member.
    private func effectiveExpandedID(clusters: [HazardCluster]) -> UUID? {
        if let expandedGroupID { return expandedGroupID }
        if let highlightedID,
           let group = clusters.first(where: { $0.isGroup && $0.memberIDs.contains(highlightedID) }) {
            return group.id
        }
        return nil
    }

    @ViewBuilder
    private func markerLayer(_ marker: MarkerItem) -> some View {
        let active: Bool = {
            if marker.isRevealedChild || (marker.isGroup && marker.isExpanded) {
                return true
            }
            if let highlightedID {
                if marker.isGroup {
                    return marker.memberIDs.contains(highlightedID)
                }
                return highlightedID == marker.id
            }
            return true
        }()
        let box = marker.box
        let w = max(8, box.width)
        let h = max(8, box.height)
        let line: CGFloat = (active || marker.isRevealedChild) ? 3 : 1.75
        let opacity: CGFloat = {
            if marker.isFixed { return 0.7 }
            if marker.isRevealedChild { return 1 }
            if marker.isGroup && marker.isExpanded { return 0.92 }
            if active { return 1 }
            return 0.72
        }()
        let fillOpacity: CGFloat = {
            if marker.isRevealedChild { return 0.28 }
            if marker.isGroup && marker.isExpanded { return 0.1 }
            return active ? 0.2 : 0.1
        }()
        let strokeStyle = marker.isGroup
            ? StrokeStyle(lineWidth: line, dash: marker.isExpanded ? [5, 4] : [7, 4])
            : StrokeStyle(lineWidth: line)

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(marker.color, style: strokeStyle)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(marker.color.opacity(fillOpacity))
            )
            .frame(width: w, height: h)
            .position(x: box.midX, y: box.midY)
            .opacity(opacity)
            .allowsHitTesting(false)

        Button {
            Haptics.light()
            handleTap(marker)
        } label: {
            HStack(spacing: 4) {
                Text(marker.text)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 2)
                if let confidence = marker.confidence {
                    Text("\(confidence)%")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                }
                if marker.isGroup {
                    Image(systemName: marker.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .padding(.horizontal, 7)
            .frame(width: marker.labelSize.width, height: marker.labelSize.height, alignment: .leading)
            .background(tabShape(for: marker.side).fill(marker.color))
        }
        .buttonStyle(.plain)
        .position(x: marker.labelRect.midX, y: marker.labelRect.midY)
        .opacity(opacity)
        .zIndex(3)

        if marker.isGroup {
            Button {
                Haptics.light()
                handleTap(marker)
            } label: {
                Color.clear
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: box.midX, y: box.midY)
            .zIndex(1)
        }
    }

    private func handleTap(_ marker: MarkerItem) {
        if marker.isGroup {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedGroupID == marker.id {
                    expandedGroupID = nil
                    onSelectHazard?(nil)
                } else {
                    expandedGroupID = marker.id
                    onSelectHazard?(marker.memberIDs.first)
                }
            }
        } else {
            onSelectHazard?(marker.id)
        }
    }

    private enum LabelSide {
        case top, bottom, leading, trailing
    }

    private struct ClusterMember {
        let hazard: ScanHazardDTO
        let box: CGRect
    }

    private struct HazardCluster: Identifiable {
        let id: UUID
        let members: [ClusterMember]
        let box: CGRect
        var isGroup: Bool { members.count > 1 }
        var memberIDs: [UUID] { members.map(\.hazard.id) }
        var hazards: [ScanHazardDTO] { members.map(\.hazard) }
    }

    private struct MarkerItem: Identifiable {
        let id: UUID
        let text: String
        let color: Color
        let isFixed: Bool
        let box: CGRect
        let side: LabelSide
        let labelSize: CGSize
        let labelRect: CGRect
        let isGroup: Bool
        let isExpanded: Bool
        let isRevealedChild: Bool
        let memberIDs: [UUID]
        /// Per-hazard AI confidence; nil on group tabs.
        let confidence: Int?
    }

    private func tabShape(for side: LabelSide) -> UnevenRoundedRectangle {
        switch side {
        case .top:
            return UnevenRoundedRectangle(
                topLeadingRadius: 3, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 3, style: .continuous
            )
        case .bottom:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 3,
                bottomTrailingRadius: 3, topTrailingRadius: 0, style: .continuous
            )
        case .leading:
            return UnevenRoundedRectangle(
                topLeadingRadius: 3, bottomLeadingRadius: 3,
                bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous
            )
        case .trailing:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 3, topTrailingRadius: 3, style: .continuous
            )
        }
    }

    // MARK: Nested / stacked → one outer box

    private static func buildClusters(
        hazards: [ScanHazardDTO],
        imageFrame: CGRect
    ) -> [HazardCluster] {
        let visible = hazards.filter { $0.status != .dismissed }
        guard !visible.isEmpty else { return [] }

        let boxes: [CGRect] = visible.map { hazard in
            let local = hazard.boundingBox.cgRect(in: imageFrame.size)
            return local.offsetBy(dx: imageFrame.minX, dy: imageFrame.minY)
        }

        let n = visible.count
        var parent = Array(0..<n)
        func find(_ i: Int) -> Int {
            var x = i
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<n {
            for j in (i + 1)..<n where shouldMerge(boxes[i], boxes[j]) {
                union(i, j)
            }
        }

        var buckets: [Int: [Int]] = [:]
        for i in 0..<n {
            buckets[find(i), default: []].append(i)
        }

        return buckets.values.map { indices -> HazardCluster in
            let members: [ClusterMember] = indices.map {
                ClusterMember(hazard: visible[$0], box: boxes[$0])
            }
            let unionBox = members.dropFirst().reduce(members[0].box) { $0.union($1.box) }
            let key = members.map(\.hazard.id.uuidString).sorted().joined(separator: "|")
            let id = stableUUID(from: key)
            return HazardCluster(id: id, members: members, box: unionBox)
        }
        .sorted {
            ($0.box.width * $0.box.height) > ($1.box.width * $1.box.height)
        }
    }

    private static func stableUUID(from raw: String) -> UUID {
        var hash: UInt64 = 5381
        for b in raw.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(b)
        }
        let a = hash
        let b = hash &* 0x9E3779B97F4A7C15
        let s = String(
            format: "%08x-%04x-%04x-%04x-%012llx",
            UInt32(truncatingIfNeeded: a),
            UInt16(truncatingIfNeeded: a >> 32),
            (UInt16(truncatingIfNeeded: b) & 0x0fff) | 0x4000,
            (UInt16(truncatingIfNeeded: b >> 16) & 0x3fff) | 0x8000,
            b >> 32
        )
        return UUID(uuidString: s) ?? UUID()
    }

    private static func shouldMerge(_ a: CGRect, _ b: CGRect) -> Bool {
        let inter = a.intersection(b)
        guard !inter.isNull, !inter.isEmpty else { return false }
        let aArea = max(a.width * a.height, 1)
        let bArea = max(b.width * b.height, 1)
        let interArea = inter.width * inter.height
        let smaller = min(aArea, bArea)
        if interArea / smaller >= 0.62 { return true }
        let unionArea = aArea + bArea - interArea
        return interArea / unionArea >= 0.48
    }

    private static func worstSeverity(in hazards: [ScanHazardDTO]) -> HazardSeverity {
        if hazards.contains(where: { $0.severity == .high }) { return .high }
        if hazards.contains(where: { $0.severity == .medium }) { return .medium }
        return .low
    }

    private static func resolvedMarkers(
        clusters: [HazardCluster],
        expandedGroupID: UUID?,
        canvas: CGSize
    ) -> [MarkerItem] {
        var occupied: [CGRect] = []
        var out: [MarkerItem] = []

        for cluster in clusters {
            let expanded = cluster.isGroup && cluster.id == expandedGroupID

            if cluster.isGroup && !expanded {
                appendGroupMarker(
                    cluster: cluster,
                    expanded: false,
                    canvas: canvas,
                    occupied: &occupied,
                    out: &out
                )
                continue
            }

            if cluster.isGroup && expanded {
                appendGroupMarker(
                    cluster: cluster,
                    expanded: true,
                    canvas: canvas,
                    occupied: &occupied,
                    out: &out
                )
            }

            guard !cluster.isGroup || expanded else { continue }

            let revealed = cluster.isGroup && expanded
            let items = cluster.members
            let boxes = items.map(\.box)
            let sorted = items.enumerated().sorted { a, b in
                let ar = boxes[a.offset], br = boxes[b.offset]
                if abs(ar.minY - br.minY) > 2 { return ar.minY < br.minY }
                return ar.minX < br.minX
            }

            for pair in sorted {
                let hazard = pair.element.hazard
                let box = pair.element.box
                let text = hazard.status == .fixed ? "Fixed · \(hazard.title)" : hazard.title
                let color = hazard.status == .fixed
                    ? Color(red: 0.20, green: 0.68, blue: 0.45)
                    : hazard.severity.color
                let size = estimatedLabelSize(text, extra: 0, showConfidence: true)
                let foreign = boxes.enumerated().compactMap { i, r in i == pair.offset ? nil : r }
                let picked = bestPlacement(
                    box: box,
                    labelSize: size,
                    canvas: canvas,
                    occupiedLabels: occupied,
                    foreignBoxes: foreign
                )
                occupied.append(picked.rect.insetBy(dx: -5, dy: -4))
                out.append(
                    MarkerItem(
                        id: hazard.id,
                        text: text,
                        color: color,
                        isFixed: hazard.status == .fixed,
                        box: box,
                        side: picked.side,
                        labelSize: size,
                        labelRect: picked.rect,
                        isGroup: false,
                        isExpanded: false,
                        isRevealedChild: revealed,
                        memberIDs: [hazard.id],
                        confidence: hazard.confidence
                    )
                )
            }
        }
        return out
    }

    private static func appendGroupMarker(
        cluster: HazardCluster,
        expanded: Bool,
        canvas: CGSize,
        occupied: inout [CGRect],
        out: inout [MarkerItem]
    ) {
        let worst = worstSeverity(in: cluster.hazards)
        let allFixed = cluster.hazards.allSatisfy { $0.status == .fixed }
        let text: String
        if expanded {
            text = "Hide \(cluster.members.count)"
        } else if allFixed {
            text = "Fixed · \(cluster.members.count) issues"
        } else {
            text = "\(cluster.members.count) issues"
        }
        let color = allFixed
            ? Color(red: 0.20, green: 0.68, blue: 0.45)
            : worst.color
        let size = estimatedLabelSize(text, extra: 14, showConfidence: false)
        let picked = bestPlacement(
            box: cluster.box,
            labelSize: size,
            canvas: canvas,
            occupiedLabels: occupied,
            foreignBoxes: []
        )
        occupied.append(picked.rect.insetBy(dx: -5, dy: -4))
        out.append(
            MarkerItem(
                id: cluster.id,
                text: text,
                color: color,
                isFixed: allFixed,
                box: cluster.box,
                side: picked.side,
                labelSize: size,
                labelRect: picked.rect,
                isGroup: true,
                isExpanded: expanded,
                isRevealedChild: false,
                memberIDs: cluster.memberIDs,
                confidence: nil
            )
        )
    }

    private static func estimatedLabelSize(_ text: String, extra: CGFloat, showConfidence: Bool) -> CGSize {
        let confidencePad: CGFloat = showConfidence ? 30 : 0
        let w = min(210, max(44, CGFloat(text.count) * 6.35 + 16 + extra + confidencePad))
        return CGSize(width: w, height: 20)
    }

    private struct Placement {
        let side: LabelSide
        let rect: CGRect
        let score: CGFloat
    }

    private static func bestPlacement(
        box: CGRect,
        labelSize: CGSize,
        canvas: CGSize,
        occupiedLabels: [CGRect],
        foreignBoxes: [CGRect]
    ) -> Placement {
        let canvasRect = CGRect(origin: .zero, size: canvas).insetBy(dx: 1, dy: 1)
        let candidates = rimCandidates(box: box, size: labelSize)
        var best: Placement?

        for (side, rect) in candidates {
            let clamped = clampRect(rect, in: canvasRect)
            if occupiedLabels.contains(where: { $0.intersects(clamped) }) { continue }
            let hitsBox = foreignBoxes.contains { $0.intersects(clamped.insetBy(dx: 1, dy: 1)) }
            let offCanvas = !canvasRect.contains(rect)
            var score = sidePreference(side)
            score += hypot(clamped.midX - rect.midX, clamped.midY - rect.midY) * 0.2
            if hitsBox { score += 40 }
            if offCanvas { score += 25 }
            let placement = Placement(side: side, rect: clamped, score: score)
            if best == nil || placement.score < best!.score { best = placement }
        }
        if let best { return best }

        var rescue: Placement?
        for (side, rect) in candidates {
            let clamped = clampRect(rect, in: canvasRect)
            let overlapArea = occupiedLabels.reduce(CGFloat(0)) { sum, other in
                let inter = clamped.intersection(other)
                guard !inter.isNull, !inter.isEmpty else { return sum }
                return sum + inter.width * inter.height
            }
            var score = 1000 + overlapArea + sidePreference(side)
            if foreignBoxes.contains(where: { $0.intersects(clamped) }) { score += 40 }
            let placement = Placement(side: side, rect: clamped, score: score)
            if rescue == nil || placement.score < rescue!.score { rescue = placement }
        }
        return rescue ?? Placement(
            side: .top,
            rect: clampRect(
                CGRect(
                    x: box.minX,
                    y: box.minY - labelSize.height + 1,
                    width: labelSize.width,
                    height: labelSize.height
                ),
                in: canvasRect
            ),
            score: 9999
        )
    }

    private static func sidePreference(_ side: LabelSide) -> CGFloat {
        switch side {
        case .top: return 0
        case .bottom: return 8
        case .trailing: return 16
        case .leading: return 18
        }
    }

    private static func rimCandidates(box: CGRect, size: CGSize) -> [(LabelSide, CGRect)] {
        let overlap: CGFloat = 1
        let fracs: [CGFloat] = [0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
        var out: [(LabelSide, CGRect)] = []
        let topTravel = max(box.width - size.width, 0)
        let topOverhang = max(size.width - box.width, 0)
        for f in fracs {
            let x = topTravel > 0 ? box.minX + f * topTravel : box.minX - f * topOverhang
            out.append((.top, CGRect(x: x, y: box.minY - size.height + overlap, width: size.width, height: size.height)))
            out.append((.bottom, CGRect(x: x, y: box.maxY - overlap, width: size.width, height: size.height)))
        }
        let sideTravel = max(box.height - size.height, 0)
        let sideOverhang = max(size.height - box.height, 0)
        for f in fracs {
            let y = sideTravel > 0 ? box.minY + f * sideTravel : box.minY - f * sideOverhang
            out.append((.leading, CGRect(x: box.minX - size.width + overlap, y: y, width: size.width, height: size.height)))
            out.append((.trailing, CGRect(x: box.maxX - overlap, y: y, width: size.width, height: size.height)))
        }
        return out
    }

    private static func clampRect(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var r = rect
        if r.width > bounds.width { r.size.width = bounds.width }
        if r.height > bounds.height { r.size.height = bounds.height }
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        return r
    }

    private func placementRect(
        imageSize: CGSize,
        in bounds: CGSize,
        hazards: [ScanHazardDTO]
    ) -> CGRect {
        let fill = aspectFillRect(imageSize: imageSize, in: bounds)
        let visibleHazards = hazards.filter { $0.status != .dismissed }
        guard !visibleHazards.isEmpty else { return fill }
        let pad: CGFloat = 12
        let visible = CGRect(origin: .zero, size: bounds).insetBy(dx: pad, dy: pad)
        let allVisible = visibleHazards.allSatisfy { hazard in
            let local = hazard.boundingBox.cgRect(in: fill.size)
            let mapped = local.offsetBy(dx: fill.minX, dy: fill.minY)
            return visible.contains(mapped)
        }
        return allVisible ? fill : aspectFitRect(imageSize: imageSize, in: bounds)
    }

    private func aspectFitRect(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        let iw = max(imageSize.width, 1)
        let ih = max(imageSize.height, 1)
        let imageAspect = iw / ih
        let boundsAspect = bounds.width / max(bounds.height, 1)
        if imageAspect > boundsAspect {
            let h = bounds.width / imageAspect
            return CGRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        } else {
            let w = bounds.height * imageAspect
            return CGRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height)
        }
    }

    private func aspectFillRect(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        let iw = max(imageSize.width, 1)
        let ih = max(imageSize.height, 1)
        let imageAspect = iw / ih
        let boundsAspect = bounds.width / max(bounds.height, 1)
        if imageAspect > boundsAspect {
            let w = bounds.height * imageAspect
            return CGRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height)
        } else {
            let h = bounds.width / imageAspect
            return CGRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        }
    }
}
