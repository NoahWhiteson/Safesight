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

    var body: some View {
        NavigationStack {
            Group {
                if openItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(openItems.count) open")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(mute)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(openItems.enumerated()), id: \.element.hazard.id) { index, item in
                                    hazardRow(item.scan, item.hazard)
                                    if index < openItems.count - 1 {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white)
                            )
                        }
                        .padding(22)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Hazards")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .containerBackground(bg, for: .navigation)
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
