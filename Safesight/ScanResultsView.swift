//
//  ScanResultsView.swift
//  Safesight
//

import SwiftUI

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

            for (index, item) in sorted {
                let hazard = item.hazard
                let box = boxes[index]
                let text = hazard.status == .fixed ? "Fixed · \(hazard.title)" : hazard.title
                let color = hazard.status == .fixed
                    ? Color(red: 0.20, green: 0.68, blue: 0.45)
                    : hazard.severity.color
                let size = estimatedLabelSize(text, extra: 0)
                let foreign = boxes.enumerated().compactMap { i, r in i == index ? nil : r }
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
                        memberIDs: [hazard.id]
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
        let size = estimatedLabelSize(text, extra: 14)
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
                memberIDs: cluster.memberIDs
            )
        )
    }

    private static func estimatedLabelSize(_ text: String, extra: CGFloat) -> CGSize {
        let w = min(180, max(44, CGFloat(text.count) * 6.35 + 16 + extra))
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

// MARK: - Home-style product card (shared)

struct RecommendedProductCard: View {
    let product: ScanProductDTO

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        Button {
            Haptics.light()
            if let raw = product.productURL, let url = URL(string: raw) {
                UIApplication.shared.open(url)
            } else if let asin = product.asin,
                      let url = URL(string: "https://www.amazon.com/dp/\(asin)") {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.96))
                        .frame(height: 120)

                    if let urlString = product.imageURL,
                       !AmazonCatalog.isUnusableImageURL(urlString),
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(10)
                            case .failure:
                                placeholderIcon
                            default:
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                    } else if let name = product.imageName,
                              !name.hasPrefix("Hazard"),
                              UIImage(named: name) != nil {
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .padding(.horizontal, 10)
                    } else {
                        placeholderIcon
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(product.reason)
                        .font(.system(size: 13))
                        .foregroundStyle(mute)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(product.priceLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(blue)
                    Spacer(minLength: 0)
                    Text("Amazon")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mute)
                }
            }
            .padding(16)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderIcon: some View {
        Image(systemName: product.icon)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(blue)
    }
}

// MARK: - Results drawer

struct ScanResultsDrawer: View {
    let scanID: UUID
    @Binding var highlightedHazardID: UUID?
    var onDone: () -> Void
    var onScanUpdated: ((ScanResult) -> Void)? = nil

    @ObservedObject private var history = ScanHistoryStore.shared
    @State private var expandedHazardID: UUID?

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let good = Color(red: 0.20, green: 0.68, blue: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)

    private var result: ScanResult {
        history.scans.first(where: { $0.id == scanID })
            ?? ScanResult(
                id: scanID,
                imageFileName: "",
                score: 0,
                summary: "",
                hazards: [],
                products: [],
                nextSteps: []
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scoreHeader
                    hazardsSection
                    if !result.products.isEmpty {
                        productsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Scan results")
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

    private var scoreHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 10)
                    .frame(width: 118, height: 118)

                Circle()
                    .trim(from: 0, to: CGFloat(min(100, max(0, result.score))) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 118, height: 118)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(result.score)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(ink)
                    Text("/ 100")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mute)
                }
            }
            .padding(.top, 8)

            Text(scoreLabel)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ink)

            Text(result.summary)
                .font(.system(size: 15))
                .foregroundStyle(mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 16) {
                metricPill(title: "Open", value: "\(result.openHazardCount)")
                metricPill(title: "Fixed", value: "\(result.fixedHazardCount)")
                metricPill(
                    title: "Dismissed",
                    value: "\(result.hazards.filter { $0.status == .dismissed }.count)"
                )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ink)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mute)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreColor: Color {
        if result.score >= 85 { return good }
        if result.score >= 65 { return Color(red: 0.95, green: 0.62, blue: 0.12) }
        return Color(red: 0.92, green: 0.28, blue: 0.25)
    }

    private var scoreLabel: String {
        if result.openHazardCount == 0 && !result.hazards.isEmpty { return "All clear here" }
        if result.score >= 85 { return "Looking solid" }
        if result.score >= 65 { return "Needs attention" }
        return "High risk areas"
    }

    private var hazardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hazards")

            if result.hazards.isEmpty {
                Text("No hazards in this scan.")
                    .font(.system(size: 14))
                    .foregroundStyle(mute)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(result.hazards.enumerated()), id: \.element.id) { index, hazard in
                        hazardRow(hazard, expanded: expandedHazardID == hazard.id)

                        if index < result.hazards.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                )
            }
        }
    }

    private func hazardRow(_ hazard: ScanHazardDTO, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    if expanded {
                        expandedHazardID = nil
                        highlightedHazardID = nil
                    } else {
                        expandedHazardID = hazard.id
                        highlightedHazardID = hazard.id
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: hazard.status == .fixed ? "checkmark.circle.fill" : hazard.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hazard.status == .fixed ? good : hazard.severity.color)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(
                                (hazard.status == .fixed ? good : hazard.severity.color).opacity(0.12)
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(hazard.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(hazard.status == .dismissed ? mute : ink)
                                .strikethrough(hazard.status == .dismissed)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Text(hazard.status.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(statusColor(hazard.status))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(statusColor(hazard.status).opacity(0.12)))
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(mute)
                        }
                        Text(hazard.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(mute)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !hazard.fixSteps.isEmpty {
                        Text("HOW TO FIX")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(mute)

                        ForEach(Array(hazard.fixSteps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(blue)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(blue.opacity(0.12)))
                                Text(step)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    lifecycleButtons(for: hazard)
                }
                .padding(.leading, 40)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(hazard.status == .dismissed ? 0.55 : 1)
    }

    private func lifecycleButtons(for hazard: ScanHazardDTO) -> some View {
        HStack(spacing: 8) {
            if hazard.status != .fixed {
                Button {
                    applyStatus(.fixed, hazardID: hazard.id)
                } label: {
                    Label("Fixed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(good.opacity(0.14))
                        )
                        .foregroundStyle(good)
                }
                .buttonStyle(.plain)
            }

            if hazard.status != .dismissed {
                Button {
                    applyStatus(.dismissed, hazardID: hazard.id)
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.05))
                        )
                        .foregroundStyle(mute)
                }
                .buttonStyle(.plain)
            }

            if hazard.status != .open {
                Button {
                    applyStatus(.open, hazardID: hazard.id)
                } label: {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(blue.opacity(0.12))
                        )
                        .foregroundStyle(blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func applyStatus(_ status: HazardLifecycleStatus, hazardID: UUID) {
        Haptics.medium()
        if let updated = history.setHazardStatus(
            scanID: scanID,
            hazardID: hazardID,
            status: status
        ) {
            onScanUpdated?(updated)
            if status != .open {
                highlightedHazardID = nil
            }
        }
    }

    private func statusColor(_ status: HazardLifecycleStatus) -> Color {
        switch status {
        case .open: return Color(red: 0.95, green: 0.62, blue: 0.12)
        case .fixed: return good
        case .dismissed: return mute
        }
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ink)
                Spacer()
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(result.products) { product in
                        RecommendedProductCard(product: product)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(mute)
            .padding(.horizontal, 4)
    }
}

// MARK: - Gallery

struct ScanGalleryView: View {
    @ObservedObject var store: ScanHistoryStore
    var onSelect: (ScanResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var selectedScans: [ScanResult] {
        store.scans.filter { selectedIDs.contains($0.id) }
    }

    private var allSelectedStarred: Bool {
        !selectedScans.isEmpty && selectedScans.allSatisfy(\.isStarred)
    }

    private var selectedTitle: String {
        selectedIDs.isEmpty ? "Select Scans" : "\(selectedIDs.count) Selected"
    }

    var body: some View {
        NavigationStack {
            content
                .background(bg.ignoresSafeArea())
                .navigationTitle(isSelecting ? selectedTitle : "Past scans")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .bottom) {
                    if isSelecting { selectionBar }
                }
                .onAppear { store.purgeExpired() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.scans.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.scans) { scan in
                        ScanGalleryCell(
                            scan: scan,
                            image: store.image(for: scan),
                            isSelecting: isSelecting,
                            isSelected: selectedIDs.contains(scan.id),
                            hasSelection: !selectedIDs.isEmpty,
                            ink: ink,
                            mute: mute,
                            blue: blue
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .onTapGesture { handleTap(scan) }
                        .onLongPressGesture(minimumDuration: 0.35) { handleLongPress(scan) }
                        .contextMenu { contextMenu(for: scan) }
                    }
                }
                .padding(20)
                .padding(.bottom, isSelecting ? 72 : 0)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(mute)
            Text("No scans yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ink)
            Text("Take a photo on Scan and past results will land here.")
                .font(.system(size: 15))
                .foregroundStyle(mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting {
                Button("Cancel") {
                    Haptics.light()
                    exitSelection()
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isSelecting {
                Button(selectedIDs.count == store.scans.count ? "Deselect All" : "Select All") {
                    Haptics.light()
                    if selectedIDs.count == store.scans.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(store.scans.map(\.id))
                    }
                }
                .fontWeight(.semibold)
            } else {
                Button("Done") {
                    Haptics.light()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                guard !selectedIDs.isEmpty else { return }
                store.setStarred(selectedIDs, starred: !allSelectedStarred)
            } label: {
                Label(
                    allSelectedStarred ? "Unstar" : "Star",
                    systemImage: allSelectedStarred ? "star.slash.fill" : "star.fill"
                )
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .foregroundStyle(selectedIDs.isEmpty ? mute : blue)
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)

            Button(role: .destructive) {
                Haptics.warning()
                guard !selectedIDs.isEmpty else { return }
                let ids = selectedIDs
                store.delete(ids: ids)
                selectedIDs.removeAll()
                if store.scans.isEmpty { exitSelection() }
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                    .foregroundStyle(
                        selectedIDs.isEmpty
                            ? mute
                            : Color(red: 0.92, green: 0.28, blue: 0.25)
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func contextMenu(for scan: ScanResult) -> some View {
        Button {
            Haptics.light()
            store.toggleStarred(scan)
        } label: {
            Label(
                scan.isStarred ? "Unstar" : "Star",
                systemImage: scan.isStarred ? "star.slash" : "star"
            )
        }
        Button(role: .destructive) {
            Haptics.warning()
            store.delete(scan)
            selectedIDs.remove(scan.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func handleTap(_ scan: ScanResult) {
        Haptics.light()
        if isSelecting {
            toggleSelection(scan.id)
        } else {
            onSelect(scan)
            dismiss()
        }
    }

    private func handleLongPress(_ scan: ScanResult) {
        Haptics.medium()
        if !isSelecting { isSelecting = true }
        selectedIDs.insert(scan.id)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }
}

private struct ScanGalleryCell: View {
    let scan: ScanResult
    let image: UIImage?
    let isSelecting: Bool
    let isSelected: Bool
    let hasSelection: Bool
    let ink: Color
    let mute: Color
    let blue: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumb
                badges
            }

            Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(mute)

            Text("\(scan.openHazardCount) open · \(scan.hazards.count) total")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ink)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .opacity(isSelecting && !isSelected && hasSelection ? 0.72 : 1)
    }

    private var thumb: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.92)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelecting {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? blue : Color.white.opacity(0.35), lineWidth: isSelected ? 3 : 1)
            }
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if scan.isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.04))
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }

            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isSelected ? Color.white : Color.white.opacity(0.9),
                        isSelected ? blue : Color.clear
                    )
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            } else {
                Text("\(scan.score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
            }
        }
        .padding(8)
    }
}
