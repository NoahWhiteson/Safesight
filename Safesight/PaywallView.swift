//
//  PaywallView.swift
//  Safesight
//

import RevenueCat
import RevenueCatUI
import SwiftUI

private enum PayPlan: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var productID: String {
        switch self {
        case .monthly: return RevenueCatConfig.monthlyProductID
        case .yearly: return RevenueCatConfig.yearlyProductID
        }
    }

    var fallbackPrice: String {
        switch self {
        case .monthly: return "$9.99/m"
        case .yearly: return "$79.99/y"
        }
    }

    var fallbackDetail: String {
        switch self {
        case .monthly: return "$119.88/y"
        case .yearly: return "Original $119.88/y"
        }
    }

    var isBestValue: Bool { self == .yearly }
}

/// Custom Safesight paywall — purchases go through RevenueCat packages.
struct PaywallView: View {
    var isModal: Bool = false

    @ObservedObject private var subs = SubscriptionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: PayPlan = .yearly
    @State private var showCustomerCenter = false
    @State private var appeared = false
    @State private var isPurchasing = false

    private let features = [
        ("gauge.with.needle", "House Score"),
        ("bag", "Product recommendations"),
        ("sparkles", "AI summary"),
        ("viewfinder", "Unlimited scans"),
        ("square.grid.3x3", "All camera focus areas"),
        ("exclamationmark.triangle", "Unlimited hazard detection")
    ]

    private let blue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if subs.isPremium {
                        premiumSuccessContent
                    } else {
                        purchaseContent
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .animation(.default, value: appeared)
                .animation(.default, value: subs.isPremium)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.light()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(white: 0.35))
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            .containerBackground(Color(red: 0.96, green: 0.96, blue: 0.97), for: .navigation)
            .onAppear {
                withAnimation(.default) { appeared = true }
                Task { await subs.refresh() }
            }
            .sheet(isPresented: $showCustomerCenter) {
                CustomerCenterView()
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Purchase (not premium)

    private var purchaseContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 14) {
                Image("PaywallVIP")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)

                Text("Upgrade to Access")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(white: 0.08))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Text("Unlock House Score, AI summary, product picks, unlimited scans, and full hazard detection.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            featureList(showChecks: false)

            HStack(spacing: 12) {
                planButton(.monthly)
                planButton(.yearly)
            }

            Button {
                Haptics.medium()
                guard !isPurchasing else { return }
                isPurchasing = true
                Task {
                    _ = await subs.purchase(productID: selected.productID)
                    isPurchasing = false
                    // Stay on sheet — premium UI swaps in via isPremium.
                }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing || subs.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text(selected == .yearly ? "Get Premium Yearly" : "Get Premium Monthly")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(Color(white: 0.08)))
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || subs.isLoading)

            Button {
                Haptics.light()
                Task { _ = await subs.restorePurchases() }
            } label: {
                Text("Restore Purchase")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.5))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if let err = subs.lastErrorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.92, green: 0.35, blue: 0.32))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Premium success

    private var premiumSuccessContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.18, green: 0.70, blue: 0.35))
                .padding(.top, 16)

            Text("You’re on Premium")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.08))
                .multilineTextAlignment(.center)

            Text("Thanks for supporting Safesight. Everything below is unlocked on this device.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            featureList(showChecks: true)

            Button {
                Haptics.medium()
                showCustomerCenter = true
            } label: {
                Text("Manage subscription")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(Color(white: 0.08)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if isModal {
                Button {
                    Haptics.light()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared

    private func featureList(showChecks: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.1) { index, item in
                HStack(spacing: 12) {
                    if showChecks {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.18, green: 0.70, blue: 0.35))
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: item.0)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(blue)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(blue.opacity(0.12)))
                    }

                    Text(item.1)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(white: 0.08))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if index < features.count - 1 {
                    Rectangle()
                        .fill(Color(white: 0.94))
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private func planButton(_ plan: PayPlan) -> some View {
        Button {
            Haptics.select()
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = plan
            }
        } label: {
            planCard(plan)
        }
        .buttonStyle(.plain)
    }

    private func planCard(_ plan: PayPlan) -> some View {
        let on = selected == plan
        let price = subs.displayPrice(for: plan.productID) ?? plan.fallbackPrice

        return VStack(alignment: .leading, spacing: 6) {
            Text(plan.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))

            Text(price)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(white: 0.08))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(plan.fallbackDetail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(plan.isBestValue ? Color(red: 0.92, green: 0.35, blue: 0.32) : Color(white: 0.45))
                .strikethrough(plan.isBestValue)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(on ? blue : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if plan.isBestValue {
                Text("33% OFF")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(blue))
                    .offset(x: -10, y: -10)
            }
        }
    }
}

extension View {
    func enterFade(_ appeared: Bool, index: Int = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .animation(.default, value: appeared)
    }
}
