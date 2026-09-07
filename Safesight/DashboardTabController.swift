//
//  DashboardTabController.swift
//  Safesight
//

import SwiftUI
import UIKit

/// Native UIKit tab bar — no horizontal page-swipe between tabs.
struct DashboardTabController: UIViewControllerRepresentable {
    let profile: UserProfile
    @Binding var showPaywall: Bool
    var hidesTabBar: Bool
    @ObservedObject private var nav = AppNavigation.shared

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

        // Defer camera / Photos stack until the user opens Scan.
        let scan = LazyScanHostingController()
        scan.tabBarItem = UITabBarItem(
            title: "Scan",
            image: UIImage(systemName: "camera"),
            selectedImage: UIImage(systemName: "camera.fill")
        )

        let hazards = UIHostingController(rootView: HazardsTabView())
        hazards.tabBarItem = UITabBarItem(
            title: "Hazards",
            image: UIImage(systemName: "exclamationmark.triangle"),
            selectedImage: UIImage(systemName: "exclamationmark.triangle.fill")
        )

        // Placeholder only — selecting Premium opens the paywall sheet.
        let premium = UIViewController()
        premium.view.backgroundColor = UIColor(Theme.bg)
        let premiumIcon: UIImage? = {
            guard let raw = UIImage(named: "PremiumTabIcon") else { return nil }
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
        premium.tabBarItem.imageInsets = UIEdgeInsets(top: -2, left: 0, bottom: 2, right: 0)
        context.coordinator.premiumTab = premium

        let you = UIHostingController(rootView: YouScreen(profile: profile))
        you.tabBarItem = UITabBarItem(
            title: "You",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )

        for host in [home, hazards, you] {
            host.view.backgroundColor = UIColor(Theme.bg)
            host.view.clipsToBounds = false
        }
        scan.view.backgroundColor = .black

        tabBar.viewControllers = [home, scan, hazards, premium, you]
        tabBar.view.tintColor = UIColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        tabBar.view.backgroundColor = UIColor(Theme.bg)
        tabBar.tabBar.isTranslucent = true
        context.coordinator.tabBar = tabBar

        return tabBar
    }

    func updateUIViewController(_ tabBar: UITabBarController, context: Context) {
        context.coordinator.showPaywall = $showPaywall
        context.coordinator.tabBar = tabBar
        if tabBar.tabBar.isHidden != hidesTabBar {
            UIView.performWithoutAnimation {
                tabBar.tabBar.isHidden = hidesTabBar
            }
            tabBar.view.setNeedsLayout()
            tabBar.view.layoutIfNeeded()
        }
        let target = nav.selectedTab
        if tabBar.selectedIndex != target,
           let count = tabBar.viewControllers?.count,
           target >= 0, target < count,
           target != 3 {
            tabBar.selectedIndex = target
        }
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var showPaywall: Binding<Bool>
        weak var premiumTab: UIViewController?
        weak var tabBar: UITabBarController?

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
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
                AppNavigation.shared.selectedTab = index
            }
            return true
        }
    }
}

/// Builds `ScanScreen` on first visit so camera setup never blocks app launch.
private final class LazyScanHostingController: UIViewController {
    private var hosted: UIHostingController<ScanScreen>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installScanIfNeeded()
    }

    private func installScanIfNeeded() {
        guard hosted == nil else { return }
        let host = UIHostingController(rootView: ScanScreen())
        hosted = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .black
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
