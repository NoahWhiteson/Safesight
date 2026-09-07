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
            let size = geo.size
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()

                ForEach(hazards) { hazard in
                    let rect = hazard.boundingBox.cgRect(in: size)
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
                            x: min(size.width - 60, max(60, rect.midX)),
                            y: max(18, rect.minY - 14)
                        )
                        .opacity(active ? 1 : 0.4)
                }
            }
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
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.96))
                    .frame(height: 120)

                if let name = product.imageName, UIImage(named: name) != nil {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .padding(.horizontal, 10)
                } else {
                    Image(systemName: product.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(blue)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(product.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(mute)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(product.priceLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(blue)
        }
        .padding(16)
        .frame(width: 200, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
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

    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if store.scans.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.scans) { scan in
                                Button {
                                    Haptics.light()
                                    onSelect(scan)
                                    dismiss()
                                } label: {
                                    galleryCell(scan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Past scans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func galleryCell(_ scan: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = store.image(for: scan) {
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

                Text("\(scan.score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(8)
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
    }
}
