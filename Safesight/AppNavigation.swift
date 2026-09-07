//
//  AppNavigation.swift
//  Safesight
//

import Combine
import Foundation

/// Cross-tab jumps (Home Activity → Scan results, empty-state CTAs).
@MainActor
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    /// Tab indices match DashboardTabController: Home 0, Scan 1, Hazards 2, Premium 3, You 4.
    @Published var selectedTab: Int = 0
    @Published var pendingScanID: UUID?

    func goToScan() {
        selectedTab = 1
    }

    func openScan(_ id: UUID) {
        pendingScanID = id
        selectedTab = 1
    }
}
