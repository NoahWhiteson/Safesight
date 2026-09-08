//
//  HazardsTabView.swift
//  Safesight
//
//  House-wide open hazards across all scans.
//

import SwiftUI

struct HazardsTabView: View {
    @ObservedObject private var history = ScanHistoryStore.shared
    @ObservedObject private var nav = AppNavigation.shared

    @State private var selectedFocus: SafetyInterest? = nil
    @State private var pageIndex = 0
    @State private var listBlur: CGFloat = 0
    @State private var listOpacity: Double = 1
    @State private var isPaging = false

    private let pageSize = 10
    private let ink = Color(white: 0.08)
    private let mute = Color(white: 0.45)
    private let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    private let good = Color(red: 0.20, green: 0.68, blue: 0.45)
    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    private var openItems: [(scan: ScanResult, hazard: ScanHazardDTO)] {
        history.scans.flatMap { scan in
            scan.openHazards.map { (scan, $0) }
        }
    }

    /// Focus areas that appear on at least one open hazard (stable SafetyInterest order).
    private var availableFocusFilters: [SafetyInterest] {
        let present = Set(openItems.compactMap(\.hazard.focusInterest))
        return SafetyInterest.allCases.filter { present.contains($0) }
    }

    private var filteredItems: [(scan: ScanResult, hazard: ScanHazardDTO)] {
        guard let selectedFocus else { return openItems }
        return openItems.filter { $0.hazard.focusInterest == selectedFocus }
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize))))
    }

    private var pageItems: [(scan: ScanResult, hazard: ScanHazardDTO)] {
        let start = pageIndex * pageSize
        guard start < filteredItems.count else { return [] }
        let end = min(start + pageSize, filteredItems.count)
        return Array(filteredItems[start..<end])
    }

    var body: some View {
        NavigationStack {
            Group {
                if openItems.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        focusFilterBar
                            .padding(.top, 4)
                            .padding(.bottom, 10)

                        if filteredItems.isEmpty {
                            filteredEmptyState
                        } else {
                            ZStack(alignment: .bottom) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text(countLabel)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(mute)
                                            .padding(.horizontal, 4)

                                        VStack(spacing: 0) {
                                            ForEach(Array(pageItems.enumerated()), id: \.element.hazard.id) { index, item in
                                                hazardRow(item.scan, item.hazard)
                                                if index < pageItems.count - 1 {
                                                    Divider().padding(.leading, 56)
                                                }
                                            }
                                        }
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(Color.white)
                                        )
                                        .id(pageIndex)
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.bottom, pageCount > 1 ? 72 : 16)
                                }
                                .blur(radius: listBlur)
                                .opacity(listOpacity)
                                .animation(.easeInOut(duration: 0.2), value: listBlur)
                                .animation(.easeInOut(duration: 0.2), value: listOpacity)

                                if pageCount > 1 {
                                    VStack(spacing: 0) {
                                        LinearGradient(
                                            colors: [bg.opacity(0), bg],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: 36)
                                        .allowsHitTesting(false)

                                        pageNavigator
                                            .padding(.horizontal, 22)
                                            .padding(.bottom, 16)
                                            .background(bg)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Hazards")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .containerBackground(bg, for: .navigation)
            .onChange(of: selectedFocus) { _, _ in
                goToPage(0, animated: false)
            }
            .onChange(of: filteredItems.count) { _, _ in
                clampPage()
            }
            .onChange(of: openItems.count) { _, _ in
                if let selectedFocus,
                   !availableFocusFilters.contains(selectedFocus) {
                    self.selectedFocus = nil
                }
                clampPage()
            }
        }
    }

    private var countLabel: String {
        if let selectedFocus {
            return "\(filteredItems.count) open · \(selectedFocus.rawValue)"
        }
        return "\(filteredItems.count) open"
    }

    private var focusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", selected: selectedFocus == nil) {
                    selectedFocus = nil
                }
                ForEach(availableFocusFilters) { focus in
                    filterChip(title: focus.rawValue, selected: selectedFocus == focus) {
                        selectedFocus = focus
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.white : ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? ink : Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var pageNavigator: some View {
        HStack(spacing: 16) {
            Button {
                goToPage(pageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pageIndex > 0 ? ink : mute.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            .disabled(pageIndex <= 0 || isPaging)

            Text("Page \(pageIndex + 1) of \(pageCount)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .monospacedDigit()

            Button {
                goToPage(pageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pageIndex < pageCount - 1 ? ink : mute.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            .disabled(pageIndex >= pageCount - 1 || isPaging)
        }
        .frame(maxWidth: .infinity)
    }

    private func goToPage(_ next: Int, animated: Bool = true) {
        let clamped = min(max(0, next), max(0, pageCount - 1))
        guard clamped != pageIndex else { return }
        guard !isPaging else { return }

        Haptics.light()

        guard animated else {
            pageIndex = clamped
            listBlur = 0
            listOpacity = 1
            return
        }

        isPaging = true
        withAnimation(.easeInOut(duration: 0.16)) {
            listBlur = 10
            listOpacity = 0.25
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            pageIndex = clamped
            withAnimation(.easeInOut(duration: 0.22)) {
                listBlur = 0
                listOpacity = 1
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            isPaging = false
        }
    }

    private func clampPage() {
        let maxIndex = max(0, pageCount - 1)
        if pageIndex > maxIndex {
            goToPage(maxIndex, animated: false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(good)
            Text("You’re all caught up")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ink)
            Text("Open hazards from every scan land here until you mark them Fixed or Dismissed.")
                .font(.system(size: 15))
                .foregroundStyle(mute)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(mute)
            Text("Nothing in this focus area")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ink)
            Text("Try All, or pick another focus filter.")
                .font(.system(size: 14))
                .foregroundStyle(mute)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }

    private func hazardRow(_ scan: ScanResult, _ hazard: ScanHazardDTO) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: hazard.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(hazard.severity.color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hazard.severity.color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    Haptics.light()
                    nav.openScan(scan.id, highlightHazardID: hazard.id, returnToTab: 2)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(hazard.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ink)
                            Spacer(minLength: 0)
                            Text(hazard.severity.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(hazard.severity.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(hazard.severity.color.opacity(0.12)))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(mute.opacity(0.7))
                        }

                        if let focus = hazard.focusInterest {
                            Text(focus.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(blue)
                        }

                        Text(hazard.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(mute)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mute)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Button {
                        Haptics.medium()
                        _ = history.setHazardStatus(
                            scanID: scan.id,
                            hazardID: hazard.id,
                            status: .fixed
                        )
                    } label: {
                        Text("Fixed")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(good)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(good.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.medium()
                        _ = history.setHazardStatus(
                            scanID: scan.id,
                            hazardID: hazard.id,
                            status: .dismissed
                        )
                    } label: {
                        Text("Dismiss")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(mute)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.black.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Pixel look-hardness slider (smooth, stylized)

struct PixelLookSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.1...1.0

    private let accent = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let track = Color(white: 0.90)
    private let mute = Color(white: 0.45)

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let t = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbW: CGFloat = 14
            let thumbH = height + 10
            let x = t * max(width - thumbW, 1)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(track)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.15),
                                accent.opacity(0.55),
                                accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: max(x + thumbW * 0.5, 0), height: height)
                    }

                PixelGridOverlay(progress: t, accent: accent)
                    .clipShape(Capsule(style: .continuous))

                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: thumbW, height: thumbH)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .offset(x: x)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = drag.location.x / max(width, 1)
                        let clamped = min(1, max(0, raw))
                        let next = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                        if abs(next - value) > 0.0005 {
                            value = next
                        }
                    }
            )
        }
        .frame(height: 36)
        .accessibilityValue(Text("\(Int(round(value * 100))) percent"))
    }
}

private struct PixelGridOverlay: View {
    var progress: CGFloat
    var accent: Color

    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 4
            let gap: CGFloat = 2
            let step = cell + gap
            let cols = Int(ceil(size.width / step))
            let rows = Int(ceil(size.height / step))
            let litWidth = size.width * progress

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * step + gap * 0.5
                    let y = CGFloat(row) * step + gap * 0.5
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    let along = x / max(size.width, 1)
                    let lit = x + cell * 0.5 <= litWidth
                    let base = lit ? 0.22 + along * 0.78 : 0.08
                    let color = lit
                        ? accent.opacity(Double(base))
                        : Color.black.opacity(0.06)
                    context.fill(Path(roundedRect: rect, cornerRadius: 0.8), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
