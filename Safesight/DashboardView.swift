//
//  DashboardView.swift
//  Safesight
//

import SwiftUI
import UIKit
import RevenueCatUI

private enum HomeSegment: String, CaseIterable {
    case overview = "Overview"
    case activity = "Activity"
}

private enum Theme {
    static let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let ink = Color(white: 0.08)
    static let mute = Color(white: 0.45)
    static let soft = Color(white: 0.94)
    static let blue = Color(red: 0.0, green: 0.48, blue: 1.0) // iOS blue
    static let good = Color(red: 0.22, green: 0.72, blue: 0.48)
    static let warn = Color(red: 0.92, green: 0.35, blue: 0.32)
}

enum Haptics {
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

struct DashboardView: View {
    let profile: UserProfile
    @State private var showPaywall = false

    var body: some View {
        DashboardTabController(profile: profile, showPaywall: $showPaywall)
            .ignoresSafeArea()
            .preferredColorScheme(.light)
            .sheet(isPresented: $showPaywall) {
                PaywallView(isModal: true)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
    }
}

/// Native UIKit tab bar — no horizontal page-swipe between tabs.
private struct DashboardTabController: UIViewControllerRepresentable {
    let profile: UserProfile
    @Binding var showPaywall: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(showPaywall: $showPaywall)
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBar = UITabBarController()
        tabBar.delegate = context.coordinator

        let home = UIHostingController(rootView: HomeScreen(profile: profile))
        home.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        let scan = UIHostingController(rootView: ScanScreen())
        scan.tabBarItem = UITabBarItem(
            title: "Scan",
            image: UIImage(systemName: "camera"),
            selectedImage: UIImage(systemName: "camera.fill")
        )

        // Placeholder only — selecting Premium opens the paywall sheet.
        let premium = UIViewController()
        premium.view.backgroundColor = UIColor(Theme.bg)
        let premiumIcon: UIImage? = {
            guard let raw = UIImage(named: "PremiumTabIcon") else { return nil }
            // Larger than default tab glyphs so the crown reads clearly.
            let size = CGSize(width: 42, height: 42)
            let renderer = UIGraphicsImageRenderer(size: size)
            let scaled = renderer.image { _ in
                raw.draw(in: CGRect(origin: .zero, size: size))
            }
            return scaled.withRenderingMode(.alwaysOriginal)
        }()
        premium.tabBarItem = UITabBarItem(
            title: "Premium",
            image: premiumIcon,
            selectedImage: premiumIcon
        )
        // Pull icon up/out so tab bar doesn't crush it.
        premium.tabBarItem.imageInsets = UIEdgeInsets(top: -2, left: 0, bottom: 2, right: 0)
        context.coordinator.premiumTab = premium

        let you = UIHostingController(rootView: YouScreen(profile: profile))
        you.tabBarItem = UITabBarItem(
            title: "You",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )

        for host in [home, scan, you] {
            host.view.backgroundColor = UIColor(Theme.bg)
            host.view.clipsToBounds = true
        }

        tabBar.viewControllers = [home, scan, premium, you]
        tabBar.view.tintColor = UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        tabBar.view.backgroundColor = UIColor(Theme.bg)

        return tabBar
    }

    func updateUIViewController(_ tabBar: UITabBarController, context: Context) {
        context.coordinator.showPaywall = $showPaywall
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var showPaywall: Binding<Bool>
        weak var premiumTab: UIViewController?

        init(showPaywall: Binding<Bool>) {
            self.showPaywall = showPaywall
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            if viewController === premiumTab {
                Haptics.select()
                showPaywall.wrappedValue = true
                return false
            }
            Haptics.select()
            return true
        }
    }
}

/// Forces Home's UIScrollView to vertical-only and kills root nav edge-swipe.
private struct HomeScrollLock: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        LockController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? LockController)?.apply()
    }

    private final class LockController: UIViewController, UIGestureRecognizerDelegate {
        private weak var attachedScroll: UIScrollView?
        private var axisLock: UIPanGestureRecognizer?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        func apply() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationController?.interactivePopGestureRecognizer?.delegate = self

            let root: UIView
            if let parentView = parent?.view {
                root = parentView
            } else if let superview = view.superview {
                root = superview
            } else {
                root = view
            }
            for scroll in Self.scrollViews(in: root) {
                scroll.alwaysBounceHorizontal = false
                scroll.isDirectionalLockEnabled = true
                scroll.showsHorizontalScrollIndicator = false

                if scroll.contentSize.width > scroll.bounds.width + 0.5 {
                    scroll.contentSize = CGSize(
                        width: max(scroll.bounds.width, 0),
                        height: scroll.contentSize.height
                    )
                }
                if scroll.contentOffset.x != 0 {
                    scroll.contentOffset.x = 0
                }

                if attachedScroll !== scroll {
                    attachedScroll = scroll
                    installAxisLock(on: scroll)
                }
            }
        }

        private func installAxisLock(on scroll: UIScrollView) {
            if let existing = axisLock {
                existing.view?.removeGestureRecognizer(existing)
            }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleAxisLock(_:)))
            pan.delegate = self
            pan.cancelsTouchesInView = false
            scroll.addGestureRecognizer(pan)
            axisLock = pan
        }

        @objc private func handleAxisLock(_ gesture: UIPanGestureRecognizer) {
            guard let scroll = attachedScroll else { return }
            if scroll.contentOffset.x != 0 {
                scroll.contentOffset.x = 0
            }
            if gesture.state == .ended || gesture.state == .cancelled {
                scroll.contentOffset.x = 0
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === navigationController?.interactivePopGestureRecognizer {
                return false
            }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  gestureRecognizer === axisLock,
                  let scroll = attachedScroll else { return false }
            let v = pan.velocity(in: scroll)
            return abs(v.x) > abs(v.y) && abs(v.x) > 8
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private static func scrollViews(in root: UIView) -> [UIScrollView] {
            var result: [UIScrollView] = []
            var stack: [UIView] = [root]
            while let view = stack.popLast() {
                if let scroll = view as? UIScrollView {
                    result.append(scroll)
                }
                stack.append(contentsOf: view.subviews)
            }
            return result
        }
    }
}

private struct NavPopGestureLock: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        LockController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? LockController)?.lock()
    }

    private final class LockController: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            lock()
        }

        func lock() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }
    }
}

private extension View {
    func lockHorizontalNavDrag() -> some View {
        background(NavPopGestureLock())
    }
}

// MARK: - Home

private struct HomeScreen: View {
    let profile: UserProfile
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var subs = SubscriptionStore.shared
    @ObservedObject private var history = ScanHistoryStore.shared
    @State private var segment: HomeSegment = .overview
    @State private var appeared = false
    @State private var showPaywall = false

    private var current: UserProfile {
        profiles.profile ?? profile
    }

    private var focusCount: Int { current.hazards.count }

    private var weekDays: [(String, Int, Bool)] {
        let cal = Calendar.current
        let today = Date()
        return (-3...3).compactMap { offset -> (String, Int, Bool)? in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let name = DateFormatter()
            name.dateFormat = "EEE"
            let num = cal.component(.day, from: day)
            return (String(name.string(from: day).prefix(3)), num, offset == 0)
        }
    }

    private var scoreLabel: String {
        "\(subs.houseScore)"
    }

    var body: some View {
        NavigationStack {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal, alignment: .leading)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.default, value: appeared)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollEdgeEffectStyle(.soft, for: .top)
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
            .onAppear {
                guard !appeared else { return }
                withAnimation(.default) {
                    appeared = true
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(isModal: true)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .background(HomeScrollLock())
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        segment = item
                    }
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
            .padding(.top, 12)
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
                    status: subs.scanCount == 0 ? "—" : "Live",
                    statusColor: subs.scanCount == 0 ? Theme.mute : Theme.good,
                    value: scoreLabel,
                    title: "Readiness",
                    bars: Array(repeating: CGFloat(0.08), count: 7),
                    barColor: Theme.blue
                )
                statusCard(
                    delta: "Open",
                    status: subs.scanCount == 0 ? "—" : (subs.openHazards == 0 ? "Clear" : "Open"),
                    statusColor: subs.scanCount == 0
                        ? Theme.mute
                        : (subs.openHazards == 0 ? Theme.good : Theme.warn),
                    value: "\(subs.openHazards)",
                    title: "Hazards",
                    bars: Array(repeating: CGFloat(0.08), count: 7),
                    barColor: Theme.warn
                )
            }
            .padding(.horizontal, 22)

            productsSection
                .padding(.horizontal, 22)
                .padding(.top, 4)
        }
    }

    private var scoreCaption: String {
        if !subs.isPremium {
            return "Premium unlocks deeper scoring after your first scans."
        }
        if subs.scanCount == 0 || subs.houseScore == 0 {
            return "No score yet — run a scan to generate one."
        }
        return "Updated from your latest scans."
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No activity yet")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 22)
                .padding(.top, 22)

            Text("Scans and fixes will show up here. You’ve completed \(subs.scanCount) scan\(subs.scanCount == 1 ? "" : "s").")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mute)
                .padding(.horizontal, 22)
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
                        .frame(width: 8, height: 28 * h + 6)
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
                        subs.isPremium
                            ? "No recommendations yet. Complete a scan and Safesight will surface product picks here."
                            : "Product picks unlock with Premium after Safesight knows what’s in your home."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mute)

                    if !subs.isPremium {
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
                }
            }
        }
    }
}

private struct ProfileAvatarView: View {
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


// MARK: - Scan / You

private struct ScanScreen: View {
    @ObservedObject private var subs = SubscriptionStore.shared
    @ObservedObject private var history = ScanHistoryStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @StateObject private var camera = CameraController()
    @State private var showPaywall = false
    @State private var thinkingImage: UIImage?
    @State private var showThinking = false
    @State private var showGallery = false
    @State private var scanResult: ScanResult?
    @State private var resultImage: UIImage?
    @State private var highlightedHazardID: UUID?
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let resultImage, scanResult != nil {
                ScanAnnotatedImageView(
                    image: resultImage,
                    hazards: scanResult?.hazards ?? [],
                    highlightedID: highlightedHazardID
                )
                .ignoresSafeArea()
            } else if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else if camera.authorizationDenied {
                permissionDenied
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Top chrome (hidden while reviewing a scan so the photo stays clear)
            if scanResult == nil {
                VStack {
                    HStack {
                        Image("AppLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                            .blendMode(.difference)
                            .accessibilityLabel("Safesight")

                        Spacer()
                        Text(
                            subs.isPremium
                                ? "Unlimited"
                                : "\(subs.remainingFreeScans) left"
                        )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.18)))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                    Spacer()

                    HStack(alignment: .center) {
                        Color.clear.frame(width: 52, height: 52)

                        Spacer()

                        Button {
                            Haptics.medium()
                            Task { await takePhoto() }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 4)
                                    .frame(width: 78, height: 78)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 64, height: 64)
                                    .opacity(isCapturing ? 0.55 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isCapturing || showThinking || !camera.isAuthorized)

                        Spacer()

                        Button {
                            Haptics.light()
                            showGallery = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Past scans")
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 36)
                }
            }
        }
        .fullScreenCover(isPresented: $showThinking) {
            Group {
                if let thinkingImage {
                    ScanThinkingOverlay(image: thinkingImage)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .presentationBackground(.black)
        }
        .sheet(item: $scanResult, onDismiss: {
            highlightedHazardID = nil
            resultImage = nil
        }) { result in
            ScanResultsDrawer(
                result: result,
                highlightedHazardID: $highlightedHazardID
            ) {
                scanResult = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showGallery) {
            ScanGalleryView(store: history) { scan in
                openScan(scan)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isModal: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task {
            await camera.requestAccessAndConfigure()
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.8))
            Text("Camera access needed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Enable camera in Settings so Safesight can scan rooms.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private func openScan(_ scan: ScanResult) {
        resultImage = history.image(for: scan)
        highlightedHazardID = nil
        scanResult = scan
    }

    private func takePhoto() async {
        guard !isCapturing else { return }
        if !subs.canScan {
            showPaywall = true
            return
        }

        isCapturing = true
        let image = await camera.capturePhoto()
        isCapturing = false

        guard let image else { return }
        subs.recordScan()

        let scanId = UUID()
        thinkingImage = image
        var present = Transaction()
        present.disablesAnimations = true
        withTransaction(present) {
            showThinking = true
        }

        let request = ScanAnalysisRequest(
            scanId: scanId,
            focusAreas: profiles.profile?.hazards.map(\.rawValue) ?? [],
            dwelling: profiles.profile?.dwelling.rawValue,
            imageBase64: nil
        )

        let analyzer = ScanAnalyzerFactory.make()
        let response: ScanAnalysisResponse
        do {
            response = try await analyzer.analyze(request: request, image: image)
        } catch {
            response = ScanPlaceholderPayload.response()
        }

        // Keep the thinking chrome up long enough to feel intentional.
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        let saved = history.save(image: image, response: response, scanId: scanId)
        let openCount = saved.hazards.filter { $0.severity != .low }.count
        subs.applyScanInsights(score: saved.score, openHazards: openCount, summary: saved.summary)

        var dismiss = Transaction()
        dismiss.disablesAnimations = true
        withTransaction(dismiss) {
            showThinking = false
        }
        thinkingImage = nil

        resultImage = image
        try? await Task.sleep(nanoseconds: 280_000_000)
        scanResult = saved
    }
}

private struct YouScreen: View {
    let profile: UserProfile
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var subs = SubscriptionStore.shared
    @State private var appeared = false
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var showEditFocus = false
    @State private var showEditDwelling = false

    private var current: UserProfile {
        profiles.profile ?? profile
    }

    private var planLabel: String {
        subs.isPremium ? "Premium" : "Free"
    }

    private var planDetail: String {
        if subs.isPremium {
            return "Full access · all focus areas"
        }
        return "1 scan · 6 focus areas"
    }

    private var scansLabel: String {
        if subs.isPremium {
            return "\(subs.scanCount) (unlimited)"
        }
        return "\(subs.scanCount) / \(SubscriptionStore.freeScanLimit)"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    profileHeader

                    planCard
                        .padding(.horizontal, 22)

                    settingsSection(title: "Home profile") {
                        Button {
                            Haptics.light()
                            showEditDwelling = true
                        } label: {
                            settingsRow(
                                icon: "house.fill",
                                title: "Dwelling",
                                value: current.dwelling.rawValue,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        settingsRow(icon: "viewfinder", title: "Scans used", value: scansLabel)
                        settingsRow(
                            icon: "scope",
                            title: "Focus areas",
                            value: "\(current.hazards.count)"
                        )
                    }
                    .padding(.horizontal, 22)

                    focusSection
                        .padding(.horizontal, 22)

                    settingsSection(title: "Subscription") {
                        Button {
                            Haptics.light()
                            if subs.isPremium {
                                showCustomerCenter = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            settingsRow(
                                icon: subs.isPremium ? "crown.fill" : "crown",
                                title: subs.isPremium ? "Manage subscription" : "Upgrade to Premium",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.light()
                            Task { _ = await subs.restorePurchases() }
                        } label: {
                            settingsRow(
                                icon: "arrow.clockwise",
                                title: "Restore purchases",
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    if let err = subs.lastErrorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.warn)
                            .padding(.horizontal, 22)
                    }

                    Text("Safesight")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.default, value: appeared)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Theme.bg)
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .lockHorizontalNavDrag()
            .containerBackground(Theme.bg, for: .navigation)
            .sheet(isPresented: $showPaywall) {
                PaywallView(isModal: true)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
            .sheet(isPresented: $showEditFocus) {
                EditFocusAreasSheet(
                    initial: Set(current.hazards),
                    isPremium: subs.isPremium,
                    onUpgrade: {
                        showEditFocus = false
                        showPaywall = true
                    }
                )
            }
            .sheet(isPresented: $showEditDwelling) {
                EditDwellingSheet(initial: current.dwelling)
            }
            .onAppear {
                guard !appeared else { return }
                withAnimation(.default) { appeared = true }
                Task { await subs.refresh() }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ProfileAvatarView(name: current.name, size: 96)
            Text(current.name)
                .font(.system(size: 22, weight: .bold))
            Text(current.dwelling.rawValue)
                .font(.system(size: 15))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your plan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mute)
                    Text(planLabel)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(planDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mute)
                }
                Spacer()
                Image(systemName: subs.isPremium ? "checkmark.circle.fill" : "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        subs.isPremium
                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                            : Theme.blue
                    )
            }

            Button {
                Haptics.medium()
                if subs.isPremium {
                    showCustomerCenter = true
                } else {
                    showPaywall = true
                }
            } label: {
                Text(subs.isPremium ? "Manage subscription" : "Upgrade to Premium")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FOCUS AREAS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.mute)
                Spacer()
                Button {
                    Haptics.light()
                    showEditFocus = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                let hazards = Array(current.hazards)
                if hazards.isEmpty {
                    Text("No focus areas yet. Tap Edit to choose what Safesight watches for.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let visible = Array(hazards.prefix(6))
                    let others = max(0, hazards.count - 6)

                    ForEach(visible) { hazard in
                        HStack(spacing: 12) {
                            Image(systemName: hazard.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.blue)
                                .frame(width: 28)
                            Text(hazard.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                            if hazard.requiresPremium {
                                Text("Premium")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.blue.opacity(0.12)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if others > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.blue)
                                .frame(width: 28)
                            Text("\(others) other Focus Areas Selected")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )

            if current.hazards.count > 8 {
                focusBatchWarning
            }
        }
    }

    private var focusBatchWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.86, green: 0.58, blue: 0.12))
                .padding(.top, 1)

            Text("With more than 8 focus areas, the AI model may underperform. For best results, scan in smaller batches.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.mute)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        value: String?,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mute.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct EditFocusAreasSheet: View {
    let initial: Set<SafetyInterest>
    let isPremium: Bool
    var onUpgrade: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<SafetyInterest> = []

    private var focusLimit: Int? {
        isPremium ? nil : SubscriptionStore.freeFocusLimit
    }

    private var atLimit: Bool {
        guard let focusLimit else { return false }
        return selection.count >= focusLimit
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SafetyInterest.allCases) { hazard in
                        let selected = selection.contains(hazard)
                        let premiumLocked = hazard.requiresPremium && !isPremium
                        let capped = !selected && atLimit && !premiumLocked

                        Button {
                            Haptics.select()
                            if selected {
                                selection.remove(hazard)
                            } else if premiumLocked {
                                onUpgrade()
                            } else if !atLimit {
                                selection.insert(hazard)
                            } else {
                                Haptics.light()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: hazard.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hazard.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    if premiumLocked {
                                        Text("Premium focus area")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.mute)
                                    } else if capped {
                                        Text("Free limit reached")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.mute)
                                    }
                                }

                                Spacer()

                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(
                                        selected
                                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                                            : Color(white: 0.75)
                                    )
                            }
                            .opacity((premiumLocked || capped) && !selected ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(
                        isPremium
                            ? "Select everything that matters"
                            : "Free: Fire, Water leaks, Electric, Child proofing, Trip hazards, Blocked exits (max \(SubscriptionStore.freeFocusLimit))."
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let focusLimit {
                            Text("\(selection.count) / \(focusLimit) selected")
                        } else {
                            Text("\(selection.count) selected")
                        }

                        if selection.count > 8 {
                            Text("With more than 8 focus areas, the AI model may underperform. For best results, scan in smaller batches.")
                                .foregroundStyle(Color(red: 0.72, green: 0.48, blue: 0.08))
                        }
                    }
                }
            }
            .navigationTitle("Focus areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.medium()
                        var next = selection
                        if !isPremium {
                            next = Set(next.filter { !$0.requiresPremium })
                            let ordered = SafetyInterest.freeCases.filter { next.contains($0) }
                            next = Set(ordered.prefix(SubscriptionStore.freeFocusLimit))
                        }
                        profiles.updateHazards(next)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                }
            }
            .onAppear {
                selection = initial
            }
        }
    }
}

private struct EditDwellingSheet: View {
    let initial: DwellingType

    @ObservedObject private var profiles = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DwellingType = .house

    var body: some View {
        NavigationStack {
            List {
                Section("Where do you live?") {
                    ForEach(DwellingType.allCases) { dwelling in
                        Button {
                            Haptics.select()
                            selection = dwelling
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: dwelling.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dwelling.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(dwelling.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.mute)
                                }

                                Spacer()

                                Image(systemName: selection == dwelling ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(
                                        selection == dwelling
                                            ? Color(red: 0.18, green: 0.70, blue: 0.35)
                                            : Color(white: 0.75)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Home profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.medium()
                        profiles.updateDwelling(selection)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selection = initial
            }
        }
    }
}
