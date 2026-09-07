//
//  HomeScreen.swift
//  Safesight
//

import SwiftUI
import UIKit

enum HomeSegment: String, CaseIterable {
    case overview = "Overview"
    case activity = "Activity"
}

// MARK: - Home

struct HomeScreen: View {
    let profile: UserProfile
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var subs = SubscriptionStore.shared
    @ObservedObject private var history = ScanHistoryStore.shared
    @ObservedObject private var nav = AppNavigation.shared
    @State private var segment: HomeSegment = .overview
    @State private var showPaywall = false

    private var current: UserProfile {
        profiles.profile ?? profile
    }

    private var focusCount: Int { current.hazards.count }

    /// Last 7 calendar days: label, day number, isToday, hasScan.
    private var weekDays: [(String, Int, Bool, Bool)] {
        let cal = Calendar.current
        let today = Date()
        let name = DateFormatter()
        name.dateFormat = "EEE"
        let scanDays: Set<DateComponents> = Set(
            history.scans.map {
                cal.dateComponents([.year, .month, .day], from: $0.createdAt)
            }
        )
        return (-3...3).compactMap { offset -> (String, Int, Bool, Bool)? in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let num = cal.component(.day, from: day)
            let comps = cal.dateComponents([.year, .month, .day], from: day)
            let hasScan = scanDays.contains(comps)
            return (String(name.string(from: day).prefix(3)), num, offset == 0, hasScan)
        }
    }

    private var scoreLabel: String {
        "\(subs.houseScore)"
    }

    private var recentActivity: [ScanResult] {
        Array(history.scans.prefix(20))
    }

    /// Per-day score height (0…1) for the last 7 days ending today.
    private var readinessBars: [CGFloat] {
        dailyMetricBars { scans in
            guard let latest = scans.max(by: { $0.createdAt < $1.createdAt }) else { return 0.08 }
            return CGFloat(min(100, max(0, latest.score))) / 100
        }
    }

    /// Per-day open-hazard intensity for the last 7 days.
    private var hazardBars: [CGFloat] {
        dailyMetricBars { scans in
            guard let latest = scans.max(by: { $0.createdAt < $1.createdAt }) else { return 0.08 }
            return CGFloat(min(1, Double(latest.openHazardCount) / 4.0))
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        weekHeader
                            .padding(.horizontal, 22)
                            .padding(.top, 8)

                        segmentControl
                            .padding(.horizontal, 22)
                            .padding(.top, 16)

                        if segment == .overview {
                            overviewContent
                        } else {
                            activityContent
                        }
                    }
                    .padding(.bottom, 28)
                    .frame(width: geo.size.width, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .background(VerticalScrollAxisLock())
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .accessibilityLabel("Safesight")
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    ProfileAvatarView(name: current.name, size: 32)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(isModal: true)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .containerBackground(Theme.bg, for: .navigation)
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    Text(day.0)
                        .font(.system(size: 12, weight: day.2 ? .bold : .medium))
                        .foregroundStyle(day.2 ? Theme.ink : Theme.mute)
                    Text("\(day.1)")
                        .font(.system(size: day.2 ? 22 : 15, weight: day.2 ? .bold : .medium))
                        .foregroundStyle(day.2 ? Theme.ink : Theme.mute)
                    Circle()
                        .fill(day.3 ? Theme.blue : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(HomeSegment.allCases, id: \.self) { item in
                Button {
                    Haptics.select()
                    segment = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(segment == item ? Theme.ink : Theme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(segment == item ? Theme.soft : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if history.scans.isEmpty {
                emptyScanCTA
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(scoreLabel)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()

                    Text("House score")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }

                Text(scoreCaption)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
            }
            .padding(.horizontal, 22)
            .padding(.top, history.scans.isEmpty ? 4 : 12)
            .onTapGesture {
                if !subs.isPremium {
                    Haptics.light()
                    showPaywall = true
                }
            }

            HStack(spacing: 12) {
                metricCard(icon: "viewfinder", label: "Scans", value: "\(subs.scanCount)")
                metricCard(icon: "scope", label: "Focus areas", value: "\(focusCount)")
            }
            .padding(.horizontal, 22)

            aiSummaryCard
                .padding(.horizontal, 22)
                .onTapGesture {
                    if !subs.isPremium {
                        Haptics.light()
                        showPaywall = true
                    }
                }

            HStack(spacing: 12) {
                statusCard(
                    delta: "Status",
                    status: history.scans.isEmpty ? "—" : "Live",
                    statusColor: history.scans.isEmpty ? Theme.mute : Theme.good,
                    value: history.scans.isEmpty ? "—" : scoreLabel,
                    title: "Readiness",
                    bars: readinessBars,
                    barColor: Theme.blue
                )
                statusCard(
                    delta: "Open",
                    status: history.scans.isEmpty ? "—" : (subs.openHazards == 0 ? "Clear" : "Open"),
                    statusColor: history.scans.isEmpty
                        ? Theme.mute
                        : (subs.openHazards == 0 ? Theme.good : Theme.warn),
                    value: history.scans.isEmpty ? "—" : "\(subs.openHazards)",
                    title: "Hazards",
                    bars: hazardBars,
                    barColor: Theme.warn
                )
            }
            .padding(.horizontal, 22)

            productsSection
                .padding(.horizontal, 22)
                .padding(.top, 4)
        }
    }

    private var emptyScanCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start with a room scan")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Point the camera at a space and Safesight will score visible risks.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mute)
            Button {
                Haptics.medium()
                nav.goToScan()
            } label: {
                Text("Scan a room")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var scoreCaption: String {
        if history.scans.isEmpty {
            return "No score yet — scan a room to generate one."
        }
        if !subs.isPremium {
            return "Premium unlocks deeper scoring after your first scans."
        }
        if subs.houseScore == 0 {
            return "No score yet — run a scan to generate one."
        }
        return "Updated from your latest scans."
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if recentActivity.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                Text("Scans show up here after you capture a room.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mute)
                    .padding(.horizontal, 22)

                Button {
                    Haptics.medium()
                    nav.goToScan()
                } label: {
                    Text("Scan a room")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(Theme.ink))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 8)
            } else {
                Text("Recent activity")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                Text("Showing latest \(recentActivity.count) · unstarred drop after 60 days")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
                    .padding(.horizontal, 22)

                VStack(spacing: 10) {
                    ForEach(recentActivity) { scan in
                        Button {
                            Haptics.light()
                            nav.openScan(scan.id)
                        } label: {
                            activityRow(scan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activityRow(_ scan: ScanResult) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let image = history.image(for: scan) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(white: 0.92)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if scan.isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.05))
                    }
                }

                Text(scan.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Score \(scan.score) · \(scan.openHazardCount) open"
                        + (scan.fixedHazardCount > 0 ? " · \(scan.fixedHazardCount) fixed" : "")
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.mute)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mute.opacity(0.7))
                .padding(.top, 6)

            severityDot(for: scan)
                .padding(.top, 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
    }

    private func severityDot(for scan: ScanResult) -> some View {
        let worst = scan.openHazards.map(\.severity).max(by: { a, b in
            severityRank(a) < severityRank(b)
        })
        let color: Color = {
            if scan.openHazardCount == 0 && !scan.hazards.isEmpty { return Theme.good }
            switch worst {
            case .high: return Theme.warn
            case .medium: return Color(red: 0.95, green: 0.62, blue: 0.12)
            case .low: return Theme.good
            case .none: return Theme.good
            }
        }()
        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private func severityRank(_ s: HazardSeverity) -> Int {
        switch s {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    private func metricCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI summary", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                Spacer()
                if !subs.isPremium {
                    Text("Premium")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.blue.opacity(0.12)))
                }
            }

            Text(summaryCopy)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var summaryCopy: String {
        if history.scans.isEmpty {
            return "Scan a room and Safesight will explain your House Score here."
        }
        if !subs.isPremium {
            return "AI summary explains your House Score after scans. Unlock Premium to turn on summaries."
        }
        if let summary = subs.aiSummary, !summary.isEmpty {
            return summary
        }
        return "No summary yet. Complete a scan and Safesight will explain your House Score here."
    }

    private func statusCard(
        delta: String,
        status: String,
        statusColor: Color,
        value: String,
        title: String,
        bars: [CGFloat],
        barColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(delta)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mute)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.mute)
                }
            }

            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.mute)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barColor.opacity(0.35 + Double(h) * 0.65))
                        .frame(width: 8, height: 28 * max(h, 0.08) + 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !subs.isPremium {
                    Text("Premium")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.blue.opacity(0.12)))
                }
            }

            let products = history.latest?.products ?? []

            if products.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        history.scans.isEmpty
                            ? "Scan a room to unlock product picks for what Safesight finds."
                            : (subs.isPremium
                                ? "No recommendations yet. Complete a scan and Safesight will surface product picks here."
                                : "Product picks unlock with Premium after Safesight knows what’s in your home.")
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mute)

                    if history.scans.isEmpty {
                        Button {
                            Haptics.medium()
                            nav.goToScan()
                        } label: {
                            Text("Scan a room")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(Theme.ink))
                        }
                        .buttonStyle(.plain)
                    } else if !subs.isPremium {
                        Button {
                            Haptics.medium()
                            showPaywall = true
                        } label: {
                            Text("Unlock recommendations")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(Theme.ink))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(products) { product in
                            RecommendedProductCard(product: product)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
            }
        }
    }

    /// Seven bars for days [-6…0] relative to today.
    private func dailyMetricBars(_ value: ([ScanResult]) -> CGFloat) -> [CGFloat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (-6...0).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return 0.08 }
            let next = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let scans = history.scans.filter { $0.createdAt >= day && $0.createdAt < next }
            return value(scans)
        }
    }
}

struct ProfileAvatarView: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Image("ProfileAvatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: size > 60 ? 3 : 1.5)
            )
            .accessibilityLabel(name)
    }
}
