//
//  SafesightApp.swift
//  Safesight
//
//  Created by Noah Whiteson on 2026-09-05.
//

import RevenueCat
import SwiftUI

@main
struct SafesightApp: App {
    @State private var didConfigurePurchases = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    guard !didConfigurePurchases else { return }
                    didConfigurePurchases = true
                    #if DEBUG
                    Purchases.logLevel = .debug
                    #endif
                    // After first frame — configure must not block the launch screen.
                    Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
                    SubscriptionStore.shared.start()
                }
        }
    }
}
