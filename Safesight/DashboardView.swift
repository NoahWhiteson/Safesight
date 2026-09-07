//
//  DashboardView.swift
//  Safesight
//

import SwiftUI

struct DashboardView: View {
    let profile: UserProfile
    @State private var showPaywall = false
    @ObservedObject private var chrome = ScanChromeState.shared

    var body: some View {
        DashboardTabController(
            profile: profile,
            showPaywall: $showPaywall,
            hidesTabBar: chrome.hidesTabBar
        )
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
