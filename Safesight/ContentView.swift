 //
//  ContentView.swift
//  Safesight
//
//  Created by Noah Whiteson on 2026-09-05.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = ProfileStore.shared
    @State private var phase: AppPhase = .resolving

    private enum AppPhase {
        case resolving
        case onboarding
        case settingUp
        case dashboard
    }

    var body: some View {
        Group {
            switch phase {
            case .resolving:
                Color(white: 0.96).ignoresSafeArea()
            case .onboarding:
                OnboardingFlow { name, dwelling, hazards in
                    var focusAreas = hazards
                    if !SubscriptionStore.shared.isPremium {
                        let ordered = SafetyInterest.freeCases.filter { focusAreas.contains($0) }
                        focusAreas = Set(ordered.prefix(SubscriptionStore.freeFocusLimit))
                    }
                    store.save(name: name, dwelling: dwelling, hazards: focusAreas)
                    withAnimation(.default) {
                        phase = .settingUp
                    }
                }
                .transition(.opacity)
            case .settingUp:
                SetupLoadingView {
                    withAnimation(.default) {
                        phase = .dashboard
                    }
                }
                .transition(.opacity)
            case .dashboard:
                if let profile = store.profile {
                    DashboardView(profile: profile)
                        .transition(.opacity)
                } else {
                    Color.clear.onAppear { phase = .onboarding }
                }
            }
        }
        .animation(.default, value: phase)
        .onAppear {
            phase = store.hasCompletedOnboarding ? .dashboard : .onboarding
        }
    }
}

#Preview {
    ContentView()
}
