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

    var body: some View {
        GeometryReader { geo in
            // Fill the screen when safe; fall back to fit if a hazard would be cropped.
            let placed = placementRect(
                imageSize: image.size,
                in: geo.size,
                hazards: hazards
            )

            ZStack {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .frame(width: placed.width, height: placed.height)
                    .position(x: placed.midX, y: placed.midY)
                    .clipped()

                ForEach(hazards) { hazard in
                    let local = hazard.boundingBox.cgRect(in: placed.size)
                    let rect = local.offsetBy(dx: placed.minX, dy: placed.minY)
                    let active = highlightedID == nil || highlightedID == hazard.id

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(hazard.severity.color, lineWidth: active ? 2.5 : 1.2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(hazard.severity.color.opacity(active ? 0.14 : 0.05))
                        )
                        .frame(width: max(24, rect.width), height: max(24, rect.height))
                        .position(x: rect.midX, y: rect.midY)
                        .opacity(active ? 1 : 0.35)

                    Text(hazard.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(hazard.severity.color.opacity(0.92))
                        )
                        .position(
                            x: min(geo.size.width - 60, max(60, rect.midX)),
                            y: max(18, rect.minY - 14)
                        )
                        .opacity(active ? 1 : 0.4)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// Prefer aspect-fill; if any hazard would leave the viewport, use aspect-fit so nothing scanned is cut.
    private func placementRect(
        imageSize: CGSize,
        in bounds: CGSize,
        hazards: [ScanHazardDTO]
    ) -> CGRect {
        let fill = aspectFillRect(imageSize: imageSize, in: bounds)
        guard !hazards.isEmpty else { return fill }

        let pad: CGFloat = 12
        let visible = CGRect(origin: .zero, size: bounds).insetBy(dx: pad, dy: pad)
        let allVisible = hazards.allSatisfy { hazard in
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
    let result: ScanResult
    @Binding var highlightedHazardID: UUID?
    var onDone: () -> Void

    @State private var expandedHazardID: UUID?

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    scoreHeader
                    hazardsSection
                    productsSection
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
    }

    private var scoreColor: Color {
        if result.score >= 85 { return Color(red: 0.20, green: 0.68, blue: 0.45) }
        if result.score >= 65 { return Color(red: 0.95, green: 0.62, blue: 0.12) }
        return Color(red: 0.92, green: 0.28, blue: 0.25)
    }

    private var scoreLabel: String {
        if result.score >= 85 { return "Looking solid" }
        if result.score >= 65 { return "Needs attention" }
        return "High risk areas"
    }

    private var hazardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hazards found")

            VStack(spacing: 0) {
                ForEach(Array(result.hazards.enumerated()), id: \.element.id) { index, hazard in
                    let expanded = expandedHazardID == hazard.id

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
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: hazard.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(hazard.severity.color)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(hazard.severity.color.opacity(0.12)))

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(hazard.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(ink)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                        Text(hazard.severity.rawValue)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(hazard.severity.color)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(hazard.severity.color.opacity(0.12)))
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

                            if expanded {
                                VStack(alignment: .leading, spacing: 8) {
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
                                .padding(.leading, 40)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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

            Text("\(scan.hazards.count) hazard\(scan.hazards.count == 1 ? "" : "s")")
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
