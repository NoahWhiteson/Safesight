//
//  ScanResultsDrawer.swift
//  Safesight
//

import SwiftUI

struct ScanResultsDrawer: View {
    let scanID: UUID
    @Binding var highlightedHazardID: UUID?
    var onDone: () -> Void
    var onScanUpdated: ((ScanResult) -> Void)? = nil

    @ObservedObject private var history = ScanHistoryStore.shared
    @State private var expandedHazardID: UUID?
    @State private var shareItems: [Any]?
    @State private var isPreparingShare = false

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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        prepareShare()
                    } label: {
                        if isPreparingShare {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isPreparingShare)
                    .accessibilityLabel("Share scan")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )) {
                if let shareItems {
                    ShareSheet(items: shareItems)
                        .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                if let id = highlightedHazardID {
                    expandedHazardID = id
                }
            }
            .onChange(of: highlightedHazardID) { _, id in
                if let id {
                    expandedHazardID = id
                }
            }
        }
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        let scan = result
        let image = history.image(for: scan)
        Task { @MainActor in
            let items = await ScanSharePresenter.makeShareItems(for: scan, image: image)
            isPreparingShare = false
            if let items {
                shareItems = items
            } else {
                Haptics.warning()
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
