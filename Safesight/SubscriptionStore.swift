//
//  SubscriptionStore.swift
//  Safesight
//

import Combine
import Foundation
import RevenueCat
import SwiftUI

@MainActor
final class SubscriptionStore: NSObject, ObservableObject {
    static let shared = SubscriptionStore()

    @Published private(set) var isPremium = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    @Published private(set) var scanCount: Int
    @Published private(set) var houseScore: Int
    @Published private(set) var openHazards: Int
    @Published private(set) var aiSummary: String?

    private let scansKey = "safesight.scanCount"
    private let scoreKey = "safesight.houseScore"
    private let hazardsKey = "safesight.openHazards"
    private let summaryKey = "safesight.aiSummary"

    static let freeScanLimit = 1
    static let freeFocusLimit = 6

    var remainingFreeScans: Int {
        max(0, Self.freeScanLimit - scanCount)
    }

    var canScan: Bool {
        isPremium || scanCount < Self.freeScanLimit
    }

    private var started = false

    override init() {
        scanCount = UserDefaults.standard.integer(forKey: scansKey)
        openHazards = UserDefaults.standard.integer(forKey: hazardsKey)
        houseScore = UserDefaults.standard.object(forKey: scoreKey) == nil
            ? 0
            : UserDefaults.standard.integer(forKey: scoreKey)
        aiSummary = UserDefaults.standard.string(forKey: summaryKey)
        super.init()
    }

    /// Call once after `Purchases.configure`.
    func start() {
        guard !started else { return }
        started = true
        Purchases.shared.delegate = self
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            async let infoTask = Purchases.shared.customerInfo()
            async let offeringsTask = Purchases.shared.offerings()

            let info = try await infoTask
            apply(customerInfo: info)

            let offerings = try await offeringsTask
            currentOffering = offerings.current
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func purchase(package: Package) async -> Bool {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                apply(customerInfo: result.customerInfo)
                return isPremium
            }
            return false
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func purchase(productID: String) async -> Bool {
        guard let offering = currentOffering else {
            await refresh()
            guard let offering = currentOffering else {
                lastErrorMessage = "No offerings available yet."
                return false
            }
            return await purchase(productID: productID, from: offering)
        }
        return await purchase(productID: productID, from: offering)
    }

    private func purchase(productID: String, from offering: Offering) async -> Bool {
        let package = offering.availablePackages.first {
            $0.storeProduct.productIdentifier == productID
        } ?? offering.package(identifier: productID)

        guard let package else {
            lastErrorMessage = "Product “\(productID)” isn’t in the current offering."
            return false
        }
        return await purchase(package: package)
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            return isPremium
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func recordScan() {
        scanCount += 1
        UserDefaults.standard.set(scanCount, forKey: scansKey)
    }

    /// Clears local free-scan counters / house insights (logout). Does not touch RevenueCat.
    func resetLocalProgress() {
        scanCount = 0
        houseScore = 0
        openHazards = 0
        aiSummary = nil
        UserDefaults.standard.removeObject(forKey: scansKey)
        UserDefaults.standard.removeObject(forKey: scoreKey)
        UserDefaults.standard.removeObject(forKey: hazardsKey)
        UserDefaults.standard.removeObject(forKey: summaryKey)
    }

    func applyScanInsights(score: Int, openHazards: Int, summary: String) {
        houseScore = score
        self.openHazards = openHazards
        aiSummary = summary
        UserDefaults.standard.set(score, forKey: scoreKey)
        UserDefaults.standard.set(openHazards, forKey: hazardsKey)
        UserDefaults.standard.set(summary, forKey: summaryKey)
    }

    /// Localized Store price for a product in the current offering, if loaded.
    func displayPrice(for productID: String) -> String? {
        guard let package = package(for: productID) else { return nil }
        return package.storeProduct.localizedPriceString
    }

    func package(for productID: String) -> Package? {
        guard let offering = currentOffering else { return nil }
        return offering.availablePackages.first {
            $0.storeProduct.productIdentifier == productID
        } ?? offering.package(identifier: productID)
    }

    private func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        isPremium = customerInfo.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
    }
}

extension SubscriptionStore: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}
