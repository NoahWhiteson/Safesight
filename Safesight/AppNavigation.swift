//
//  AppNavigation.swift
//  Safesight
//

import Combine
import Foundation

/// Cross-tab jumps (Home Activity → Scan results, Hazards → Scan, empty-state CTAs).
@MainActor
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    /// Tab indices match DashboardTabController: Home 0, Scan 1, Hazards 2, Premium 3, You 4.
    @Published var selectedTab: Int = 0
    @Published var pendingScanID: UUID?
    /// Optional hazard to highlight when opening a scan from Hazards / elsewhere.
    @Published var pendingHazardID: UUID?
    /// After closing scan results, jump back to this tab (e.g. Hazards = 2). `nil` = stay on Scan.
    @Published var returnTabAfterScan: Int?

    func goToScan() {
        selectedTab = 1
    }

    func openScan(_ id: UUID, highlightHazardID: UUID? = nil, returnToTab: Int? = nil) {
        pendingHazardID = highlightHazardID
        returnTabAfterScan = returnToTab
        pendingScanID = id
        selectedTab = 1
    }
}
