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
    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        SubscriptionStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
